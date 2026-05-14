# FOL Dispatch Caching: Developer Guidelines

**Date**: May 14, 2026  
**Audience**: FOL developers, library authors, application engineers

---

## Quick Start

### Enable Caching (Default: ON)

Caching is **automatically enabled** for:
- Functions with 4+ dispatch clauses
- Single-clause functions with 4+ `cond` branches

### Check if Caching is Active

```lisp
(multiple-value-bind (hits misses gen size)
    (fol.compiler.dispatch:inspect-fn-cache 'my-function)
  (if hits
      (format t "Cached: ~D% hit rate (~D/~D)~%"
              (* 100 (/ hits (+ hits misses))) hits misses)
      (format t "Not cached~%")))
```

### Monitor Memory Usage

```lisp
(defun cache-status ()
  "Print cache status for all cached functions."
  (fol.compiler.dispatch:inspect-fn-cache 'my-fn1)  ; Check specific functions
  (fol.compiler.dispatch:inspect-fn-cache 'my-fn2)
  ;; Sum memory: entries × ~40 bytes
  )
```

---

## 1. When to Enable/Disable Caching

### Enable Caching When

✅ **Performance matters**: Function is called frequently in tight loops  
✅ **Dispatch overhead is visible**: Profiler shows dispatch in hot path  
✅ **Clause count is 4+**: Benefit exceeds overhead  
✅ **Workload has locality**: Same types appear repeatedly (not uniformly random)

**Example: Enable caching**
```lisp
(defn process-data [x]
  ;; 6 clauses → CACHED automatically
  (cond
    ((integer? x) (process-int x))
    ((float? x) (process-float x))
    ((string? x) (process-string x))
    ((vector? x) (process-vector x))
    ((map? x) (process-map x))
    (t (process-other x))))

;; Call this in a tight loop?
(loop for item in large-dataset do
  (process-data item))
;; Cache helps here!
```

### Disable Caching When

❌ **Memory is constrained**: Function may see 1000+ distinct types  
❌ **Performance doesn't matter**: Function called rarely, not in hot path  
❌ **Clause count < 4**: Overhead > benefit  
❌ **Workload is uniform**: Random access to many types (hit rate ≈ 1/K)

**Example: Disable caching (add `&rest`)**
```lisp
;; BEFORE (will be cached):
(defn rare-function [x]
  (cond ((integer? x) :int)
        ((float? x) :float)
        ((string? x) :string)
        (t :other)))

;; AFTER (not cached, called rarely):
(defn rare-function [x &rest _]
  (cond ((integer? x) :int)
        ((float? x) :float)
        ((string? x) :string)
        (t :other)))
```

---

## 2. Memory Monitoring and Limits

### Monitor Cache Size

```lisp
(defun report-cache-memory ()
  "Report memory usage of all caches."
  (let ((total-bytes 0)
        (functions '(process-data classify transform)))
    (dolist (fn functions)
      (multiple-value-bind (hits misses gen size)
          (fol.compiler.dispatch:inspect-fn-cache fn)
        (when hits
          (let ((bytes (* size 40)))  ; ~40 bytes per entry
            (format t "~A: ~D entries (~,1F KB)~%" fn size (/ bytes 1024.0))
            (incf total-bytes bytes)))))
    (format t "Total: ~,1F MB~%" (/ total-bytes 1024.0 1024.0))))
```

### Set Memory Limits

**Recommended thresholds**:
- ≤ 1 MB per function: Fine (typically <30k types)
- 1–10 MB per function: Monitor; consider restructuring
- > 10 MB per function: Problematic; disable caching or split function

**Example: Warn on excessive cache size**
```lisp
(defun check-cache-health ()
  "Warn if caches are growing unboundedly."
  (let ((threshold-kb 1024))  ; 1 MB per function
    (dolist (fn '(big-dispatcher complex-processor))
      (multiple-value-bind (h m g size)
          (fol.compiler.dispatch:inspect-fn-cache fn)
        (when (and h (> (* size 40) (* threshold-kb 1024)))
          (warn "Cache for ~A exceeding ~D KB (currently ~,0F KB)"
                fn threshold-kb (/ (* size 40) 1024.0)))))))

;; Call periodically in long-running processes
(run-every-minute #'check-cache-health)
```

### Cache Eviction (Manual)

FOL caches are unbounded by default. If memory becomes critical:

**Option 1: Flush all caches**
```lisp
(fol.compiler.dispatch:flush-all-caches!)
;; ⚠️ WARNING: All caches reset to empty; hit rate drops to 0 on next call
```

