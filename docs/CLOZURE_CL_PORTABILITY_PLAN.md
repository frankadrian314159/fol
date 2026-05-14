# Clozure CL Portability Plan: Dispatch Caching Port

**Date**: May 14, 2026  
**Objective**: Port dispatch caching from SBCL to Clozure CL, demonstrating generality

---

## Executive Summary

**Current state**: Dispatch caching implemented in SBCL with 3 SBCL-specific features:
1. Synchronized hash tables (`:synchronized t`)
2. Atomic increment operations (`sb-ext:atomic-incf`)
3. SBCL-specific type declarations

**Portability goal**: Create portable Clozure CL version to demonstrate the algorithm works across Lisps.

**Effort estimate**: 2–3 weeks (implementation + testing + validation)

**Expected benefit**: +10% publication confidence (shows generality beyond SBCL)

---

## SBCL-Specific Code Analysis

### 1. Synchronized Hash Tables

**Current code** (dispatch.lisp:17):
```lisp
(make-hash-table :test 'equal :synchronized t)
```

**Issue**: `:synchronized t` is SBCL-specific. Creates a lock-protected hash table for thread-safe concurrent access.

**Clozure CL alternatives**:

**Option A: Use `ccl:with-lock-grabbed`** (recommended)
- Wrap cache operations in explicit locks
- Pros: Fine-grained control, portable
- Cons: Slightly more verbose

**Option B: Use `bordeaux-threads:with-lock`** (portable library)
- Wrap cache operations in portable lock mechanism
- Pros: Works across Lisps
- Cons: External dependency (already used by FOL)

**Option C: Accept single-threaded** (simplest)
- Remove synchronization for Clozure version
- Pros: Simplest port
- Cons: Not thread-safe (acceptable for initial port)

**Recommendation**: **Option B (bordeaux-threads)** — portable and already a dependency.

**Portable implementation**:
```lisp
(defstruct (dispatch-cache (:constructor make-dispatch-cache ()) (:copier nil))
  (table      (make-hash-table :test 'equal) :type hash-table)
  (lock       (bordeaux-threads:make-lock) :type bordeaux-threads:lock)
  (generation 0 :type (unsigned-byte 64))
  (hits       0 :type (unsigned-byte 64))
  (misses     0 :type (unsigned-byte 64)))
```

---

### 2. Atomic Increment Operations

**Current code** (dispatch.lisp:31, 32, 51):
```lisp
(sb-ext:atomic-incf (dispatch-cache-hits cache))
(sb-ext:atomic-incf (dispatch-cache-misses cache))
(sb-ext:atomic-incf (dispatch-cache-generation cache))
```

**Issue**: `sb-ext:atomic-incf` is SBCL-specific. Performs atomic increment without locks.

**Clozure CL alternatives**:

**Option A: Wrapped increment with bordeaux-threads lock**
```lisp
(bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
  (incf (dispatch-cache-hits cache)))
```

**Option B: Use CCL native atomic operations**
```lisp
;; CCL has atomic operations in CCL package
(ccl::atomic-incf (dispatch-cache-hits cache))
```

**Option C: Accept non-atomic for Clozure version**
- Still correct (increments happen, just not atomic)
- Statistics may be slightly off under high concurrency
- Acceptable for validation purposes

**Recommendation**: **Option A (bordeaux-threads)** — portable and safe.

**Portable implementation**:
```lisp
(defun cache-lookup (cache key)
  "Lookup KEY in cache. Thread-safe via lock."
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (let ((hit (gethash key (dispatch-cache-table cache))))
      (if hit
          (progn (incf (dispatch-cache-hits cache)) hit)
          (progn (incf (dispatch-cache-misses cache)) nil)))))
```

---

### 3. Type Declarations

**Current code** (dispatch.lisp:18–20, various `declare` statements):
```lisp
(generation 0 :type (unsigned-byte 64))
(hits       0 :type (unsigned-byte 64))
(misses     0 :type (unsigned-byte 64))
(declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
```

**Issue**: Not strictly SBCL-specific, but Clozure CL may handle differently.

