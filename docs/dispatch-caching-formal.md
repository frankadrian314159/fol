# FOL Dispatch Caching: Formal Semantics and Analysis

**Date**: May 14, 2026  
**Version**: 2.0 (Research-Grade)

---

## 1. Formal Cache Model

### 1.1 System Definition

We model the dispatch cache system as a tuple:
$$\text{Cache} = (T, H, M, G, M_{gf})$$

Where:
- **$T$**: Hash table mapping keys to cached dispatch results
- **$H$**: Atomic counter (hit count)
- **$M$**: Atomic counter (miss count)  
- **$G$**: Generation counter (monotonically increasing)
- **$M_{gf}$**: Method-definition epoch for each generic function

### 1.2 Operations

#### Lookup
```
cache-lookup(cache, key):
  if key ∈ cache.T:
    atomic-incf(cache.H)
    return cache.T[key]
  else:
    atomic-incf(cache.M)
    return NIL
```

**Properties**:
- Atomic: all-or-nothing from caller's perspective
- Linearizable: hit/miss counters reflect real event order

#### Invalidation
```
flush-all-caches():
  for each cache ∈ registry:
    clrhash(cache.T)
    cache.H ← 0
    cache.M ← 0
    atomic-incf(cache.G)
```

**Correctness Property**: 
After `flush-all-caches()` completes, for all future lookups, if a method of any generic function has changed since the cache was created, subsequent executions produce correct results.

### 1.3 Correctness Specification

**Invariant (Conservative Invalidation)**:

For a cached dispatch result $r$ stored at key $k$ for function $f$:
$$\text{Valid}(r) \iff \forall \, \text{GF} \in \text{CallSet}(f): M_{gf} = M_{gf}^{\text{create}}$$

Where:
- $\text{CallSet}(f)$: Set of generic functions called by $f$ (statically conservative approximation)
- $M_{gf}^{\text{create}}$: Method epoch when $f$ was compiled
- $M_{gf}$: Current method epoch

**Conservative Invalidation Guarantee**:
When any GF's methods change, `flush-all-caches!` is called, setting all caches' epochs to a new value. No stale results can be returned because:

1. **Per-entry atomicity**: SBCL's `:synchronized t` hash-table guarantees `gethash` is atomic per-entry
2. **Generation counter**: Updated atomically; can be used by callers to detect invalidation
3. **No stale re-entry**: Generation counter prevents re-using a cached result after flush

**Concurrent Access**:

Thread A may call `cache-lookup(cache, k)` while Thread B calls `flush-all-caches()`. Outcomes:
- ✅ A gets stale result (returns cached value before flush): **Safe**—result is from a valid state
- ✅ A misses cache (flush removes entry before lookup): **Safe**—A falls through to COND evaluation
- ✅ A's hit/miss counter update races with flush's zero: **Safe**—counter is reset afterward

**Memory Model**: 
Requires SBCL's memory semantics (synchronized tables, atomic increments). Not portable to other CL implementations without equivalent primitives.

### 1.4 Aggressive Invalidation (Optional)

**Definition**:
When `*aggressive-cache-invalidation*` is true, only flush the caches of the GF whose methods changed:

```
flush-gf-caches!(gf-name):
  for each cache ∈ registry[gf-name]:
    clrhash(cache.T)
    atomic-incf(cache.G)
```

**Correctness**:
Invariant becomes:
$$\text{Valid}(r) \iff M_{gf} = M_{gf}^{\text{create}}$$

**Trade-off**: Faster (fewer cache flushes) but **requires** that:
- No `defn` outside the GF calls the GF with changed methods
- No predicate guards reference external GFs

**Developer responsibility**: If violated, silent correctness bugs result.

---

## 2. Asymptotic Analysis

### 2.1 Speedup Model

**Parameters**:
- $N$: Number of dispatch clauses
- $K$: Number of distinct argument types observed at runtime
- $c_{hit}$: Cost of a cache hit (hash-table lookup, ~1 µs)
- $c_{test}$: Cost of evaluating a single test predicate (~10 µs for type check)
- $p$: Hit rate (probability that a call hits the cache)