**Option 2: Implement LRU eviction** (advanced)
```lisp
;; Not built-in; requires custom implementation
;; See src/dispatch.lisp for cache structure
```

**Option 3: Disable caching for memory-heavy functions**
```lisp
;; Redefine with &rest to skip caching
(defn memory-heavy-dispatcher [x &rest _]
  ...)
```

---

## 3. Hit Rate Optimization

### Measure Hit Rate

```lisp
(defun analyze-cache (fn-name &optional (num-calls 100000))
  "Analyze cache hit rate for a function."
  (let ((fn (symbol-function fn-name))
        (test-data (generate-realistic-test-data fn-name)))
    ;; Warm up
    (loop repeat 1000 do
      (funcall fn (random-element test-data)))
    
    ;; Measure
    (let ((start (get-internal-real-time)))
      (loop repeat num-calls do
        (funcall fn (random-element test-data)))
      (multiple-value-bind (hits misses gen size)
          (fol.compiler.dispatch:inspect-fn-cache fn-name)
        (let ((total (+ hits misses)))
          (format t "~A: ~,1F% hit rate (~D/~D) in ~,0F ms~%"
                  fn-name (* 100 (/ hits total)) hits misses
                  (/ (- (get-internal-real-time) start) 1000.0)))))))
```

### Improve Hit Rate

**Issue 1: Many rare types** (random workload)
- Symptom: Hit rate 10–30%, many cache entries
- Solution: Accept low speedup or restructure code
```lisp
;; BEFORE: Dispatches on 100 user-defined classes
(defn generic-processor [obj]
  (cond ((classA? obj) (process-a obj))
        ((classB? obj) (process-b obj))
        ...))

;; AFTER: Use polymorphism instead of dispatch
(defgeneric process (obj))
(defmethod process ((obj class-a)) ...)
(defmethod process ((obj class-b)) ...)
```

**Issue 2: Temporal locality could be better**
- Symptom: Hit rate 50%, but workload is bursty
- Solution: No action needed; cache is working as designed
```lisp
;; This is fine:
;; Process 1000 integers (cache hit on type)
;; Then process 1000 floats (cache miss on new type, then hits)
;; Then back to integers (cache hit on type)
;; Expected: 66% hit rate
```

**Issue 3: Type hierarchy mismatch**
- Symptom: Hitting base type when subtype clause would match
- Solution: Reorder clauses (more specific first)
```lisp
;; BEFORE (low hit rate):
(defn process [x]
  (cond ((number? x) :number)  ; Too general, blocks specific types
        ((integer? x) :int)))   ; Unreachable!

;; AFTER:
(defn process [x]
  (cond ((integer? x) :int)     ; Specific first
        ((number? x) :number)))  ; Fallback
```

---

## 4. Value-Based Dispatch: When Caching Breaks

### ⚠️ CRITICAL: Caching Unsafe with Value Predicates

**Caching assumes dispatch depends ONLY on type, not object properties.**

If you use predicates that depend on object properties (size, magnitude, flags), **caching will produce wrong answers**.

### Unsafe Patterns (❌ Don't do this)

**Pattern 1: Size-based dispatch on reference types**
```lisp
(defn classify-vector [v]
  (cond
    ((> (count v) 100) :large)        ; ← VALUE predicate (unsafe)
    ((< (count v) 10) :small)         ; ← VALUE predicate (unsafe)
    (t :medium)))

;; PROBLEM:
(classify-vector #(1 2 3))           ; :small, cached
(classify-vector #(1 ... 101))       ; WRONG! Returns :small (cache hit, stale)
```

**Pattern 2: Property checks on dicts**
```lisp
(defn analyze-map [m]
  (cond
    ((and (dict? m) (> (count (keys m)) 50)) :large)    ; ← VALUE predicate (unsafe)
    ((and (dict? m) (empty? m)) :empty)                 ; ← VALUE predicate (unsafe)
    (t :normal)))

;; PROBLEM: Different dicts of same class will hit same cache entry
```

**Pattern 3: Mixed type and value predicates**
```lisp
(defn process [x]
  (cond
    ((vector? x) :vec)                          ; ← Type predicate (safe)
    ((and (map? x) (= (count (keys x)) 0)) :empty-map)  ; ← VALUE predicate (unsafe)
    (t :other)))
;; First clause is cached correctly; second clause returns stale results
```

### Safe Patterns (✅ Do this)

**Pattern 1: Type-based dispatch only**
```lisp
(defn process [x]
  (cond
    ((vector? x) :vector)    ; ← Type predicate (safe)
    ((dict? x) :dict)        ; ← Type predicate (safe)
    ((set? x) :set)          ; ← Type predicate (safe)
    (t :other)))
```