**Clozure CL approach**: Same declarations work, but Clozure may ignore some SBCL-specific optimizations.

**Recommendation**: **Keep as-is** (portable). Clozure will use what it understands, ignore what it doesn't.

---

## Porting Strategy

### Phase 1: Code Abstraction (2–3 days)

Create portable abstraction layer for SBCL-specific features:

**File**: `src/dispatch-common.lisp` (new, portable core)
**File**: `src/dispatch-sbcl.lisp` (SBCL-specific implementation)
**File**: `src/dispatch-ccl.lisp` (Clozure CL-specific implementation)

**Structure**:
```lisp
;; dispatch-common.lisp
(in-package #:fol.compiler.dispatch)

;; Define generic interface
(defgeneric cache-atomic-incf (cache slot-name))
(defgeneric cache-acquire-lock (cache))
(defgeneric cache-release-lock (cache))

;; SBCL implementation (dispatch-sbcl.lisp)
(defmethod cache-atomic-incf :sbcl ((cache dispatch-cache) slot)
  (case slot
    (:hits (sb-ext:atomic-incf (dispatch-cache-hits cache)))
    (:misses (sb-ext:atomic-incf (dispatch-cache-misses cache)))
    (:generation (sb-ext:atomic-incf (dispatch-cache-generation cache)))))

;; Clozure CL implementation (dispatch-ccl.lisp)
(defmethod cache-atomic-incf :ccl ((cache dispatch-cache) slot)
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (case slot
      (:hits (incf (dispatch-cache-hits cache)))
      (:misses (incf (dispatch-cache-misses cache)))
      (:generation (incf (dispatch-cache-generation cache))))))
```

---

### Phase 2: Portable Version (3–5 days)

Create fully portable version using `bordeaux-threads`:

**File**: `src/dispatch-portable.lisp` (unified, works on both SBCL and Clozure)

**Key changes**:
1. Replace `:synchronized t` with explicit `bordeaux-threads:make-lock`
2. Replace `sb-ext:atomic-incf` with lock-wrapped `incf`
3. Keep rest of code identical

**Performance trade-off**:
- SBCL version: Lock-free atomics (fastest)
- Portable version: Lock-wrapped increments (slightly slower, but safe)

---

### Phase 3: Testing on Clozure CL (3–5 days)

1. **Setup Clozure CL environment**:
   - Install Clozure CL (if not present)
   - Load FOL system with portable dispatch module

2. **Run validation tests**:
   - Load FOL compiler/tests system
   - Run existing test suite on Clozure
   - Verify 2,888 checks pass

3. **Run performance benchmarks**:
   - Execute dispatch-cache-perf.lisp on Clozure
   - Measure hit rates, speedup, memory overhead
   - Compare to SBCL results

4. **Measure differences**:
   - Hit rate (should be identical)
   - Speedup (may be slightly lower due to lock overhead)
   - Memory usage (should be similar)

---

## Implementation Details

### Portable Cache Struct

**New version** (works on SBCL, Clozure CL, others):

```lisp
(defstruct (dispatch-cache (:constructor make-dispatch-cache ()) (:copier nil))
  "Hash-table cache for polymorphic inline caching.
   Works on SBCL (lock-free) and Clozure CL (lock-protected)."
  (table      (make-hash-table :test 'equal) :type hash-table)
  (lock       (bordeaux-threads:make-lock "dispatch-cache") :type bordeaux-threads:lock)
  (generation 0 :type (unsigned-byte 64))
  (hits       0 :type (unsigned-byte 64))
  (misses     0 :type (unsigned-byte 64)))
```

### Portable Cache Lookup

```lisp
(defun cache-lookup (cache key)
  "Lookup KEY in cache (thread-safe via lock)."
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (let ((hit (gethash key (dispatch-cache-table cache))))
      (if hit
          (progn (incf (dispatch-cache-hits cache)) hit)
          (progn (incf (dispatch-cache-misses cache)) nil)))))
```

### Portable Cache Flush

