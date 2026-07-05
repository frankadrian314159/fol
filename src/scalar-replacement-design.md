# Design: Scalar Replacement of Persistent Objects

**Status**: Implemented (loop-carried variant) — see "As-Built" below
**Owner**: Anonymous
**Depends On**: Escape Analysis Framework, World-Guard Machinery, Global Type Info Registry

---

## As-Built (supersedes §2–§3 for the shipped algorithm)

The originally-proposed pass (below) only unboxed an object that was created and
died inside its own `bind` — the least profitable case, and the one a native
backend often stack-allocates anyway. It also could not touch the particle-
simulation benchmark this doc prescribes, whose allocation lives in a loop
accumulator rebuilt every iteration via an object-returning callee.

The shipped algorithm (`src/compiler.lisp`, section "Aggregate Scalar
Replacement") instead targets that loop-carried pattern and is emitted from
`emit-loop`. Given a loop whose parameter `p` is initialized by a record
constructor `(make-<T> ...)`:

1. **Return-value unboxing (interprocedural).** An object-returning callee at
   the recur position — e.g. `(recur (update-point p) ...)` — is inlined.
   `sr-transform-toplevel` (a `compile-form` hook) registers qualifying
   single-clause constructors in `*sr-inlinable-fns*`; the inline substitutes
   the accumulator argument as an alias, exposing the callee's tail `make-<T>`
   as the reconstruction expression.
2. **Loop-carried unboxing.** `p` is split into one scalar loop variable per
   field (`p_x`, `p_y`, …). `(get p :x)` → `p_x`; the reconstruction that feeds
   recur becomes the per-field value expressions (recur arity grows to match);
   any bind/do wrappers around the reconstruction wrap the rewritten `recur`; a
   bare `p` in tail position is re-boxed with a single `make-<T>` at loop exit.
3. **Soundness under redefinition.** The converted loop is emitted world-guarded
   on the record class name (`register-region '("<T>")`), with the original
   allocating loop as the fallback; `emit-defclass` calls `note-redefinition`,
   so redefining `<T>` takes the fallback on next entry.

The rewrite is aligned-by-construction: a single walk both classifies and
rewrites, throwing `sr-fail` on any accumulator use outside the recognized set,
so an unhandled shape yields the original loop unchanged (never wrong code).
Enabled by `fol.compiler.escape-analysis:*scalar-replacement*`. Measured **5.8×**
on the particle-simulation benchmark (5M iterations), allocation eliminated on
the fast path. Tests: `src/tests/test-scalar-replacement.lisp`.

**Known limitations (v1):** one record accumulator per loop; the reconstruction
must peel (through single-form bind/do wrappers and one level of inlinable call)
to a `make-<T>` supplying every field; inlinable-callee arguments must be
symbol/literal; `if`-branched reconstructions are not yet recognized.

---

## (Original proposal — intra-bind variant, retained for context)

## 1. Motivation

FOL's persistent objects provide immutability and structure sharing, but they come at a significant performance cost due to heap allocation, pointer indirection, and garbage collection pressure. The `diff.md` benchmark shows that a simple operation on a native Common Lisp `defstruct` can be up to **89x faster** than the equivalent operation on a FOL persistent object.

Scalar replacement is a compiler optimization that can bridge this gap. If an object is created and used exclusively within a single function's scope (i.e., it does not "escape"), the compiler can avoid allocating the object altogether. Instead, it can "unbox" the object, storing its fields directly in local variables on the stack.

**Example**:
```lisp
;; Before Optimization
(defn calculate-offset []
  (bind [p (make-<point> :x 10 :y 20)]
    (+ (get p :x) (get p :y))))

;; After Scalar Replacement
(defn calculate-offset []
  ;; The <point> object is never allocated.
  ;; Its fields live on the stack as local variables.
  (bind [p_x 10 p_y 20]
    (+ p_x p_y)))
```

This eliminates the heap allocation and turns `get` calls into direct variable accesses, resulting in a dramatic performance improvement.

## 2. Core Design

The implementation will extend the existing escape analysis framework to identify non-escaping object allocations and rewrite the AST accordingly.

### 2.1. Generalizing the Escape Analysis

The current analysis is specialized for `loop` accumulators and proving **uniqueness-at-death** (a *must-analysis*). Scalar replacement requires a more general analysis that can operate on any local binding and prove **non-escape** (a *may-analysis*).

**Required Changes**:
1.  **New Analysis Function**: A new function, `analyze-bindings(scope-node)`, will be created in `src/escape-analysis.lisp`. It will take an AST node with a lexical scope (like `bind`, `fn`, or `loop`) and return a map from each bound variable to its escape status (e.g., `:non-escaping`, `:escapes-to-caller`, `:escapes-globally`).
2.  **Focus on Non-Escape**: An object is a candidate for scalar replacement if its escape status is `:non-escaping`. This means no references to the object can exist after its defining function returns.
3.  **Stricter Rules**: The analysis must be conservative. Passing an object to any function whose summary is not known (Tier-0) or is `:retained` will immediately mark the object as `:escapes-globally`.

### 2.2. Candidate Identification

The analysis will specifically look for `bind` forms where a variable is initialized with a constructor call.

1.  **Find Allocations**: The compiler will scan for `(bind [var (make-<type> ...)] ...)` patterns.
2.  **Check Escape Status**: It will use `analyze-bindings` to check if `var` is `:non-escaping`.
3.  **Get Type Information**: If the object is non-escaping, the compiler will use the type name (`<type>`) to look up the class's slot information from the `*global-type-info*` registry (populated by `defclass`). This provides the list of field names needed for unboxing.

### 2.3. The Rewriter Pass

A new AST-to-AST transformation pass, `scalar-replacement-pass`, will be implemented. When it finds a non-escaping object allocation, it will perform the following rewrite:

1.  **Remove Allocation**: The `(make-<type> ...)` call is removed from the `bind` form.
2.  **Introduce Scalar Bindings**: New local variables are created for each of the object's slots. The variable names will be mangled to avoid collisions (e.g., `p` becomes `p_x`, `p_y`). These new variables are initialized with the values from the constructor call.
3.  **Rewrite Accessors**: The rewriter then walks the body of the `bind` form and replaces all `(get p :key)` calls with direct references to the corresponding mangled local variable (e.g., `p_x`).

This pass will run before the final code emission.

### 2.4. Soundness in a Dynamic World

The optimization must remain sound even when class definitions change at runtime.

**Mechanism**: We will extend the existing world-guard machinery.

1.  **Dependency on Class Definitions**: When a function `f` is compiled with a scalar-replaced object of type `<t>`, the compiled function `f` will register a dependency on the *class name* `'<t>`.
2.  **Invalidation on `defclass`**: The `emit-defclass` function in `src/compiler.lisp` will be modified to wrap the generated `cl:defclass` form with a call to `(note-redefinition '<t>)`.
3.  **Fallback**: If the class `<t>` is redefined at runtime, `note-redefinition` will invalidate the optimized version of `f`, forcing it to fall back to its safe, unoptimized path on the next call.

This ensures that if a class's slots change, any code that made assumptions about its structure is safely invalidated.

### 2.5. Synergy with Tier-2 Summary Inference

The scalar replacement pass and the Tier-2 summary inference engine are not just compatible; they are mutually beneficial, forming a powerful feedback loop that enhances the effectiveness of both optimizations.

**How Tier-2 Summaries Improve Scalar Replacement**

The primary requirement for scalar replacement is proving that an object is **non-escaping**. Without interprocedural information, this analysis must be very conservative. If an object `p` is passed to a user-defined function `f`, the analysis has to assume `f` might cause `p` to escape, thus disqualifying `p` from scalar replacement.

Tier-2 summaries solve this problem. The `infer-summary` engine can analyze `f` and determine that it does not retain a reference to its argument. When the scalar replacement pass later analyzes a call to `f(p)`, it can use this inferred summary to prove that `p` does not escape through the call, enabling its unboxing.

**How Scalar Replacement Improves Tier-2 Summaries**

The relationship also works in reverse. The `infer-summary` engine's precision depends on the simplicity of the code it analyzes.

Consider a function `g` that creates a temporary object `t` and passes one of its own parameters, `x`, to `t`'s constructor. Without scalar replacement, the analysis sees `x` flowing into a new object and may produce a conservative summary for `g`.

If the scalar replacement pass runs *before* summary inference, it can analyze `g`'s body and prove that `t` is a non-escaping temporary. It will then rewrite the body, eliminating the allocation of `t` and replacing it with stack variables. This simplification allows `infer-summary` to analyze a much simpler data flow for `x`, leading to a more precise summary for `g`. This more accurate summary then benefits the callers of `g`.

**Compiler Pass Ordering**

To maximize this synergy, the compiler passes should be ordered as follows:

1.  **`scalar-replacement-pass`**: Simplifies function bodies by unboxing temporary objects.
2.  **`infer-summary`**: Runs on the simplified AST to produce more accurate interprocedural summaries.

This ordering ensures that each optimization provides the maximum benefit to the other, leading to more opportunities for both scalar replacement and other summary-based optimizations like transient conversion.

## 3. Implementation Plan

1.  **[src/escape-analysis.lisp]**
    - Generalize the core classification logic into a new `analyze-bindings` function that returns an escape-status map for all variables in a scope.
    - The existing `classify-loop-param` can be refactored to use this more general analysis.

2.  **[src/compiler.lisp]**
    - Implement the `scalar-replacement-pass` as a new AST-to-AST transformation function.
    - This pass will:
        - Traverse the AST looking for `bind` nodes.
        - Call `analyze-bindings` to find non-escaping object allocations.
        - Use `*global-type-info*` to get slot names.
        - Perform the rewrite: remove the allocation, add scalar bindings, and replace `get` calls.
    - Update `compile-form` to run `scalar-replacement-pass` on the AST before `emit-node`.
    - Modify `emit-defclass` to emit a `note-redefinition` call for the class name, integrating it with the world-guard system.

3.  **[src/tests]**
    - Create a new test file, `test-scalar-replacement.lisp`.
    - Add tests to verify that:
        - Simple, non-escaping objects are correctly replaced.
        - `get` calls are correctly rewritten to variable references.
        - Objects that escape (e.g., are returned, passed to unknown functions, or captured in closures) are *not* replaced.
        - The optimization produces byte-identical results to the unoptimized version.
        - Redefining a class correctly invalidates functions that depend on it.

4.  **[benchmarks]**
    - Create a new micro-benchmark that heavily uses small, short-lived objects to quantify the performance improvement.
    - Re-run the `diff.md` benchmark to confirm that the performance gap has been significantly closed.

## 4. Benefits and Drawbacks

### Benefits

- **Massive Performance Improvement**: Can yield 10-50x speedups for object-heavy, allocation-bound code.
- **Reduced GC Pressure**: By avoiding heap allocations for short-lived objects, it significantly reduces the load on the garbage collector.
- **Builds on Existing Infrastructure**: Leverages the escape analysis framework and world-guard system already in place.

### Drawbacks

- **Increased Compiler Complexity**: The analysis is more general and the AST rewrite is more complex than for transient conversion.
- **Potential for Slower Compilation**: The extra analysis and rewrite pass will add to compile times, though this should be negligible for most code.

By implementing scalar replacement, we can bring the performance of FOL's persistent objects much closer to that of native structs for a large class of common code patterns, making the language significantly more competitive for performance-sensitive applications.

---