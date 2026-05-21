# LispWorks Validation Checklist

**Date**: May 14, 2026  
**Purpose**: Step-by-step validation of dispatch caching on LispWorks (commercial Lisp)
**Expected performance**: 2.0–2.2× speedup (similar to or better than Clozure CL)

---

## Pre-Validation Setup

### Step 1: Obtain LispWorks

**Option A: Personal Edition (Free, for education/personal use)**
```
1. Visit: https://www.lispworks.com/download/
2. Select: Personal Edition
3. Choose: Linux, macOS, or Windows (as appropriate)
4. Download: LispWorks 8.1.x (latest available)
5. Install: Follow platform-specific instructions
```

**Option B: Evaluation License (Free, 60 days, commercial use)**
```
1. Contact: sales@lispworks.com
2. Request: Evaluation license
3. Receive: License key via email
4. Install: LispWorks with evaluation license
```

**Option C: Full License (Commercial)**
```
Contact LispWorks Ltd for licensing options.
May have institutional or volume discounts.
```

**Verification**:
```bash
# On Linux/macOS
lispworks-8-1-0-x86-linux --version
# Expected: LispWorks Version 8.1.x

# On Windows
"C:\Program Files\LispWorks\lispworks.exe" --version
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[LispWorks version and edition]
[License type if applicable]
```

---

### Step 2: Verify LispWorks Environment

**Command**:
```bash
lispworks --eval "(format t \"LispWorks: ~A~%\" (lisp-implementation-version))" \
         --eval "(format t \"Compiled: ~A~%\" (get-universal-time))" \
         --eval "(multiple-value-bind (a b c) (room) (format t \"Memory available~%\"))"
```

**Expected output**:
```
LispWorks: 8.1.x
Compiled: [timestamp]
Memory available
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Step 3: Verify Dependencies

**Check bordeaux-threads**:
```bash
lispworks --eval "(ql:quickload :bordeaux-threads)" \
         --eval "(format t \"bordeaux-threads loaded: ~A~%\" (find-package :bordeaux-threads))"
```

**Expected output**:
```
bordeaux-threads loaded: #<PACKAGE "BORDEAUX-THREADS">
```

**Check closer-mop**:
```bash
lispworks --eval "(ql:quickload :closer-mop)" \
         --eval "(format t \"closer-mop loaded: ~A~%\" (find-package :closer-mop))"
```

**Check fset**:
```bash
lispworks --eval "(ql:quickload :fset)" \
         --eval "(format t \"fset loaded: ~A~%\" (find-package :fset))"
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Phase 1: Basic Compilation and Loading

### Test 1.1: Load Portable Dispatch Module

**Command**:
```bash
lispworks --eval "(asdf:load-system :fol-compiler.dispatch)" \
         --eval "(format t \"DISPATCH LOADED SUCCESSFULLY~%\")"
```