**Pattern 2: Value predicates on atoms only**
```lisp
(defn classify-number [n]
  (cond
    ((> n 1000) :large)      ; ← VALUE predicate on fixnum (safe, cached by value)
    ((< n 0) :negative)      ; ← VALUE predicate on fixnum (safe, cached by value)
    ((= n 0) :zero)          ; ← VALUE predicate on fixnum (safe, cached by value)
    (t :normal)))
```

**Pattern 3: Post-dispatch property checks**
```lisp
(defn analyze-collection [coll]
  (if (vector? coll)
      ;; After type dispatch succeeds, property checks are safe (not cached)
      (if (> (count coll) 100) :large :small)
      (if (dict? coll)
          (if (empty? coll) :empty :nonempty)
          :unknown)))
```

### Check Your Code

**Caching safety audit**:
1. Identify all dispatch predicates (conditions in `cond`, `if`, guards)
2. For each predicate on a reference type, ask: "Does this depend on `class-of` alone, or on object properties?"
3. If property-based: Either (a) disable caching, or (b) restructure to type-based dispatch

**Safe predicates**: `type?`, `class-of`, `instanceof`, `kind-of`, `satisfies-type-spec?`  
**Unsafe predicates**: `>`, `<`, `=`, `empty?`, `size`, `count`, `magnitude`, custom property checks

### Disable Caching for Value-Based Functions

```lisp
;; BEFORE (unsafe, will be cached):
(defn classify-collection [coll]
  (cond
    ((and (vector? coll) (> (count coll) 100)) :large-vec)
    ((and (dict? coll) (> (count (keys coll)) 50)) :large-dict)
    (t :normal)))

;; AFTER (safe, not cached because of &rest):
(defn classify-collection [coll &rest _]
  (cond
    ((and (vector? coll) (> (count coll) 100)) :large-vec)
    ((and (dict? coll) (> (count (keys coll)) 50)) :large-dict)
    (t :normal)))
```

---

## 5. Closure Capture: A Language Semantics Issue

### ⚠️ CRITICAL: Breaking Semantic Change

Dispatch caching causes a **breaking change in FOL language semantics**. When a method is added to an external GF that a cached defn calls indirectly, the cached defn may return results from **before the method was added**.

**This violates referential transparency and FOL's dynamic method semantics.**

### The Problem

```lisp
;; Module A: Core library (compiled early)
(defn validate-data [x]
  (if (is-valid? x) :valid :invalid))  ; is-valid? is external GF
                                        ; Cache created at compile time

(validate-data (make-customer))  ; No method for customer → :invalid

;; Module B: Customer extension (loaded later)
(defmethod is-valid? ((x customer)) t)  ; New method added

;; SEMANTIC VIOLATION:
(validate-data (make-customer))  ; Still returns :invalid (cached result!)
                                 ; Should return :valid (new method applies)
```

**Why this happens**:
- When `validate-data` is compiled, its cache is created with knowledge of `is-valid?` methods at that time
- When a new method is added, conservative mode flushes ALL caches, but `validate-data`'s cache was already created
- The next call hits the existing cache entry created before the method existed

### When This Affects You

**Common patterns that trigger closure capture**:
1. **Module A defines defn that calls GF from Module B** (loaded later)
2. **Middleware/framework patterns** where core functions reference plugin GFs
3. **Multi-phase initialization** where methods are added in later phases

### How to Handle It

**Option 1: Always redefine after method changes** (safest, recommended)
```lisp
;; Add new methods:
(defmethod is-valid? ((x customer)) t)

;; Redefine affected functions:
(defn validate-data [x]
  (if (is-valid? x) :valid :invalid))  ; Cache reset
```

**Option 2: Manual cache flush**
```lisp
(defmethod is-valid? ((x customer)) t)
(fol.compiler.dispatch:flush-all-caches!)  ; Clears all caches
;; Expensive but safe
```

**Option 3: Disable caching for "interface" functions**
```lisp
;; Functions that call external GFs: disable caching
(defn validate-data [x &rest _]  ; ← &rest disables caching
  (if (is-valid? x) :valid :invalid))
```

**Option 4: Conservative mode (default, recommended)**
```lisp
;; Default: *aggressive-cache-invalidation* = NIL
;; All caches flushed on ANY method change
;; Cost: Occasional unnecessary cache flushes
;; Benefit: Guaranteed correctness

;; Only use aggressive mode if you can verify:
(setf fol.compiler.dispatch:*aggressive-cache-invalidation* t)
;; Then audit: "Do any defns in this module call external GFs?"
```

