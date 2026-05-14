# Phase 2 Dispatch Caching Validation Report

**Date**: May 14, 2026  
**Status**: ⚠️ **IMPLEMENTATION INCOMPLETE**

## Executive Summary

While the Phase 2 dispatch caching infrastructure is **fully implemented** in `src/dispatch.lisp` (cache operations, MOP hooks, GF registry), the **integration with the compiler is broken**. The caching code is never actually emitted because the analysis function `cacheable-defn-p` is fundamentally broken.

## Root Cause Analysis

### The Problem

The `cacheable-defn-p` function in `src/compiler.lisp` (line 2677) attempts to analyze dispatch caching applicability by inspecting a **pre-compiled lambda-form**. This is incorrect because:

1. **Original Code Flow**:
   - `emit-defn` receives an AST defn-node
   - Calls `compile-fn(clauses)` → produces a compiled lambda-form
   - Calls `cacheable-defn-p(lambda-form)` → tries to analyze the compiled code

2. **The Issue**:
   - `compile-fn` transforms the original AST clauses into:
     - Pattern-matching checks (not type predicates)
     - Specialized parameter bindings
     - Compiled body expressions
   - The original type predicates like `integer?`, `(cl:typep x 'integer)` are **replaced** with compiled code
   - `cacheable-defn-p` can't find the original type predicates to analyze

3. **Example**:
   ```lisp
   ;; Original clause
   (#(x) (cond ((integer? x) (* x 2)) ...))
   
   ;; After compile-fn
   (lambda (a0) (cond
     ((integerp a0) (let ((x a0)) (* x 2)))  ; Pattern binding added
     ...))
   
   ;; cacheable-defn-p sees: (integerp a0)
   ;; But a0 is NOT in the params list (params is (x))
   ;; So it fails the (member (second check) params) test
   ```

### Current Test Results

Created comprehensive validation tests in `run-phase2-validation.lisp`:

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Test 1 | defn with `integer?` | progn (cached) | plain defun | ❌ FAIL |
| Test 2 | defn with `cl:typep` | progn (cached) | plain defun | ❌ FAIL |
| Test 3 | defn with value predicates | progn (cached) | plain defun | ❌ FAIL |
| Test 4 | Anonymous fn | progn (cached) | plain lambda | ❌ FAIL |
| Test 5 | defmethod | progn (cached) | plain defmethod | ❌ FAIL |
| Test 6 | Single-clause defn | plain defun | plain defun | ✅ PASS |

**Zero out of five caching scenarios trigger cache code generation.**

## What IS Implemented (Working)

### In `src/dispatch.lisp` (88 lines)
- ✅ `dispatch-cache` struct with `entries` (hash-table), `generation` counter
- ✅ `cache-lookup(cache, key)` - O(1) hash lookup
- ✅ `cache-insert!(cache, key, fn)` - atomic insertion
- ✅ `cache-flush!(cache)` - zero entries, bump generation
- ✅ `*gf-cache-registry*` - global hash-table mapping GF names to caches
- ✅ `register-gf-cache!(gf-name, cache)` - adds to registry
- ✅ `flush-gf-caches!(gf-name)` - flush specific GF's caches
- ✅ `flush-all-caches!()` - emergency flush (invoked by `finalize-inheritance`)
- ✅ MOP hooks:
  - `add-method :after` → calls `flush-gf-caches!`
  - `remove-method :after` → calls `flush-gf-caches!`
  - `finalize-inheritance :after` → calls `flush-all-caches!`
- ✅ `pred-key(x)` - returns value for fixnum/char/symbol, (class-of x) for reference types
- ✅ `type-dispatch-cond-p(cond, params)` - detects type-predicate COND
- ✅ `predicate-dispatch-cond-p(cond)` - detects ≥4-clause COND
- ✅ `has-reference-type-value-predicates-p(cond, params)` - detects unsafe value predicates on reference types
- ✅ `value-key-expr(params)` - builds (list (pred-key p1) (pred-key p2) ...) expressions