**Cost Model**:

On each call, we either:
- Hit cache: Cost = $c_{hit}$
- Miss cache: Cost = $O(N) \times c_{test} + c_{insert}$ (evaluate $N$ tests, then insert)

Expected cost per call:
$$E[\text{Cost}] = p \cdot c_{hit} + (1-p) \cdot (N \cdot c_{test} + c_{insert})$$

**Without caching** (pure COND):
$$\text{Cost}_{\text{COND}} = E[\text{# tests}] \times c_{test} = \frac{N+1}{2} \times c_{test}$$

(Average case: tests half the clauses before matching)

**Speedup**:
$$\text{Speedup}(N, K, p) = \frac{\text{Cost}_{\text{COND}}}{E[\text{Cost}]} = \frac{(N+1) \times c_{test}}{2(p \times c_{hit} + (1-p) \times (N \times c_{test}))}$$

### 2.2 Hit Rate as Function of K

Assume uniform distribution over $K$ distinct types:
$$p = \frac{K_{\text{seen}}}{K} \approx 1 - e^{-\frac{M}{K}}$$

Where $M$ is the number of calls (via coupon collector approximation).

**Asymptotic behavior**:
- $K = 1$ (single type): $p \to 1$ → Speedup $\approx \frac{(N+1) \times c_{test}}{2 \times c_{hit}} = O(N)$
- $K = N$ (one type per clause): $p \approx \frac{M \ln N}{M} = \ln N$ → Speedup $\approx \frac{(N+1)}{2 \ln N}$ → $O(\frac{N}{\ln N})$
- $K >> N$ (many rare types): $p \to 0$ → Speedup $\to 1$ (no benefit)

### 2.3 Memory Usage

**Cache table size**:
- Per entry: ~40 bytes (hash-table overhead + key + value pointer)
- In worst case: $O(K)$ entries (one per distinct type/value)

$$\text{Memory} = O(K) \times 40 \text{ bytes}$$

**Practical**: For $K = 1000$ distinct types, $\approx 40$ KB per function. For $K = 10000$, $\approx 400$ KB.

### 2.4 Theoretical Speedup Bounds

**Best case** ($K = 1$, single type):
$$\text{Speedup}_{\max} = \frac{(N+1) \times c_{test}}{2 \times c_{hit}} \approx \frac{10N}{2} = 5N$$

For $N = 4$ clauses: $\approx 20\times$  
For $N = 20$ clauses: $\approx 100\times$

**Realistic case** ($K = 4$, round-robin types, $p = 0.75$):
$$\text{Speedup} = \frac{(N+1) \times 10}{2(0.75 \times 1 + 0.25 \times (N \times 10))} = \frac{10(N+1)}{2(0.75 + 2.5N)} \approx \frac{10N}{5N} = 2$$

For $N = 4$: $\approx 2.0\times$  
For $N = 20$: $\approx 1.8\times$

**Worst case** ($K >> N$, rare types, $p \to 0$):
$$\text{Speedup} \to 1$$ (no benefit)

---

## 3. Hit Rate Characterization

### 3.1 Workload Profiles

**Profile 1: Single-Type** (Best case)
- Example: A loop processing integers exclusively
- Hit rate: 99%+
- Expected speedup: $O(N)$

**Profile 2: Round-Robin** (Realistic, 4 types)
- Example: Processing mixed int/float/string/vector data
- Hit rate: 75%–85% (initial misses for each new type, then hits)
- Expected speedup: 1.8–2.0×

**Profile 3: Many Rare Types** (Worst case)
- Example: Dispatch on user-defined classes, 100+ types
- Hit rate: 5%–20%
- Expected speedup: 1.0–1.2×

**Profile 4: Bursty** (Realistic, temporal locality)
- Example: Process all integers, then all strings, then all integers
- Hit rate: Depends on burst size; if bursts are large, $p \approx 0.9$
- Expected speedup: 4–5×

### 3.2 Actual Hit Rate Measurement

Code to measure:
```lisp
(multiple-value-bind (hits misses gen size)
    (fol.compiler.dispatch:inspect-fn-cache 'my-fn)
  (let ((total (+ hits misses)))
    (format t "Hit rate: ~,1F% (~D/~D)~%" 
            (* 100 (/ hits total)) hits total)))
```

---

## 4. Comparison to Alternatives

### 4.1 Bytecode Versioning

**Approach**: Compile bytecode with embedded method epoch. Recompile when epoch changes.

**Pros**:
- Eliminates cache invalidation races
- Can inline type checks in compiled code
- Automatic adaptation to new methods

**Cons**:
- Expensive recompilation on every method change
- More complex implementation (bytecode infrastructure needed)
- Higher memory usage (multiple versions of each function)

**Estimated cost**: 100–1000× slower than cache flush on method change (full recompilation vs. hash-table clear).

### 4.2 Dependency-Based Invalidation

**Approach**: Statically track which GFs each defn calls. Flush only dependent caches on method change.

**Pros**:
- More efficient than conservative flush
- Enables aggressive mode by default
- Eliminates closure-capture surprise bugs

**Cons**:
- Complex static analysis (needs call-graph analysis)
- Handles only statically-known calls; dynamic dispatch escapes
- Adds compile-time overhead

**Estimated implementation cost**: 500–1000 lines of code (call-graph analysis, dependency registry).

### 4.3 JIT Specialization

**Approach**: Compile specialized versions of function for top 3–5 types; fall back to cache for others.

**Pros**:
- Eliminates dispatch overhead entirely for hot types
- Can inline type checks and operations
- Unbounded speedup potential

**Cons**:
- Complex JIT infrastructure (not present in FOL)
- Warm-up time before specialization kicks in
- Memory usage per specialized version

**Estimated speedup**: 3–5× (vs. 2–3× for caching), but 10–50× implementation complexity.

### 4.4 Type-Annotation at Call Sites

**Approach**: Callers provide type information; skip dispatch if annotated.

```lisp
(defn process [x]
  (if (integer? x) (+ x 1) (other x)))

;; With annotations:
(process ^integer 42)  ; Skip dispatch, call integer clause directly
```

**Pros**:
- Simple implementation (just check annotation before dispatch)
- Zero cache miss cost (no dispatch if annotated)

**Cons**:
- Requires discipline from callers (error-prone)
- Doesn't help with polymorphic code (can't annotate)
- Type annotation syntax is non-standard

**Estimated speedup**: Unbounded (if annotated), 1.0× (if not).

### 4.5 Summary Comparison

| Approach | Implementation | Warm-Up | Speedup | Memory | Notes |
|----------|---|---|---|---|---|
| **Conservative Cache** (current) | 200 LOC | Immediate | 2–3× | $O(K)$ | Safe, simple, real-time |
| Bytecode Versioning | 1000+ LOC | Slow (recompile) | 3–5× | $O(\text{versions})$ | Complex, overhead on method changes |
| Dependency Tracking | 500–1000 LOC | Immediate | 2–3× | $O(K)$ | More efficient, harder to implement |
| JIT Specialization | 5000+ LOC | Slow (warmup) | 3–5× | $O(\text{types})$ | Best speedup, infra-heavy |
| Type Annotations | 100 LOC | Immediate | ∞ | $O(1)$ | Caller burden, limited applicability |

---

## 5. Developer Guidelines

### 5.1 When to Enable Caching (Default: ON)

**Caching is beneficial when**:
- $N \geq 4$ (4 or more dispatch clauses)
- Workload has temporal locality ($K \ll M$, where $K$ = distinct types, $M$ = total calls)
- Dispatch overhead matters (tight loops, high-frequency calls)

**Caching is not beneficial when**:
- $N < 4$ (overhead > benefit)
- Workload is uniformly random over many types (hit rate $\approx 1/K$)
- Memory is constrained and $K$ is large

### 5.2 Memory Monitoring

**Track cache size**:
```lisp
(defun cache-memory-usage (fn-name)
  "Estimate memory usage of function's cache in KB."
  (multiple-value-bind (hits misses gen size)
      (fol.compiler.dispatch:inspect-fn-cache fn-name)
    (let ((bytes (* size 40)))  ; ~40 bytes per entry
      (/ bytes 1024.0))))

;; Example:
(cache-memory-usage 'my-fn)  ; => 40.5 KB (1010 entries)
```

**Warnings**: If cache exceeds 10 MB, consider:
1. Disabling caching (add `&rest` parameter or split into smaller functions)
2. Restructuring code to reduce type cardinality
3. Implementing manual cache eviction (LRU policy)

### 5.3 Opt-Out Strategies

**Strategy 1: Add `&rest` parameter**
```lisp
;; Cached (4 clauses):
(defn classify [x]
  (cond ((integer? x) :int) ((float? x) :float) ...))

;; Not cached (variable arity):
(defn classify [x &rest args]
  (cond ((integer? x) :int) ((float? x) :float) ...))
```

**Strategy 2: Reduce clause count below 4**
```lisp
;; Cached (5 clauses):
(defn process [x] (if (int? x) ... (if (float? x) ... ...)))

;; Not cached (3 clauses):
(defn process [x] (if (int? x) ... (if (float? x) ... ...)))
```

**Strategy 3: Set *aggressive-cache-invalidation* = nil** (default)
- Ensures correctness by flushing all caches on method change
- Can cause unnecessary cache flushes in modular code

### 5.4 Closure-Capture Avoidance

**Pattern 1: Avoid cross-GF dependencies**
```lisp
;; RISKY: defn depends on external GF
(defn check-value [x]
  (if (valid? x) :valid :invalid))  ; valid? is an external GF

;; SAFE: Reduce to fewer clauses
(defn check-value [x]
  (if (integer? x)
      (if (valid? x) :valid :invalid)  ; Only 2 clauses, not cached
      :unknown))
```

**Pattern 2: Explicitly redefined after method changes**
```lisp
;; Add a new method to an external GF
(defmethod valid? ((x custom-type)) t)

;; Redefinition forces fresh cache
(defn check-value [x]
  (if (valid? x) :valid :invalid))
```

**Pattern 3: Use flush-gf-caches!**
```lisp
;; After adding methods to a specific GF:
(defmethod process [x] ...)
(fol.compiler.dispatch:flush-gf-caches! 'process)
```

### 5.5 Profiling Cache Effectiveness

**Benchmark template**:
```lisp
(defun benchmark-cache (fn-name arg-list num-calls)
  "Measure cache hit rate and speedup."
  (let* ((fn (symbol-function fn-name))
         ;; Warm-up
         (warm-count (floor num-calls 10)))
    (loop repeat warm-count do (funcall fn (random-arg)))
    
    ;; Timed run
    (let ((start (get-internal-real-time)))
      (loop repeat num-calls do (funcall fn (random-arg)))
      (let ((elapsed (/ (- (get-internal-real-time) start) 1000.0)))
        
        ;; Report
        (multiple-value-bind (hits misses gen size)
            (fol.compiler.dispatch:inspect-fn-cache fn-name)
          (let ((total (+ hits misses))
                (hit-rate (/ hits (max 1 total))))
            (format t "~A: ~,1F% hit rate, ~D entries, ~,2F ms total~%"
                    fn-name (* 100 hit-rate) size elapsed)))))))
```

---

## References

- Chambers, C., & Ungar, D. (1989). "Customization: Optimizing Compiler Technology for SELF, a Dynamically-Typed Object-Oriented Language." PLDI.
- Hölzle, U., Chambers, C., & Ungar, D. (1991). "Optimizing Dynamically-Dispatched Calls with Run-Time Type Feedback." PLDI.
- Deutsch, L., & Schiffman, A. M. (1984). "Efficient Implementation of the Smalltalk-80 System." POPL.