**Expected output**:
```
DISPATCH LOADED SUCCESSFULLY
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Notes**:
```
[Any LispWorks-specific behavior?]
```

---

### Test 1.2: Create Cache Instance

**Command**:
```bash
lispworks --eval "(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
                  (format t \"Cache created: ~A~%\" (type-of cache))
                  (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
                    (format t \"Initial stats: hits=~D misses=~D gen=~D size=~D~%\" h m g s)))"
```

**Expected output**:
```
Cache created: DISPATCH-CACHE
Initial stats: hits=0 misses=0 gen=0 size=0
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Test 1.3: Basic Cache Operations

**Command**:
```bash
lispworks --eval "(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
                  (fol.compiler.dispatch:cache-insert! cache '(integer) #'identity)
                  (let ((hit (fol.compiler.dispatch:cache-lookup cache '(integer))))
                    (format t \"Cache hit: ~A~%\" (eq hit #'identity)))
                  (let ((miss (fol.compiler.dispatch:cache-lookup cache '(string))))
                    (format t \"Cache miss: ~A~%\" (null miss)))
                  (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
                    (format t \"Final stats: hits=~D misses=~D size=~D~%\" h m g s)))"
```

**Expected output**:
```
Cache hit: T
Cache miss: T
Final stats: hits=1 misses=1 size=1
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Phase 2: FOL Compiler Test Suite

### Test 2.1: Load Compiler Tests

**Command**:
```bash
lispworks --eval "(asdf:load-system :fol-compiler/tests)" \
         --eval "(format t \"TESTS LOADED SUCCESSFULLY~%\")"
```

**Expected output**:
```
TESTS LOADED SUCCESSFULLY
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Test 2.2: Run Full Test Suite

**Command**:
```bash
lispworks --eval "(asdf:load-system :fol-compiler/tests)" \
         --eval "(let ((result (fol.compiler.tests:run-compiler-tests)))
                 (format t \"TEST RESULT: ~A~%\" result))"
```

**Expected output**:
```
TEST RESULT: (:tests 23 :checks 2888 :failures 0)
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Test duration**: _____ seconds

**Failure analysis** (if failed):
```
[List any test failures]
[Which modules?]
[LispWorks-specific issues?]
```

---

### Test 2.3: Verify No Regressions

**Command**:
```bash
lispworks --eval "(asdf:load-system :fol-compiler/tests)" \
         --eval "(format t \"RUN 1: ~A~%\" (fol.compiler.tests:run-compiler-tests))" \
         --eval "(format t \"RUN 2: ~A~%\" (fol.compiler.tests:run-compiler-tests))"
```

**Expected output**:
```
RUN 1: (:tests 23 :checks 2888 :failures 0)
RUN 2: (:tests 23 :checks 2888 :failures 0)
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Phase 3: Dispatch Caching Validation

### Test 3.1: Profile on Test Suite

**Command**:
```bash
lispworks --eval "(asdf:load-system :fol-compiler/tests)" \
         --eval "(fol.compiler.tests:run-compiler-tests)" \
         --eval "(fol.compiler.dispatch:profile-dispatch-caching)"
```

**Expected output**:
```
=== FOL DISPATCH CACHING PROFILING ===
[Profiling enabled...]
Profiling complete.
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Test 3.2: Verify Cache Statistics

**Command**:
```bash
lispworks --eval "(asdf:load-system :fol-compiler/tests)" \
         --eval "(fol.compiler.tests:run-compiler-tests)" \
         --eval "(multiple-value-bind (h m g s) (fol.compiler.dispatch:inspect-fn-cache 'some-fn)
                 (when h (format t \"Cache stats: hits=~D misses=~D gen=~D size=~D~%\" h m g s)))"
```

**Expected output**:
```
Cache stats: hits=XXX misses=YYY gen=Z size=W
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Phase 4: Performance Benchmarking

### Test 4.1: Run Performance Benchmark

**Command**:
```bash
lispworks --eval "(load \"benchmarks/dispatch-cache-perf.lisp\")"
```

**Expected output**:
```
=== Dispatch Cache Performance ===
Warm-up: 1000 calls
Timed run (100k, single type, all hits): XXX.X ms (YY.YY µs/call)
Hit rate: 99.X% (99001 hits / 999 misses)
---
Uncached baseline: XXXX.X ms (ZZ.ZZ µs/call)
Speedup: X.Xx
```

**Pass/Fail**: [ ] Pass [ ] Fail

**Performance metrics**:
- [ ] Timed run duration: _____ ms
- [ ] Per-call time: _____ µs
- [ ] Hit rate: _____%
- [ ] Speedup: _____ x

**Expected speedup range**: 2.0–2.2× (within 5% of SBCL's 2.2×)

**Pass/Fail**: [ ] Pass (within range) [ ] Fail (outside range)

---

### Test 4.2: Multiple Benchmark Runs

**Command**:
```bash
lispworks --eval "(loop for i from 1 to 3 do
                 (format t \"~%=== Run ~D ===~%\" i)
                 (load \"benchmarks/dispatch-cache-perf.lisp\"))"
```

**Speedup by run**:
- Run 1: _____ x
- Run 2: _____ x
- Run 3: _____ x

**Expected**: Consistent across runs (LispWorks compiles ahead-of-time)

**Pass/Fail**: [ ] Pass [ ] Fail

---

### Test 4.3: LispWorks vs SBCL Comparison

| Metric | SBCL | LispWorks | Ratio | Status |
|--------|------|-----------|-------|--------|
| Timed run (ms) | 45 | ? | ? | ? |
| Per-call (µs) | 0.45 | ? | ? | ? |
| Hit rate (%) | 84.3 | ? | ? | ? |
| Speedup (x) | 2.2 | ? | ? | ? |
| Memory (KB) | 24.5 | ? | ? | ? |

**Expected**: LispWorks within 95–105% of SBCL performance

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Phase 5: LispWorks-Specific Features

### Test 5.1: GUI and Debugger Integration (Optional)

**LispWorks bonus**: Full IDE with integrated debugger

**Test**:
```bash
lispworks  # Start full IDE
# CL-USER > (asdf:load-system :fol-compiler/tests)
# CL-USER > (fol.compiler.tests:run-compiler-tests)
```

**Verification**:
- [ ] Can set breakpoints in dispatch code
- [ ] Debugger works correctly
- [ ] Performance profiler shows cache operations
- [ ] IDE displays cache statistics

**Notes**:
```
[IDE observations]
[Debugging experience]
```

---

### Test 5.2: Multithreading (LispWorks MP)

**Command**:
```bash
lispworks --eval "(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
                 (lw:process-run-function 
                  \"thread-1\"
                  (lambda () (dotimes (i 1000) 
                            (fol.compiler.dispatch:cache-lookup cache '(integer)))))
                 (lw:process-run-function 
                  \"thread-2\"
                  (lambda () (dotimes (i 1000) 
                            (fol.compiler.dispatch:cache-lookup cache '(string)))))
                 (sleep 5)
                 (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
                  (format t \"Final: hits=~D misses=~D~%\" h m g s)))"
```

**Expected**: No crashes, correct statistics

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Phase 6: Compilation and Delivery

### Test 6.1: Compile to Executable (Optional)

**LispWorks delivery feature**: Compile Lisp code to executable

**Command**:
```lisp
(lw:deliver 
 (lambda ()
   (asdf:load-system :fol-compiler/tests)
   (fol.compiler.tests:run-compiler-tests))
 "fol-dispatch-cache-test"
 :console t
 :keep-pretty-printer t)
```

**Result**: Executable file `fol-dispatch-cache-test`

**Test**: Run executable
```bash
./fol-dispatch-cache-test
# Expected: All 2888 checks pass
```

**Pass/Fail**: [ ] Pass [ ] Fail

---

## Summary Report

### Overall Results

| Phase | Tests | Passed | Failed | Status |
|-------|-------|--------|--------|--------|
| 1. Setup | 3 | [ ] | [ ] | [ ] |
| 2. Compilation | 3 | [ ] | [ ] | [ ] |
| 3. Dispatch caching | 2 | [ ] | [ ] | [ ] |
| 4. Performance | 3 | [ ] | [ ] | [ ] |
| 5. LispWorks features | 2 | [ ] | [ ] | [ ] |
| 6. Delivery | 1 | [ ] | [ ] | [ ] |
| **Total** | **14** | **[ ]** | **[ ]** | **[ ]** |

### Performance Summary

**Hit Rate**:
- Expected: 84.3%
- Observed: _____%
- Match: [ ] Yes [ ] No

**Speedup**:
- SBCL: 2.2×
- LispWorks: _____ ×
- Range acceptable (2.0–2.2×): [ ] Yes [ ] No

### Conclusion

**LispWorks Port Status**:
- [ ] **SUCCESSFUL**: Excellent performance and compatibility
- [ ] **GOOD**: Works correctly, performance acceptable
- [ ] **PARTIAL**: Works but with some limitations
- [ ] **FAILED**: Critical issues identified

**Recommendation**:
- [ ] Include in multi-platform publication
- [ ] Highlight LispWorks IDE advantages
- [ ] Document performance characteristics
- [ ] Plan delivery/compilation approach if commercial use intended

---

## LispWorks-Specific Notes

### Compiler Characteristics
```
[LispWorks compiler performance vs SBCL?]
[AOT compilation effects?]
[Optimization levels?]
```

### IDE Experience
```
[Debugger usability for dispatch caching?]
[Performance profiler features?]
[Integrated development advantages?]
```

### Commercial Considerations
```
[License requirements for deployment?]
[Delivery options (executable, DLL, etc)?]
[Performance under different license types?]
```

---

**Validation Date**: _____________________  
**Validated By**: _____________________  
**LispWorks Version**: _____________________  
**License Type**: [ ] Personal [ ] Evaluation [ ] Commercial [ ] Other

**Status**: [ ] Complete [ ] In Progress [ ] Not Started