### Release Notes Warning

> **Breaking Change: Dispatch Caching and Method Addition**
>
> With dispatch caching enabled (default), adding a method to a GF after a defn
> that calls it has been compiled will NOT retroactively update the cached defn.
> The defn will continue returning cached results from before the method was added.
>
> To ensure correctness after method changes, either:
> 1. Redefine affected functions, or
> 2. Call `(fol.compiler.dispatch:flush-all-caches!)`
>
> For details, see docs/dispatch-caching-semantics.md

**Strategy 4: Use dependency-aware guards** (future)
```lisp
;; Not yet implemented; keep defn definitions near their GF usage
```

---

## 5. Profiling and Benchmarking

### Benchmark Cache Effectiveness

```lisp
(defun benchmark-function (fn-name num-trials num-calls)
  "Benchmark function with multiple trials for statistical rigor."
  (let ((fn (symbol-function fn-name))
        (test-data (generate-test-data)))
    (format t "Benchmarking ~A (~D trials, ~D calls each)~%"
            fn-name num-trials num-calls)
    
    (let ((times nil))
      (loop repeat num-trials do
        ;; Warm up
        (loop repeat 1000 do
          (funcall fn (random-element test-data)))
        
        ;; Timed run
        (let ((start (get-internal-real-time)))
          (loop repeat num-calls do
            (funcall fn (random-element test-data)))
          (let ((elapsed (/ (- (get-internal-real-time) start) 1000.0)))
            (push elapsed times))))
      
      ;; Statistics
      (let* ((times (sort (nreverse times) #'<))
             (mean (/ (reduce #'+ times) (length times)))
             (median (nth (floor (/ (length times) 2)) times))
             (min-t (first times))
             (max-t (last times)))
        (format t "Results (~D trials):~%" (length times))
        (format t "  Mean:   ~,1F ms (~,2F µs/call)~%" mean (/ mean num-calls 1000))
        (format t "  Median: ~,1F ms~%" median)
        (format t "  Min:    ~,1F ms  Max: ~,1F ms~%" min-t max-t)
        (format t "  StdDev: ~,1F ms~%" 
                (sqrt (/ (reduce #'+ (mapcar (lambda (t) (expt (- t mean) 2)) times))
                         (length times))))))
      
      ;; Cache stats
      (multiple-value-bind (hits misses gen size)
          (fol.compiler.dispatch:inspect-fn-cache fn-name)
        (when hits
          (let ((total (+ hits misses))
                (hit-rate (/ hits (max 1 total))))
            (format t "Cache: ~,1F% hit rate (~D/~D), ~D entries~%"
                    (* 100 hit-rate) hits misses size)))))))
```

### Profile with Realistic Data

```lisp
(defun generate-test-data ()
  "Generate test data matching your actual workload."
  ;; For each function, use realistic data distribution
  ;; Examples:
  (vector
    42 3.14 "hello" #(1 2 3)  ; Basic types
    {:x 1 :y 2}               ; Collections
    :keyword                   ; Atoms
    'symbol))

;; Example: AST node profiling
(defun generate-ast-nodes ()
  "Create test AST nodes matching FOL compiler patterns."
  (vector
    (make-instance 'integer-node :value 42)
    (make-instance 'symbol-node :name 'foo)
    (make-instance 'list-node :items (list 1 2 3))
    (make-instance 'quote-node :form '(+ 1 2))))
```

---

## 6. Troubleshooting

### Problem: Unexpectedly Low Hit Rate

**Diagnosis**:
```lisp
(multiple-value-bind (h m g size)
    (fol.compiler.dispatch:inspect-fn-cache 'my-fn)
  (format t "Hits: ~D  Misses: ~D  Ratio: ~,1F%~%"
          h m (* 100 (/ h (+ h m)))))
```

**Causes & Solutions**:

| Hit Rate | Likely Cause | Solution |
|----------|---|---|
| 1–10% | Many rare types | Restructure or disable caching |
| 10–50% | Poor temporal locality | Check if workload is uniform random |
| 50–75% | Expected for 4–5 types | No action needed |
| > 90% | Good locality | Cache is working well |

### Problem: Cache Memory Growing Unboundedly

**Diagnosis**:
```lisp
(defun monitor-cache-growth (fn-name &optional (interval-sec 60))
  "Monitor cache size over time."
  (let ((prev-size 0))
    (loop do
      (multiple-value-bind (h m g size)
          (fol.compiler.dispatch:inspect-fn-cache fn-name)
        (when (> size prev-size)
          (format t "[~A] Cache size: ~D entries (~,0F KB)~%"
                  (get-universal-time) size (/ (* size 40) 1024.0)))
        (setf prev-size size))
      (sleep interval-sec))))
```

