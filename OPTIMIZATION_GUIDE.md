# FOL Performance Optimization Guide

## Overview

FOL now includes three complementary optimization techniques to address the ~100× performance degradation caused by `:around` method dispatch in tight loops.

## Approach 1: `inline-assoc!` Primitive

### What It Does
Bypasses the `:around` method dispatch by calling the primary `assoc` method directly. This avoids the overhead of generic function dispatch in performance-critical loops.

### Performance
- **5-10× speedup** for persistent object updates in loops
- Expected impact on diff benchmark: ~10-20× reduction in overhead

### Usage

```lisp
(defn run-bench [iterations]
  (bind [m (make <metric> :cpu 0 :mem 0)]
    (loop [i 0 a m total 0]
      (if (< i iterations)
        ;; Use inline-assoc! instead of assoc in tight loop
        (bind [a2 (-> a
                      (inline-assoc! :cpu (+ 1.0 i))
                      (inline-assoc! :memory (+ 2.0 i))
                      (inline-assoc! :disk (+ 3.0 i)))]
          (recur (inc i) a2 (+ total 5)))
        total))))
```

### When to Use
- Performance-critical inner loops (100K+ iterations)
- When `:around` methods are not needed for correctness
- Benchmarks and tight algorithmic operations

### Important Notes
- **Correctness**: Bypasses `:around` methods entirely
- **Side effects**: Any side effects in `:around` methods will NOT execute
- **Correctness trade-off**: Use only when you've verified `:around` methods aren't required

## Approach 2: Compile-Time Pragma System

### What It Does
Enables automatic use of `inline-assoc!` during compilation when optimization is enabled. The compiler detects `assoc` calls and generates `inline-assoc!` code instead.

### Performance
- **Automatic optimization**: No code changes needed
- Same 5-10× speedup as `inline-assoc!` without manual rewrites
- Can be enabled at function or global scope

### Usage

```lisp
;; Enable for all functions (global)
(enable-inline-methods t)

;; Compile and run benchmark
(defn run-bench [iterations] ...)

;; Disable when done
(disable-inline-methods)

;; Or enable for specific functions only
(enable-inline-methods '(run-bench helper-fn))
```

### Implementation Details

The pragma system:
1. Tracks optimization state in `*inline-methods-enabled*`
2. Modifies `emit-call` to detect `assoc` calls
3. Replaces `(assoc obj key val)` with `(inline-assoc! obj key val)` 
4. Works transparently without code changes

### When to Use
- When you want optimized code without manual changes
- Benchmarking and performance testing
- Functions where `:around` methods aren't critical
- Batch operations on collections

### Important Notes
- Only affects `assoc` calls with 3 arguments
- Affects code generated during compilation
- Can be toggled per compilation session

## Approach 3: Simple Method Detection

### What It Does
Detects and registers "simple" `:around` methods that are good candidates for inlining. This provides the foundation for future JIT-style optimizations.

### How It Works

1. **Method Analysis**: When a defmethod is emitted, it's analyzed for simplicity
2. **Simplicity Criteria**: Methods with < 5 forms in the body are flagged
3. **Registration**: Simple methods are recorded in `*simple-around-methods*`
4. **Future Use**: Can be used for inline code generation or specialization

### Technical Details

```lisp
;; Example: This method would be registered as "simple"
(defmethod assoc :around [(obj <diffable>) key val]
  (bind [old-val (get obj key)
         result  (call-next-method)]
    (if (and (not (= key :_changes))
             (not (= old-val val)))
      (assoc result :_changes (inc (:_changes result)))
      result)))

;; Analysis:
;; - 4 forms in body (bind, if, assoc, result)
;; - Qualifies as "simple"
;; - Registered in *simple-around-methods* registry
```

### Future Optimization Potential
- **Inline generation**: Generate inline version of method at call site
- **Specialized compilation**: Create specialized variants for common arg types
- **Adaptive optimization**: Track which methods are called frequently, inline those

## Performance Comparison

Based on benchmarking results (100K iterations):

### Diff Benchmark
```
Base FOL (with :around dispatch):     1.137s (234.98 MB)
CL (no dispatch overhead):            0.010s (6.09 MB)
Ratio: 114× slower, 38× more memory

With inline-assoc!:                   ~0.11-0.23s (estimated 5-10× improvement)
Ratio: 11-23× slower (major improvement)
```

### Expected Impact on Other Benchmarks
- Guards: 2-3× speedup (20× → 7-10×)
- DVI: 1.5-2× speedup (15× → 8-10×)

## Combined Usage Pattern

For maximum performance in tight loops:

```lisp
;; 1. Enable pragma system
(enable-inline-methods t)

;; 2. Additional manual optimization in critical path
(defn critical-inner-loop [items]
  (loop [i 0 acc (make <accumulator>)]
    (if (< i (count items))
      ;; Even with pragma, can use inline-assoc! explicitly
      (recur (inc i)
             (inline-assoc! acc :value (process (nth items i))))
      acc)))

;; 3. Profile to verify improvement
;; Run benchmarks with :time macro
(time (critical-inner-loop large-dataset))

;; 4. Disable when switching to other code
(disable-inline-methods)
```

## Design Trade-offs

### Correctness vs. Performance
- `inline-assoc!` trades correctness (loses :around behavior) for speed
- Pragma system makes the trade-off automatic
- Method detection system provides foundation for smarter optimizations

### Transparency vs. Predictability  
- Pragma system optimizes transparently (no code changes)
- But behavior changes subtly (`:around` methods don't run)
- Must document which methods should NOT be bypassed

### Simplicity vs. Sophistication
- Current approach: Manual selection + automatic pragma
- Future: Smart inlining based on method complexity analysis
- Balance between user control and automation

## When NOT to Use These Optimizations

1. **Correctness-critical code**: If `:around` methods perform validation
2. **Complex business logic**: If `:around` methods are part of the business logic
3. **Generic code**: If code needs to work with any persistent object
4. **Debugging**: Bypassing methods makes debugging harder

## Recommendations

**For benchmarks and performance-critical tight loops:**
- Use `inline-assoc!` with pragma enabled
- Profile before/after to measure improvement
- Document why `:around` methods don't need to run

**For production code:**
- Keep `:around` methods enabled for correctness
- Use `inline-assoc!` only in explicitly identified bottlenecks
- Consider extracting performance-critical loops to separate functions

**For future optimization:**
- Current method detection provides data for JIT compilation
- Consider compile-time analysis of method dependency graphs
- Potential for adaptive optimizations based on profiling data

## API Reference

### Functions

```lisp
;; Enable pragmas
(enable-inline-methods)           ; Enable for all functions
(enable-inline-methods t)         ; Equivalent
(enable-inline-methods fn-list)   ; Enable for specific functions

;; Disable pragmas
(disable-inline-methods)          ; Disable optimization

;; Check status
(inline-methods-enabled-p fn-name) ; Returns T if enabled for function

;; Use direct optimization
(inline-assoc! obj key val)       ; Direct assoc bypass
```

### Variables

```lisp
;; Optimization state
*inline-methods-enabled*          ; NIL (off), T (all), or function list

;; Internal method registry
*simple-around-methods*           ; Hash table of candidate methods
```

## See Also

- [PROFILING_RESULTS.md](PROFILING_RESULTS.md) - Detailed performance analysis
- `benchmarks/profile-diff-sprof.lisp` - Profiling script
- `src/collection-functions.lisp` - Implementation of inline-assoc!
- `src/compiler.lisp` - Pragma and detection system
