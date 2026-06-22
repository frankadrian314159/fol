# FOL Performance Profiling Results

**Date:** June 22, 2026  
**Platform:** SBCL 2.6.0, AMD Ryzen 9 5900X, 56 GB RAM  
**Test Configuration:** FOL vs. equivalent Common Lisp implementations

## Summary

All three benchmarks show significant FOL performance degradation compared to hand-optimized CL:

| Benchmark | FOL Time | CL Time | Ratio | FOL Memory | CL Memory | Ratio |
|-----------|----------|---------|-------|------------|-----------|-------|
| **Diff** | 1.137s | 0.010s | **114×** | 234.98 MB | 6.09 MB | **38×** |
| **Guards** | 0.008s | <0.001s | **~20×** | 1.84 MB | 0.31 MB | **6×** |
| **DVI** | 0.029s | 0.002s | **15×** | 8.99 MB | 0.06 MB | **150×** |

## Findings

### 1. **Method Dispatch Overhead** (Most Severe)
The **DIFF benchmark** uses `:around` methods on persistent objects in the hot loop:
```lisp
(defmethod assoc :around [(obj <diffable>) key val]
  (bind [old-val (get obj key)
         result  (call-next-method)]
    (if (and (not (= key :_changes))
             (not (= old-val val)))
      (assoc result :_changes (inc (:_changes result)))
      result)))
```

**This is called 500K times (100K iterations × 5 assoc calls per iteration).**

Each call involves:
- Generic function dispatch
- Method lookup and resolution
- Class checking for `<diffable>`
- Multiple levels of indirection through `get`, `assoc`, `inc`

### 2. **Persistent Object Overhead**
FOL's persistent data structures provide structural sharing benefits for correctness and memory safety, but:
- **Memory usage is 6-150× higher** than mutable CL structs
- Creation involves copying entire object snapshots
- Every modification creates new immutable snapshots

### 3. **Generic Function Cost**
FOL uses generic functions extensively (e.g., `=`, `+`, `-`, `get`, `assoc`):
- **CLOS method dispatch** adds 5-10 cycles per call
- In tight loops (500K+ iterations), this compounds

### 4. **Type Checking Overhead**
The `=` operator now handles arbitrary types (added for keyword comparison fix):
```lisp
(defmethod = ((a t) &optional b &rest rest)
  (if b
      (cl:and (cl:equal a b) (if rest (apply #'= b rest) t))
      t))
```
This adds `cl:equal` overhead for non-numeric comparisons.

## Identified Hotspots

Based on profiling output and code structure:

1. **Method dispatch** - `:around` method on `assoc` in DIFF (500K calls)
2. **Persistent object creation** - `assoc` returns new `<diffable>` snapshot
3. **Generic `get`/`assoc` calls** - Multiple indirections per operation
4. **Type checking in `=`** - Dispatch to arbitrary-type fallback

## Potential Optimizations

### High-Impact (Estimated 5-10× improvement)
1. **Inline `:around` methods** - Use static analysis to inline simple `:around` methods in hot loops
2. **Specialize `assoc` for persistent objects** - Direct implementation vs. generic dispatch
3. **Cache method lookups** - (Dispatch caching was already attempted; showed 2× speedup but 40× memory cost)

### Medium-Impact (Estimated 2-3× improvement)
1. **Optimize `=` for common cases** - Fast path for numbers before generic dispatch
2. **Reduce persistent snapshots** - Use write-barriers instead of full copies
3. **Type hints/declarations** - Let compiler eliminate polymorphism in known cases

### Low-Impact (Estimated 1.5-2× improvement)
1. **Optimize `get` for small dicts** - Fast path for 2-3 slot objects
2. **Reduce garbage pressure** - Pre-allocate snapshots in benchmark loops

## Recommendation

**Start with method inlining** - The `:around` pattern is creating a 100× slowdown. Options:
1. Detect simple `:around` methods and emit inline code
2. Provide an `inline-assoc!` primitive for performance-critical loops
3. Add `#[inline-methods true]` pragma for hot functions

The dispatch caching removed earlier was attempting to solve this but with high memory cost. A lightweight inline specialization might be more effective.

## Files for Reference

- Profiling script: `benchmarks/profile-all-benchmarks.lisp`
- Diff benchmark: `benchmarks/fol-code/diff.fol` (9-line `:around` method)
- Guards benchmark: `benchmarks/fol-code/guards.fol`
- DVI benchmark: `benchmarks/fol-code/derived-value-invalidation.fol`

## Next Steps

1. Profile with SBCL's statistical profiler to identify exact function hotspots
2. Implement method inlining for simple `:around` methods
3. Re-run benchmarks to measure improvement
4. Consider trade-offs: correctness guarantees vs. performance