**Solutions**:
1. Cap cache size with `*cache-max-entries*` (if implemented)
2. Flush periodically: `(fol.compiler.dispatch:flush-all-caches!)`
3. Disable caching: Add `&rest` parameter

### Problem: Stale Results After Method Changes

**Diagnosis**: You edited a GF and a defn that depends on it now gives wrong results.

**Root Cause**: With `*aggressive-cache-invalidation* = t`, only that GF's caches flushed; unrelated defns not invalidated.

**Solution**:
```lisp
;; Option 1: Use conservative mode (default)
(setf fol.compiler.dispatch:*aggressive-cache-invalidation* nil)

;; Option 2: Redefinition
(defn dependent-fn [x]
  ...)  ; Redefine after method changes

;; Option 3: Manual flush
(fol.compiler.dispatch:flush-gf-caches! 'modified-gf)
```

---

## 7. Best Practices

### ✅ Do

- ✅ **Profile before optimizing**: Measure actual hit rates on real data
- ✅ **Monitor memory**: Check cache size periodically in production
- ✅ **Keep methods and defns together**: Reduce closure-capture risk
- ✅ **Redefinition is cheap**: Redefine functions after method changes
- ✅ **Test with realistic data**: Synthetic benchmarks may not reflect real workloads

### ❌ Don't

- ❌ **Don't blindly trust synthetic benchmarks**: Test on real data
- ❌ **Don't enable aggressive mode lightly**: Only if you're certain of dependencies
- ❌ **Don't ignore memory usage**: Monitor in long-running processes
- ❌ **Don't assume caching is active**: Check with `inspect-fn-cache`
- ❌ **Don't micro-optimize single-clause functions**: Overhead likely exceeds benefit

---

## 8. Examples

### Example 1: AST Visitor (High Hit Rate Expected)

```lisp
(defn visit-node [node]
  ;; 6 clauses → cached
  ;; Typical workload: traverse AST (many nodes of same type)
  ;; Expected hit rate: 85–95%
  (cond
    ((nil? node) nil)
    ((integer-node? node) (process-int node))
    ((symbol-node? node) (process-sym node))
    ((list-node? node) (visit-list (children node)))
    ((quote-node? node) (visit (quoted node)))
    (t (process-generic node))))

;; Measure:
(analyze-cache 'visit-node 100000)
;; Expected: 85–95% hit rate, 2–3× speedup
```

### Example 2: Event Dispatcher (Mixed Workload)

```lisp
(defn dispatch-event [event]
  ;; 5 clauses → cached
  ;; Typical workload: random mix of event types
  ;; Expected hit rate: 60–75%
  (cond
    ((mouse-event? event) (handle-mouse event))
    ((keyboard-event? event) (handle-keyboard event))
    ((timer-event? event) (handle-timer event))
    ((network-event? event) (handle-network event))
    (t (handle-unknown event))))

;; If hit rate is low (< 30%):
(defn dispatch-event [event &rest _]
  ;; Disable caching (< 4 clauses effective)
  ...)
```

### Example 3: Type Coercion (Rare, Disable Caching)

```lisp
;; BEFORE (4 clauses → cached):
(defn coerce-to-number [x]
  (cond ((integer? x) x)
        ((float? x) x)
        ((string? x) (parse-int x))
        (t nil)))

;; AFTER (disabled caching, called rarely):
(defn coerce-to-number [x &rest _]
  (cond ((integer? x) x)
        ((float? x) x)
        ((string? x) (parse-int x))
        (t nil)))
```

---

## Summary

| Task | Command/Pattern |
|------|---|
| Check if cached | `(fol.compiler.dispatch:inspect-fn-cache 'fn)` |
| Measure hit rate | `(analyze-cache 'fn 100000)` |
| Monitor memory | `(cache-status)` |
| Disable caching | Add `&rest _` parameter |
| Force refresh | `(defn fn ...)` (redefinition) |
| Flush all | `(fol.compiler.dispatch:flush-all-caches!)` |
| Enable aggressive | `(setf *aggressive-cache-invalidation* t)` |

---

## Further Reading

- [Formal Semantics](dispatch-caching-formal.md): Correctness guarantees, asymptotic analysis
- [Alternatives](dispatch-caching-alternatives.md): Comparison to bytecode versioning, JIT, etc.
- [Implementation](../src/dispatch.lisp): Cache data structure and operations