```lisp
(defun cache-flush! (cache)
  "Clear all cached entries and bump generation counter."
  (declare (type dispatch-cache cache))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (clrhash (dispatch-cache-table cache))
    (setf (dispatch-cache-hits cache) 0
          (dispatch-cache-misses cache) 0)
    (incf (dispatch-cache-generation cache))))
```

---

## Expected Performance Differences

### Comparison: SBCL vs. Clozure CL

| Metric | SBCL (lock-free) | Clozure (lock-wrapped) | Difference |
|--------|------------------|------------------------|------------|
| Cache lookup | O(1) atomic | O(1) + lock | -5% to -10% |
| Cache insert | O(1) | O(1) + lock | -5% to -10% |
| Cache flush | O(n) | O(n) + lock | -2% to -5% |
| **Overall speedup** | 2.2× | 2.0–2.1× | -5% to -10% |
| Memory overhead | 24.5 KB | 24.5 KB + lock | Negligible |

**Conclusion**: Clozure CL version will be slightly slower due to lock overhead, but still shows substantial speedup. Hit rates should be identical.

---

## Validation Plan

### Test 1: Correctness (Identical Behavior)

Run FOL test suite on both SBCL and Clozure:

```bash
# SBCL
sbcl --non-interactive --eval "(asdf:load-system :fol-compiler/tests)" \
  --eval "(fol.compiler.tests:run-compiler-tests)"
# Expected: 2888/2888 checks pass

# Clozure CL
ccl --non-interactive --eval "(asdf:load-system :fol-compiler/tests)" \
  --eval "(fol.compiler.tests:run-compiler-tests)"
# Expected: 2888/2888 checks pass (identical)
```

### Test 2: Hit Rate Comparison

Profile dispatch caching on both systems:

```bash
# Both SBCL and Clozure should show:
# - 84.3% overall hit rate
# - Same per-function hit rates
# - Same cache sizes
```

### Test 3: Performance Comparison

Run performance benchmark:

```bash
# SBCL: ~2.2× speedup
# Clozure CL: ~2.0–2.1× speedup (5–10% slower due to locks)
```

### Test 4: Concurrency Safety

Run concurrent stress test (if time permits):

```lisp
;; Spawn N threads, each calling cached function 10,000 times
;; Verify: final hit count = expected count (no lost increments)
;; Verify: no crashes or data corruption
```

---

## Deliverables

### Phase 1 Output: Portable Design Document
- File: `CLOZURE_CL_DISPATCH_DESIGN.md`
- Content: Abstraction layer design, performance trade-offs, implementation strategy

### Phase 2 Output: Portable Dispatch Module
- File: `src/dispatch-portable.lisp`
- Content: Fully portable cache implementation using `bordeaux-threads`
- Status: Works on SBCL, Clozure CL, and other Lisps

### Phase 3 Output: Validation Report
- File: `CLOZURE_CL_VALIDATION_REPORT.md`
- Content:
  - Test results (2,888/2,888 checks pass on Clozure)
  - Hit rate comparison (84.3% on both systems)
  - Performance comparison (2.0–2.1× on Clozure vs. 2.2× on SBCL)
  - Concurrency validation (if completed)

### Publication Output
- File: `PORTABILITY_EVIDENCE.md`
- Content: Summary of Clozure CL port, demonstrating generality
- Use case: Appendix for "Future Work" section of paper

---

## Integration with Publication

### Where Portability Evidence Fits

**In paper**:
- Mention in Related Work: "Implementation available for SBCL; portable version in progress for other Lisps"
- In Conclusion: "Algorithm is not SBCL-specific; demonstrated on Clozure CL as well"

**In appendices**:
- New Appendix F: Portability Evidence
  - Clozure CL validation results
  - Performance comparison across Lisps
  - Proof that algorithm generalizes beyond SBCL

**Publication impact**: +5–10% confidence (shows algorithm is general, not just an SBCL hack)

---

## Timeline Estimate

| Phase | Task | Duration | Status |
|-------|------|----------|--------|
| 1 | Create portable abstraction layer | 2–3 days | ⏳ Not started |
| 2 | Implement portable dispatch module | 3–5 days | ⏳ Not started |
| 3 | Test on Clozure CL | 2–3 days | ⏳ Not started |
| 4 | Performance benchmarking | 2–3 days | ⏳ Not started |
| 5 | Write validation report | 1–2 days | ⏳ Not started |
| **Total** | | **10–16 days** | ⏳ Ready to start |

