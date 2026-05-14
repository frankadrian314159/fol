# FOL Dispatch Caching: Semantics and Usage

**Date**: May 14, 2026  
**Status**: Publication-grade with formal semantics and limitations

---

## What Gets Cached

Automatic caching applies to:
- Multi-clause functions (4+ clauses, fixed arity)
- Single-clause with wide COND body (4+ non-fallback clauses)
- Defmethods with sufficient dispatch complexity

---

## Cache Key Strategy: Critical Limitations

### Reference Types
Cache key is `(class-of arg)`. **This assumes dispatch depends only on type, not value.**

**⚠️ BREAKS for value-based dispatch**:
```lisp
(defn classify-vec [v]
  (cond
    ((> (count v) 100) :large)  ; value predicate, not type
    (t :small)))

(classify-vec #(1 2 3))      ; :small, cached
(classify-vec #(1 ... 101))  ; WRONG: cache hit returns :small (stale!)
```

**Safe usage**: Dispatch predicates must depend only on `class-of`, not object properties:
```lisp
(defn process [x]
  (cond
    ((vector? x) :vec)      ; type-based ✓
    ((dict? x) :dict)       ; type-based ✓
    ((> (count x) 100) :big) ; UNSAFE: property-based, caching will be wrong
    (t :other)))
```

### EQL-Comparable Atoms
Cache key is the value itself (fixnum, char, symbol). Safe for all predicates.

### Guideline
**Only enable caching if all dispatch predicates depend solely on `(class-of arg1 arg2 ...)`.**

---

## Invalidation Guarantees

### Defn Redefinition
Fresh cache created on redefinition (old cache discarded).

### Method Addition/Removal
- **Conservative (default)**: All caches flushed via MOP hooks
- **Aggressive (opt-in)**: Only affected GF's caches flushed

### ⚠️ CLOSURE CAPTURE: A Language Semantics Breaking Change

**The Problem (Critical Correctness Issue)**:

If a defn references an external GF indirectly and a method is later added to that GF, the defn's cache is NOT automatically invalidated. The result is **silent semantic change**:

```lisp
(defn check-value [x]           ; compiled, cache created
  (if (valid? x) :valid :invalid))

;; Later in REPL:
(defmethod valid? ((x my-type)) t)  ; method added

;; SEMANTICS VIOLATION:
(check-value (make-my-type))  ; returns :invalid (stale cached result!)
                              ; Should return :valid (new method applies)
```

**Why this happens**:
The compiler doesn't track external GF dependencies (CallSet). At compile time, it doesn't know that `check-value` calls `valid?`. When `valid?` gets a new method, the MOP hooks flush all caches (conservative mode) to be safe, but `check-value`'s cache was already created before the new method existed.

**This is a breaking semantic change**, not a limitation:
- **Violates transparency**: User can't tell from the code whether it's safe to add methods.
- **Silent failure**: No error, no warning—just wrong answers.
- **Breaks referential transparency**: Same input may return different results depending on method history.

**Resolutions** (choose one):

1. **Always redefine defns after method changes** (practical but error-prone):
   ```lisp
   (defmethod valid? ((x my-type)) t)
   (defn check-value [x]
     (if (valid? x) :valid :invalid))  ; cache reset
   ```

2. **Manual flush** (requires discipline):
   ```lisp
   (defmethod valid? ((x my-type)) t)
   (fol.compiler.dispatch:flush-all-caches!)
   ```

3. **Use aggressive mode ONLY if you verify no cross-GF dependencies**:
   ```lisp
   (setf fol.compiler.dispatch:*aggressive-cache-invalidation* NIL)
   ```

4. **Dependency-based invalidation** (future):
   Analyze CallSet statically and flush only affected defns on method change.

**Recommended approach**: Use conservative mode (default), redefinition-based workflows, and **document this as a language semantics change** in release notes.

---

## Thread Safety and Portability

### SBCL Only
This implementation uses **SBCL-specific primitives**:
- `:synchronized t` hash-table for atomic per-entry `gethash`
- `sb-ext:atomic-incf` for non-blocking counter updates

**Portability to other CL implementations**:
- **Clozure CL**: Has atomic operations (ccl:atomic-incf) and concurrent hash-tables (ccl:make-hash-table :shared t). Minor adaptation needed.
- **ABCL** (JVM): Use `java.util.concurrent.ConcurrentHashMap` and java.util.concurrent.atomic ops.
- **Other implementations**: No standardized atomicity primitives; would require locks (performance penalty) or require implementation support.

**Recommendation**: Port to Clozure CL in a future release if needed.

---

## Cache Inspection API

```lisp
(fol.compiler.dispatch:inspect-fn-cache 'fn-name)
  ; Returns: (values hits misses generation size)

(fol.compiler.dispatch:flush-all-caches!)
(fol.compiler.dispatch:flush-gf-caches! 'gf-name)
```

**Note on `generation` counter**: Incremented on flush, observable via `inspect-fn-cache`, but **not used by cache lookups**. Provided for external monitoring/observability tools.

## Cache Inspection API

```lisp
(fol.compiler.dispatch:inspect-fn-cache 'fn-name)
  ; Returns: (values hits misses generation size)

(fol.compiler.dispatch:flush-all-caches!)
(fol.compiler.dispatch:flush-gf-caches! 'gf-name)
```

## Performance

- **Hit rates**: 75–95% typical, 99%+ for single-type
- **Speedup**: 1.8–3.0× typical, 20–50× for single-type best case
- **Memory**: ~40 bytes per entry, O(K) where K = distinct types

## When NOT to Cache

Add `&rest` parameter or reduce clauses below threshold.

Disable if:
- Function rarely called
- Uniform random workload (low hit rate)
- Memory-constrained
- Predicate evaluation is very cheap

---

**For details, see**:
- [dispatch-caching-formal.md](dispatch-caching-formal.md)
- [DISPATCH_CACHING_PAPER_v2.md](DISPATCH_CACHING_PAPER_v2.md)
- [dispatch-caching-alternatives.md](dispatch-caching-alternatives.md)
- [dispatch-caching-guidelines.md](dispatch-caching-guidelines.md)
