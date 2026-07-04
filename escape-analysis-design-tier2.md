2# Design: Tier-2 (Interprocedural) Escape Summaries

**Status**: Proposed Future Work (as of PLDI 2027 paper)  
**Owner**: Anonymous  
**Depends On**: Tier-1 Summaries, World-Guard Machinery

## 1. Motivation

The current transient conversion system is purely **intraprocedural**. It relies on a hand-verified table of "Tier-1" summaries for standard library functions. As noted in Section 8 of the PLDI 2027 paper, this is a significant limitation.

The system cannot optimize common patterns where an accumulator is passed to a user-defined helper function, even if that function is "well-behaved." The DVI benchmark is the canonical example:

```lisp
;; The accumulator `acc` is passed to a user function `add-item`.
;; The current analysis sees `add-item` as an opaque call and disqualifies `acc`.
(loop [acc (new-cart) items-to-add]
  (if (empty? items-to-add)
    acc
    (recur (add-item acc (first items-to-add))
           (rest items-to-add))))

;; The user function `add-item` just performs a standard, linear update.
(defn add-item [cart item]
  (assoc cart (:id item) item))
```

To convert this loop, the compiler must be able to understand the behavior of `add-item`. **Tier-2 summaries** provide this capability through interprocedural analysis.

## 2. Core Design

Tier-2 summaries extend the existing analysis framework by adding the ability to **infer, cache, and depend on** summaries for user-defined functions. This requires three new components built on the existing infrastructure.

### 2.1. Summary Inference Engine

The core of the Tier-2 system is a new analysis pass that infers an `escape-summary` struct for any given function.

**Mechanism**:
The inference engine will be a modified version of the existing classifier from `src/escape-analysis.lisp`. For a given function `f`, it will analyze its body to determine the effect it has on each of its parameters.

1.  **Parameter Tracking**: For each parameter `p` of `f`, the engine will track all its uses within the function body.
2.  **Effect Propagation**: It will use the existing effect lattice (`:none` < `:invoked` < `:shared-with-result` < `:retained`) and the Tier-1 summary table.
    - If `p` is passed as an argument to a function `g`, the effect on `p` is the effect `g` has on that argument position, looked up via `lookup-summary`.
    - The overall effect on `p` is the `effect-join` (least upper bound) of all its uses.
    - If `p` is stored in a captured variable that escapes the function's scope, its effect is `:retained`.
