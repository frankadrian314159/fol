# Clozure CL Validation Checklist

**Date**: May 14, 2026  
**Purpose**: Step-by-step validation of dispatch caching portability to Clozure CL

---

## Pre-Validation Setup

### Step 1: Install Clozure CL

- [ ] Download Clozure CL from https://github.com/Clozure/ccl
- [ ] Compile/install Clozure CL
- [ ] Verify installation: `ccl --version`
- [ ] Expected output: "Clozure CL version X.X.X"

### Step 2: Verify Dependencies

- [ ] bordeaux-threads available in Clozure: `(ql:quickload :bordeaux-threads)`
- [ ] closer-mop available: `(ql:quickload :closer-mop)`
- [ ] fset available: `(ql:quickload :fset)`
- [ ] All load without errors

### Step 3: Prepare FOL Source

- [ ] Copy FOL source to test location
- [ ] Verify `src/dispatch-portable.lisp` exists
- [ ] Update `src/fol-compiler.asd` to load portable version
- [ ] Check: ASDF system loads on Clozure without errors

---

## Phase 1: Basic Compilation and Loading

### Test 1.1: Load Portable Dispatch Module

**Command**:
```bash
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler.dispatch)" \
  --eval "(format t \"DISPATCH LOADED SUCCESSFULLY~%\")"
```

**Expected output**:
```
DISPATCH LOADED SUCCESSFULLY
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[User notes here - any errors encountered]
```

---

### Test 1.2: Create a Cache Instance

**Command**:
```lisp
(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
  (format t "Cache created: ~A~%" cache)
  (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
    (format t "Initial stats: hits=~D misses=~D gen=~D size=~D~%" h m g s)))
```

**Expected output**:
```
Cache created: #S(DISPATCH-CACHE ...)
Initial stats: hits=0 misses=0 gen=0 size=0
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[User notes here]
```

---

### Test 1.3: Basic Cache Operations

**Command**:
```lisp
(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
  ;; Insert
  (fol.compiler.dispatch:cache-insert! cache '(integer) #'identity)
  ;; Lookup (hit)
  (let ((hit (fol.compiler.dispatch:cache-lookup cache '(integer))))
    (format t "Cache hit: ~A~%" (eq hit #'identity)))
  ;; Lookup (miss)
  (let ((miss (fol.compiler.dispatch:cache-lookup cache '(string))))
    (format t "Cache miss: ~A~%" (null miss)))
  ;; Stats
  (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
    (format t "Final stats: hits=~D misses=~D size=~D~%" h m g s)))
```

**Expected output**:
```
Cache hit: T
Cache miss: T
Final stats: hits=1 misses=1 size=1
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[User notes here]
```

---

## Phase 2: FOL Compiler Test Suite

### Test 2.1: Load Compiler Tests

**Command**:
```bash
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler/tests)" \
  --eval "(format t \"TESTS LOADED SUCCESSFULLY~%\")"
```

**Expected output**:
```
TESTS LOADED SUCCESSFULLY
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[User notes here]
```

---

### Test 2.2: Run Full Test Suite

**Command**:
```bash
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler/tests)" \
  --eval "(let ((result (fol.compiler.tests:run-compiler-tests))) \
           (format t \"TEST RESULT: ~A~%\" result))"
```

**Expected output**:
```
TEST RESULT: (:tests 23 :checks 2888 :failures 0)
```

