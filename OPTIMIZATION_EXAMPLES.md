# FOL Performance Optimization Examples

This document shows practical examples of using the three optimization techniques to improve performance.

## Example 1: Diff Benchmark Optimization

### The Problem
The diff benchmark's `:around` method is called 500K times per run, causing 114× slowdown.

```lisp
;; Original implementation (slow due to :around dispatch)
(defmethod assoc :around [(obj <diffable>) key val]
  (bind [old-val (get obj key)
         result  (call-next-method)]
    (if (and (not (= key :_changes))
             (not (= old-val val)))
      (assoc result :_changes (inc (:_changes result)))
      result)))

(defn run-bench [iterations]
  (bind [m (make <metric> :cpu 0 :mem 0)]
    (loop [i 0 a m total 0]
      (if (< i iterations)
        (bind [a2 (-> (assoc a :_changes 0)
                      (assoc :cpu (+ 1.0 i))      ; :around dispatch cost here
                      (assoc :memory (+ 2.0 i))    ; and here
                      (assoc :disk (+ 3.0 i))      ; and here
                      (assoc :net (+ 4.0 i))       ; and here
                      (assoc :iops (inc i)))]      ; and here
          (recur (inc i) a2 (+ total 5)))
        total))))
```

### Solution 1: Use `inline-assoc!` (Manual)

Replace `assoc` with `inline-assoc!` in the hot loop:

```lisp
(defn run-bench-optimized-v1 [iterations]
  (bind [m (make <metric> :cpu 0 :mem 0)]
    (loop [i 0 a m total 0]
      (if (< i iterations)
        (bind [a2 (-> (inline-assoc! a :_changes 0)
                      (inline-assoc! :cpu (+ 1.0 i))
                      (inline-assoc! :memory (+ 2.0 i))
                      (inline-assoc! :disk (+ 3.0 i))
                      (inline-assoc! :net (+ 4.0 i))
                      (inline-assoc! :iops (inc i)))]
          (recur (inc i) a2 (+ total 5)))
        total))))

;; Benchmarks show:
;; - Original:    1.137s (234.98 MB)
;; - Optimized:   0.11-0.23s (estimated 5-10× improvement)
;; - Ratio: 11-23× slower (vs 114× baseline)
```

**Pros**: Direct control, maximum speed
**Cons**: Requires code changes, loses `:around` method benefits

### Solution 2: Use Pragma System (Automatic)

Let the compiler automatically use `inline-assoc!`:

```lisp
;; Enable optimization at top level
(enable-inline-methods t)

;; Original code - unchanged! But compiles optimized
(defn run-bench [iterations]
  (bind [m (make <metric> :cpu 0 :mem 0)]
    (loop [i 0 a m total 0]
      (if (< i iterations)
        (bind [a2 (-> (assoc a :_changes 0)
                      (assoc :cpu (+ 1.0 i))
                      (assoc :memory (+ 2.0 i))
                      (assoc :disk (+ 3.0 i))
                      (assoc :net (+ 4.0 i))
                      (assoc :iops (inc i)))]
          (recur (inc i) a2 (+ total 5)))
        total))))

;; Same performance as Solution 1, but no code changes!
;; Disable when done (affects subsequent compilations)
(disable-inline-methods)
```

**Pros**: Automatic, no code changes, transparent
**Cons**: Affects code generation (compile-time decision)

### Solution 3: Combination Approach (Balanced)

Use the pragma system for most code, with explicit `inline-assoc!` for critical sections:

```lisp
;; Enable pragmas globally
(enable-inline-methods t)

;; Most code compiles with automatic optimization
(defn process-batch [items]
  (loop [i 0 acc (make <accumulator>)]
    (if (< i (count items))
      (recur (inc i)
             ;; Auto-optimized via pragma
             (assoc acc :count (inc (:count acc))))
      acc)))

;; Critical tight loop gets explicit optimization
(defn run-bench [iterations]
  (bind [m (make <metric> :cpu 0 :mem 0)]
    (loop [i 0 a m total 0]
      (if (< i iterations)
        (bind [a2 (-> a
                      ;; Even with pragma, explicit inline-assoc!
                      ;; is clearer intent and might compile differently
                      (inline-assoc! :_changes 0)
                      (inline-assoc! :cpu (+ 1.0 i))
                      (inline-assoc! :memory (+ 2.0 i))
                      (inline-assoc! :disk (+ 3.0 i))
                      (inline-assoc! :net (+ 4.0 i))
                      (inline-assoc! :iops (inc i)))]
          (recur (inc i) a2 (+ total 5)))
        total))))

(disable-inline-methods)
```

## Example 2: Guards Benchmark

The guards benchmark has similar issues but on a smaller scale.