3.  **Freshness and Barriers**: The engine will also determine `returns-fresh-p` (if the function's return value is always a new allocation) and `barrier-p` (if it calls `eval` or other dynamic functions).

**Handling Recursion**:
For recursive or mutually recursive functions, the analysis must iterate to a fixed point.
1.  When analyzing a function `f`, initially assume the most optimistic summary for `f` itself (e.g., all params `:none`, `returns-fresh-p` true).
2.  Analyze the body of `f` using this assumption. This will produce a new, inferred summary `s1`.
3.  Re-analyze the body of `f`, this time using `s1` as the assumption for recursive calls. This produces `s2`.
4.  Repeat this process, joining the new summary with the previous one (`s_new = summary-join(s_new, s_old)`), until the summary stabilizes (`summary<=` returns true).
5.  Because the effect lattice is short and monotonic, this process is guaranteed to terminate quickly.

### 2.2. Summary Storage and Lookup

Inferred summaries must be cached for reuse.

**Mechanism**:
- A new global, thread-safe hash table, `*inferred-summaries*`, will be introduced in `src/summaries.lisp`. It will map a function's symbol to its inferred `escape-summary` struct.
- The `lookup-summary` function will be modified to follow a three-tier lookup process:
  1.  Check for a hand-verified **Tier-1** summary (the existing behavior).
  2.  If not found, check for a cached **Tier-2** summary in `*inferred-summaries*`.
  3.  If not found, the summary is **Tier-0** (fully conservative `nil`).

**Cache Invalidation**: The cache will be tied to the world-guard machinery. When a function is redefined, its entry in `*inferred-summaries*` must be cleared.

### 2.3. Integration with World Guards

This is the most critical piece for ensuring soundness. An inferred summary is a contract that is only valid as long as the function's definition remains unchanged.

**Mechanism**:
The existing world-guard system from `src/world.lisp` is perfectly suited for this.

1.  **Dependency Registration**: When the compiler optimizes a loop in function `g` based on the inferred Tier-2 summary for a user function `f`, the optimized region for `g` will call `(register-region ...)` with `'f` in its list of assumptions.
2.  **Invalidation on Redefinition**: When the user redefines `f` (via `defn` or `defmethod`), the existing `(note-redefinition 'f)` hook is triggered.
3.  `note-redefinition` will:
    a.  Look up all dependent regions for `'f`, which now includes the optimized region in `g`.
    b.  Invalidate their validity cells, forcing them to use the safe, unoptimized path on next entry.
    c.  **Crucially, it will also clear the entry for `'f` from the `*inferred-summaries*` cache.**

This ensures that optimizations based on inferred summaries are just as safe as those based on Tier-1 summaries. The next time `f` is compiled, its summary will be re-inferred.

## 3. Modes of Operation

To manage the trade-off between automation and predictability, the system will support two modes.

### 3.1. Mode 1: Automatic Inference (Default)

In this mode, the compiler will attempt to infer and cache a summary for every function it compiles.

- **Pros**: Fully automatic, maximizing optimization without user effort.
- **Cons**: Can lead to non-local performance effects. Redefining a helper function might silently de-optimize a caller far away in the codebase.

### 3.2. Mode 2: Contract-Based Summaries (Opt-in)

This mode allows developers to provide explicit summary declarations, which the compiler verifies. This makes dependencies explicit and acts as a form of machine-checked documentation.

A new `declare` form will be introduced:

```lisp
;; User provides an explicit contract for add-item.
(defn add-item [cart item]
  (declare (fol:summary :param-effects #(:shared-with-result :none)
                        :returns-fresh-p true))
  (assoc cart (:id item) item))
```

**Compiler Behavior**:
1.  **For Callers**: When compiling a call to `add-item`, the compiler will trust the declared summary and use it for optimization.
2.  **For `add-item`**: After compiling the body of `add-item`, the compiler will run the inference engine on it to produce an inferred summary. It will then **verify** that the inferred summary is compatible with (i.e., `summary<=`) the declared summary. If the implementation violates its declared contract, a compile-time warning or error will be issued.

This provides the best of both worlds: explicit, predictable contracts with automated verification.

## 4. Implementation Plan

1.  **[summaries.lisp]**
    - Add `*inferred-summaries*` hash table.
    - Update `lookup-summary` to check the Tier-2 cache.
    - Add a hook to clear the cache entry in `note-redefinition`.

2.  **[escape-analysis.lisp]**
    - Implement the `infer-summary` function, which reuses the classification logic to track effects on parameters and iterates to a fixed point for recursion.

3.  **[compiler.lisp]**
    - In `compile-form` (for `defn`/`defmethod`), after compiling a function body, call `infer-summary` and populate `*inferred-summaries*`.
    - In `emit-loop` and `emit-call`, when an optimization depends on a Tier-2 summary for a function `f`, add `'f` to the list of assumptions passed to `register-region`.
    - Add parsing logic for the `(declare (fol:summary ...))` pragma and the associated verification step.

4.  **[tests]**
    - Add unit tests for the inference engine on various function patterns (linear, escaping, recursive).
    - Add integration tests that verify:
        - The DVI benchmark now converts successfully.
        - Redefining a helper function correctly invalidates the optimized caller.
        - A function that violates its declared summary contract produces a compiler warning.

By following this design, we can extend the transient conversion optimization to be interprocedural, significantly increasing its power and applicability while maintaining the rigorous soundness guarantees of the original system.

---