**OR** (if test result format differs):
```
[All 2888 checks pass]
[No failures detected]
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Failure analysis** (if failed):
```
[List any test failures here]
[Note which modules failed: primitives? special-forms? collections?]
```

---

### Test 2.3: Verify No Regressions

**Command**:
```bash
# Run tests twice to ensure no state issues
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler/tests)" \
  --eval "(format t \"RUN 1: ~A~%\" (fol.compiler.tests:run-compiler-tests))" \
  --eval "(format t \"RUN 2: ~A~%\" (fol.compiler.tests:run-compiler-tests))"
```

**Expected output**:
```
RUN 1: (:tests 23 :checks 2888 :failures 0)
RUN 2: (:tests 23 :checks 2888 :failures 0)
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[Any differences between runs?]
```

---

## Phase 3: Dispatch Caching Validation

### Test 3.1: Load Dispatch Caching Tests

**Command**:
```bash
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler/tests)" \
  --eval "(when (fboundp 'fol.compiler.dispatch:inspect-fn-cache) \
           (format t \"DISPATCH PROFILING AVAILABLE~%\"))"
```

**Expected output**:
```
DISPATCH PROFILING AVAILABLE
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Test 3.2: Profile Dispatch Cache on Test Suite

**Command**:
```bash
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler/tests)" \
  --eval "(fol.compiler.tests:run-compiler-tests)" \
  --eval "(fol.compiler.dispatch:profile-dispatch-caching)"
```

**Expected output**:
```
=== FOL DISPATCH CACHING PROFILING ===
Profiling dispatch cache on FOL test suite
[Loading test suite...]
[Running tests with profiling enabled...]
[Analyzing results...]
Profiling complete. Results saved to: empirical-validation-results.txt
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Test 3.3: Verify Cache Statistics

**Command**:
```lisp
;; After running tests, inspect a cached function
(fol.compiler.dispatch:inspect-fn-cache 'some-cached-function)
```

**Expected output**:
```
(VALUES hits misses generation cache-size)
;; Example: (VALUES 100 10 1 5)
```

**Sample cached functions** (check if any of these have cache stats):
- [ ] `integer?` dispatch
- [ ] `vector?` dispatch
- [ ] Type checking functions
- [ ] Special form routing

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[List functions that were cached]
[Record their hit rates]
```

---

## Phase 4: Performance Benchmarking

### Test 4.1: Run Performance Benchmark

**Command**:
```bash
ccl --non-interactive --load benchmarks/dispatch-cache-perf.lisp
```

**Expected output**:
```
=== Dispatch Cache Performance ===
Warm-up: 1000 calls
Timed run (100k, single type, all hits): XX.X ms (Y.YY µs/call)
Hit rate: 99.X% (99001 hits / 999 misses)
---
Uncached baseline (flush before each call): XXX.X ms (Z.ZZ µs/call)
Speedup: X.Xx
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Performance metrics**:
- [ ] Timed run duration: _____ ms
- [ ] Per-call time: _____ µs
- [ ] Hit rate: _____%
- [ ] Speedup: _____ x

---

### Test 4.2: Compare SBCL vs. Clozure Performance

| Metric | SBCL | Clozure CL | Difference |
|--------|------|-----------|-----------|
| Timed run (ms) | [from SBCL run] | _____ | _____ |
| Per-call time (µs) | [from SBCL run] | _____ | _____ |
| Hit rate (%) | 99.7% | ____% | ____% |
| Speedup (x) | 2.2x | _____ x | _____ x |

**Expected**: Clozure CL speedup should be 2.0–2.1× (within 5–10% of SBCL's 2.2×)

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[Record actual performance numbers]
[Note any anomalies]
```

---

## Phase 5: Concurrency Validation (Optional)

### Test 5.1: Concurrent Cache Access

**Command** (if concurrency test available):
```bash
ccl --non-interactive --eval \
  "(asdf:load-system :fol-compiler/tests)" \
  --eval "(fol.compiler.dispatch:test-concurrent-cache-access)"
```

**Expected output**:
```
Spawning 4 threads, each with 1000 cache operations...
Thread 1 completed: 1000 operations
Thread 2 completed: 1000 operations
Thread 3 completed: 1000 operations
Thread 4 completed: 1000 operations
Final hit count: 3999 (expected ~3999)
Verification: PASSED
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[Any concurrency issues?]
[Any lost increments?]
```

---

## Summary Report

### Overall Results

| Test Phase | Tests | Passed | Failed | Status |
|------------|-------|--------|--------|--------|
| 1. Basic compilation | 3 | [ ] | [ ] | [ ] |
| 2. Test suite | 3 | [ ] | [ ] | [ ] |
| 3. Dispatch caching | 3 | [ ] | [ ] | [ ] |
| 4. Performance | 2 | [ ] | [ ] | [ ] |
| 5. Concurrency | 1 | [ ] | [ ] | [ ] |
| **Total** | **12** | **[ ]** | **[ ]** | **[ ]** |

### Performance Summary

**Hit Rate Validation**:
- SBCL observed: 84.3%
- Clozure CL observed: _____%
- Match: [ ] Yes [ ] No [ ] N/A

**Speedup Validation**:
- SBCL measured: 2.2×
- Clozure CL measured: _____ ×
- Within expected range (2.0–2.1×): [ ] Yes [ ] No

**Memory Overhead**:
- SBCL: 24.5 KB
- Clozure CL: _____ KB
- Acceptable (similar to SBCL): [ ] Yes [ ] No

### Conclusion

**Clozure CL Port Status**:
- [ ] **SUCCESSFUL**: All tests pass, performance acceptable
- [ ] **PARTIAL**: Some tests pass, performance degradation acceptable
- [ ] **FAILED**: Critical tests failed, significant issues identified

**Summary**:
```
[2–3 sentence summary of validation results]
[Mention any noteworthy findings or issues]
```

**Recommendation**:
- [ ] Ready for publication as Appendix F (Portability Evidence)
- [ ] Requires minor fixes before publishing
- [ ] Needs significant rework before publishing
- [ ] Abandon portability effort, focus on SBCL only

---

## Detailed Failure Log (if any failures)

### Failed Test Details

**Test name**: _____________________  
**Expected behavior**: _____________________  
**Actual behavior**: _____________________  
**Error message**: _____________________  
**Root cause analysis**: _____________________  
**Remediation**: _____________________  

---

## Appendix: System Information

**Clozure CL Version**:
```
[Output of: ccl --version]
```

**Lisp Implementation Details**:
```
(format nil "~A ~A on ~A ~A"
  (lisp-implementation-type)
  (lisp-implementation-version)
  (machine-type)
  (software-type))
```

**Expected output**: e.g., "Clozure CL 1.12.1 on x86-64 Darwin"

**Memory Available**:
```
[Amount of RAM available]
```

**Test Duration**:
- Total time: _____ minutes
- Compilation: _____ minutes
- Tests: _____ minutes
- Benchmarks: _____ minutes

---

## Sign-Off

**Validation Date**: _____________________  
**Validated By**: _____________________  
**Validation Status**: [ ] Complete [ ] In Progress [ ] Not Started

**Notes**:
```
[Any final notes or observations]
```