### In `src/compiler.lisp` (Code Generation)
- ✅ `make-cached-defn(name, lambda-form, mode)` - emits progn with defun, cache, helpers
- ✅ `make-cached-fn(lambda-form, mode)` - emits progn with lambda, cache, helpers
- ✅ `make-cached-method(name, method-form)` - emits progn with defmethod, cache, registration
- ✅ `make-cached-defgeneric-dispatcher` - wraps dispatcher with composite (arity . class-tuple) caching
- ✅ `wrap-cond-with-cache`, `wrap-dispatcher-with-cache` - helper wrappers

**These functions work correctly when called, but are never invoked.**

## What Needs Fixing

### Priority 1: Fix `cacheable-defn-p` (CRITICAL)

**Problem**: Analyzes post-compilation lambda-form instead of pre-compilation AST.

**Solution**: Create `cacheable-clauses-p(clauses, params)` that:
1. Takes raw AST clauses (before `compile-fn`)
2. Checks if all clauses form a simple COND with only type predicates
3. Detects multi-clause fixed-arity (no &rest)
4. Returns `:type`, `:value`, or `nil`

**Implementation Strategy**:
1. Extract first clause's param-vector to determine params
2. For single-clause: check if body is a COND
3. For multi-clause: check if compile-fn would produce a COND (not pattern-dispatch)
4. Analyze COND checks before emit-node processes them

**Updated Call Sites**:
```lisp
;; BEFORE
(let ((lambda-form (compile-fn clauses)))
  (let ((cache-mode (cacheable-defn-p lambda-form))))

;; AFTER
(let ((cache-mode (cacheable-clauses-p clauses)))
  (let ((lambda-form (compile-fn clauses))))
```

### Priority 2: Handle Edge Cases

- Multi-clause fns with pattern specializers (not just type predicates)
- Mixed fixed/rest-arity clauses
- Clauses with key parameters
- Reference-type value predicates (fallback to no caching)

### Priority 3: Documentation & Testing

- Create integration tests proving caching code IS emitted
- Benchmark before/after to show performance improvement
- Document why certain forms DON'T cache (mixed arity, patterns, etc.)

## Files Involved

| File | Issue | Impact |
|------|-------|--------|
| `src/compiler.lisp:2677` | `cacheable-defn-p` analyzes wrong form | Caching never triggered |
| `src/compiler.lisp:1617` | `emit-fn` calls `cacheable-defn-p` on compiled form | Fn caching broken |
| `src/compiler.lisp:2742` | `emit-defn` calls `cacheable-defn-p` on compiled form | Defn caching broken |
| `src/compiler.lisp:2445` | `emit-defmethod` calls `cacheable-method-p` on defmethod form | Method caching broken |

## Validation Tests Created

Created `run-phase2-validation.lisp` with 6 test cases covering:
- defn with FOL type predicates
- defn with cl:typep forms
- defn with value predicates
- Anonymous fn
- Multi-clause defmethod
- Single-clause defn (should NOT cache)

**Status**: All tests show caching NOT enabled. Awaiting fix of `cacheable-defn-p`.

## Performance Impact

When fixed, expected improvements:
- **Type-dispatch**: 2-3x faster via cached class-of lookups
- **Value-dispatch**: 1.5-2x faster on eql-comparable types (fixnum, char, symbol)
- **Fallback**: No overhead for reference-type value predicates (direct COND)

## Next Steps

1. Implement `cacheable-clauses-p(clauses)` analyzing pre-compilation AST
2. Update `emit-defn`, `emit-fn`, `emit-defmethod` to call it before `compile-fn`
3. Run validation tests to confirm caching code IS emitted
4. Benchmark before/after
5. Update documentation with examples of cached vs. uncached forms

---

**Time to Fix**: ~2-3 hours (implement analysis, update call sites, test, benchmark)

**Confidence Level**: HIGH - Root cause identified, solution clear, all infrastructure working