**Critical path**: Phases 1 → 2 → 3 (can run in parallel: 2 can start before 1 finishes)

**Realistic timeline**: 2–3 weeks for complete implementation + validation

---

## Detailed Implementation Steps

### Step 1: Install Clozure CL

```bash
# On macOS/Linux
cd /opt
git clone https://github.com/Clozure/ccl.git
cd ccl
./make.sh
# Add to PATH: export PATH="/opt/ccl/scripts:$PATH"

# Verify
ccl --version  # Should show CCL version
```

### Step 2: Create dispatch-portable.lisp

Copy `src/dispatch.lisp` to `src/dispatch-portable.lisp` and modify:

1. **Replace synchronized hash table**:
   ```lisp
   ;; OLD (dispatch.lisp:17)
   (table (make-hash-table :test 'equal :synchronized t) :type hash-table)
   
   ;; NEW (dispatch-portable.lisp)
   (table (make-hash-table :test 'equal) :type hash-table)
   (lock (bordeaux-threads:make-lock "dispatch-cache") :type bordeaux-threads:lock)
   ```

2. **Replace atomic operations**:
   ```lisp
   ;; OLD (dispatch.lisp:31)
   (sb-ext:atomic-incf (dispatch-cache-hits cache))
   
   ;; NEW (dispatch-portable.lisp)
   (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
     (incf (dispatch-cache-hits cache)))
   ```

3. **Update cache-lookup, cache-insert!, cache-flush!** with lock-wrapped versions

### Step 3: Update ASDF System Definition

**File**: `src/fol-compiler.asd`

Add conditional loading:

```lisp
(:module "dispatch" :components
  ((:file "dispatch-portable")  ; Works on all Lisps
   #+ nil (:file "dispatch-sbcl")))  ; SBCL-optimized (optional)
```

### Step 4: Test on Clozure CL

```bash
# Start Clozure
ccl

# Load system
(asdf:load-system :fol-compiler/tests)

# Run tests
(fol.compiler.tests:run-compiler-tests)

# Expected: 2888/2888 checks pass
```

### Step 5: Profile on Clozure CL

```bash
# In Clozure REPL
(load "benchmarks/dispatch-cache-perf.lisp")
(run-perf-bench)

# Compare output to SBCL benchmark results
```

---

## Risk Mitigation

### Risk 1: Clozure CL Not Available

**Mitigation**: Use online Docker container for Clozure CL testing

```bash
docker run -it clozure/ccl:latest
```

### Risk 2: Performance Regression

**Mitigation**: Document performance difference as expected (lock overhead)

### Risk 3: Concurrency Issues

**Mitigation**: Start with single-threaded validation, add concurrency tests later

---

## Success Criteria

✅ **Portable dispatch module works on Clozure CL**
- File: `src/dispatch-portable.lisp` compiles without errors
- Test suite passes: 2,888/2,888 checks on Clozure
- Hit rates identical to SBCL: 84.3%

✅ **Performance acceptable**
- Clozure speedup: 2.0–2.1× (within 5–10% of SBCL's 2.2×)
- Memory overhead: Similar to SBCL

✅ **Documentation complete**
- Validation report: CLOZURE_CL_VALIDATION_REPORT.md
- Portability evidence: PORTABILITY_EVIDENCE.md

---

## Conclusion

Porting dispatch caching to Clozure CL is feasible and valuable:

1. **Shows generality**: Algorithm works on multiple Lisp implementations
2. **Strengthens publication**: +5–10% confidence (demonstrates not SBCL-specific)
3. **Reasonable effort**: 2–3 weeks for complete port + validation
4. **Minimal code changes**: Only 3 SBCL-specific features to port

**Recommendation**: Start with Phase 1 (portable abstraction) immediately. Can be integrated into PLDI submission as future work, or submitted separately as follow-up publication.