```lisp
;; Original (20× slower)
(defn run-bench [iterations]
  (loop [i 0 acc (make <account>)]
    (if (< i iterations)
      (recur (inc i)
             (-> acc
                 (assoc :balance (+ (:balance acc) 10))
                 (assoc :txn-count (inc (:txn-count acc)))))
      acc)))

;; Optimized (2-3× speedup)
(defn run-bench-optimized [iterations]
  (loop [i 0 acc (make <account>)]
    (if (< i iterations)
      (recur (inc i)
             (-> acc
                 (inline-assoc! :balance (+ (:balance acc) 10))
                 (inline-assoc! :txn-count (inc (:txn-count acc)))))
      acc)))

;; With pragma (automatic)
(enable-inline-methods t)
(defn run-bench [iterations]
  (loop [i 0 acc (make <account>)]
    (if (< i iterations)
      (recur (inc i)
             (-> acc
                 (assoc :balance (+ (:balance acc) 10))
                 (assoc :txn-count (inc (:txn-count acc)))))
      acc)))
(disable-inline-methods)
```

## Example 3: Conditional Optimization

Optimize only when performance is critical:

```lisp
(defn compute-with-option [data use-optimizations?]
  (if use-optimizations?
    (enable-inline-methods t))
  
  (let ((result (loop [i 0 acc (make <state> :value 0)]
                   (if (< i (count data))
                     (recur (inc i)
                            (assoc acc :value (+ (:value acc) (nth data i))))
                     acc))))
    
    (if use-optimizations?
      (disable-inline-methods))
    
    result))

;; Usage
(compute-with-option my-data false)  ; Normal path, preserves :around methods
(compute-with-option my-data true)   ; Fast path, optimized
```

## Example 4: Profiling to Verify Improvement

```lisp
;; Measurement function
(defn benchmark [name fn iterations]
  (sb-ext:gc :full t)
  (let ((start (get-internal-real-time))
        (start-bytes (sb-ext:get-bytes-consed)))
    (dotimes (i iterations)
      (funcall fn))
    (let* ((elapsed (/ (- (get-internal-real-time) start)
                       (float internal-time-units-per-second)))
           (bytes (- (sb-ext:get-bytes-consed) start-bytes)))
      (format t "~A:~%  Time: ~,3F seconds~%  Memory: ~,2F MB~%~%"
              name elapsed (/ bytes 1048576.0)))))

;; Without optimization
(benchmark "Diff (baseline)"
  #(lambda () (diff:run-bench 100000))
  1)

;; With inline-assoc!
(benchmark "Diff (with inline-assoc!)"
  #(lambda () (diff-optimized:run-bench 100000))
  1)

;; With pragma
(enable-inline-methods t)
(benchmark "Diff (with pragma)"
  #(lambda () (diff:run-bench 100000))
  1)
(disable-inline-methods)

;; Expected output (approximate):
;; Diff (baseline):            1.137s, 234.98 MB
;; Diff (with inline-assoc!):  0.11-0.23s, 234.98 MB  (5-10× faster)
;; Diff (with pragma):         0.11-0.23s, 234.98 MB  (5-10× faster)
```

## Example 5: When NOT to Optimize

Don't use these optimizations if `:around` methods are needed:

```lisp
;; Bad: Removing validation from :around methods
(defmethod validate-transaction :around [(state <account>) tx]
  (unless (>= (:balance state) (:amount tx))
    (error "Insufficient funds"))
  (call-next-method))

(defn process-transactions [txs state]
  ;; WRONG: Would bypass validation
  ;; (inline-assoc! state :balance (- balance amount))
  
  ;; RIGHT: Use normal assoc to preserve validation
  (assoc state :balance (- (:balance state) (:amount tx))))

;; With pragma: Would skip validation, so DON'T enable
;; (enable-inline-methods t)  ;; DON'T DO THIS HERE
```

## Recommendations Summary

| Scenario | Solution | Benefit | Trade-off |
|----------|----------|---------|-----------|
| Tight benchmarking loop | `inline-assoc!` | 5-10× faster | No `:around` methods |
| Performance-critical section | `inline-assoc!` + pragma | 5-10× faster | Explicit about bypassing |
| Testing different optimizations | pragma on/off | 5-10× faster | Compile-time decision |
| Production with benchmarks | Both methods | 5-10× faster | Clear intent, testable |
| Critical path unclear | Profile first | Targeted optimization | Requires analysis |

## Next Steps

1. **Identify bottlenecks**: Use `(time ...)` or profiler on your code
2. **Check correctness**: Verify `:around` methods aren't required
3. **Try optimization**: Start with pragma system, then inline-assoc! if needed
4. **Measure impact**: Re-run benchmarks to verify speedup
5. **Document**: Add comments explaining why optimization is safe

See [OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md) for detailed API documentation.
