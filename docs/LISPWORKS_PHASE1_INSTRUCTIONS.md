# LispWorks Phase 1 Validation Instructions

**Script**: `lispworks-phase1-simple.lisp`  
**Purpose**: Validate portable dispatch caching on LispWorks  
**Duration**: ~30 seconds  
**Requirements**: LispWorks 8.0+ with Quicklisp installed

---

## Running the Validation Script

### Option A: Command-Line Execution (Recommended)

**On Windows** (Personal or Evaluation Edition):
```bash
cd C:\Users\frank\Projects\FOL\fol
"C:\Program Files\LispWorks\lispworks.exe" -l lispworks-phase1-simple.lisp
```

**On Linux/macOS** (Personal or Evaluation Edition):
```bash
cd ~/Projects/FOL/fol
lispworks-8-1-0-x86-linux -l lispworks-phase1-simple.lisp
```

or

```bash
ccl64 -l lispworks-phase1-simple.lisp
```

### Option B: IDE Execution

1. Launch LispWorks IDE
2. Open file: `lispworks-phase1-simple.lisp`
3. Select **Tools > Compile File** or press **Ctrl+Shift+K**
4. In REPL, evaluate:
   ```lisp
   (load "lispworks-phase1-simple.lisp")
   ```

### Option C: Batch Processing (LispWorks Delivery)

For integration into CI/CD pipeline:
```bash
lispworks -build lispworks-phase1-simple.lisp -eval "(quit)"
```

---

## Expected Output

Successful validation will produce:

```
============================================================
=== LISPWORKS DISPATCH CACHING PHASE 1 VALIDATION ===%
LispWorks Version: 8.1.x
Portable dispatch caching module validation

Test 1.1: Portable hash-table with lock operations
✅ Hash-table operations work: T

Test 1.2: Dispatch cache structure
✅ Cache created: DISPATCH-CACHE
   Initial state: hits=0 misses=0 gen=0

Test 1.3: Cache lookup and insertion
✅ Cache hit: T
✅ Cache miss (returns NIL): T

Test 1.4: Thread-safe concurrent cache access
✅ Concurrent access completed safely

============================================================
✅ LISPWORKS PHASE 1 VALIDATION COMPLETE

All tests passed on LispWorks 8.1.x

Summary:
  - Hash-table with locks: ✅
  - Dispatch cache structure: ✅
  - Cache operations (hit/miss): ✅
  - Thread-safe concurrent access: ✅

Portable dispatch caching is compatible with LispWorks.
============================================================
```

---

## What Each Test Validates

| Test | Purpose | Expected Outcome |
|------|---------|------------------|
| 1.1 | Bordeaux-threads lock integration | Lock wraps hash-table access |
| 1.2 | Dispatch cache struct creation | DISPATCH-CACHE instance created |
| 1.3 | Cache hit/miss semantics | Correct lookup behavior |
| 1.4 | Thread-safe concurrent access | 4 threads, 100 ops each, no crashes |

---

## Troubleshooting

### Issue: "The package 'BORDEAUX-THREADS' can't be found"

**Cause**: Quicklisp not installed or not found  
**Solution**: 
```bash
# Ensure Quicklisp is installed
# Then manually load it in the REPL:
(load "~/quicklisp/setup.lisp")
(ql:quickload :bordeaux-threads)
(load "lispworks-phase1-simple.lisp")
```

### Issue: "Can't connect to Quicklisp"

**Cause**: Network issue or Quicklisp offline  
**Solution**: 
```lisp
;; In the script, modify:
(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file ql-path)
    (format t "Loading Quicklisp from ~A~%" ql-path)
    (load ql-path)))
```

### Issue: Thread operations fail

**Cause**: LispWorks built without MP (multi-processing) support  
**Solution**: 
- Use LispWorks Full Edition (includes MP support)
- Or use Personal Edition on Windows (includes MP)
- Evaluation Edition may have MP restrictions

### Issue: Startup takes >60 seconds

**Cause**: Normal for first-time Quicklisp library loading  
**Solution**: Wait for completion (libraries are cached after first load)

---

## Successful Validation Indicators

✅ **All tests pass** if you see:
- All 4 test lines print "✅"
- Final summary shows all 4 items with "✅"
- Script exits cleanly (no error messages)

❌ **Validation failed** if you see:
- Any "❌" indicators
- Unhandled exceptions
- Thread creation failures

---

## Next Steps After Phase 1

If Phase 1 passes:

**Phase 2**: Load full FOL compiler (requires ASDF and dependencies)
**Phase 3**: Run performance benchmarks
**Phase 4**: Validate concurrency at scale

See `LISPWORKS_VALIDATION_CHECKLIST.md` for Phases 2–6 tests.

---

## Script Details

**What the script does**:
1. Loads Quicklisp from home directory
2. Installs bordeaux-threads (portable threading library)
3. Creates a portable dispatch cache struct
4. Tests hash-table operations with locks
5. Tests concurrent access with 4 threads
6. Reports results
7. Exits cleanly

**Why this approach**:
- Uses only portable Common Lisp + bordeaux-threads
- No LispWorks-specific code in the cache implementation
- Validates the same algorithm on SBCL, CCL, ABCL, and LispWorks
- Proves dispatch caching is truly implementation-independent

**Performance notes**:
- Test 1.4 (concurrency): Creates 4 OS threads, 100 lookups each
- Total operations: 400+ hash-table accesses with locking
- Should complete in <5 seconds on modern hardware

---

## Recording Results

After running, save the output:

```bash
# On Windows (Command Prompt)
C:\lispworks.exe -l lispworks-phase1-simple.lisp > lispworks-phase1-results.txt 2>&1

# On Linux/macOS
lispworks-8-1-0-x86-linux -l lispworks-phase1-simple.lisp > lispworks-phase1-results.txt 2>&1
```

Then review `lispworks-phase1-results.txt` for final validation report.

---

## License Notes

**LispWorks License Options**:
- **Personal Edition** (Free): Suitable for non-commercial use and research
- **Evaluation License** (Free, 60 days): Commercial trial, full features
- **Commercial License**: Production deployment

The validation script is portable and will run on any LispWorks edition with MP support (which all editions have).

---

## Contact & Support

If validation fails:
1. Check Quicklisp is installed: `~/.quicklisp/setup.lisp` exists
2. Check bordeaux-threads loads: `(ql:quickload :bordeaux-threads)` in REPL
3. Check LispWorks version: `(lisp-implementation-version)` in REPL
4. Verify Quicklisp can access network (first `ql:quickload` may require internet)

For issues specific to LispWorks:
- LispWorks documentation: https://www.lispworks.com/documentation/
- Support: https://www.lispworks.com/support/

---

## Files

- **Test script**: `lispworks-phase1-simple.lisp`
- **This guide**: `LISPWORKS_PHASE1_INSTRUCTIONS.md`
- **Full checklist**: `LISPWORKS_VALIDATION_CHECKLIST.md` (Phases 2–6)
- **Results template**: `MULTI_PLATFORM_PHASE1_RESULTS.md` (for recording output)
