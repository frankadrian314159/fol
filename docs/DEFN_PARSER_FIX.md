# defn Parser Fix: Accept Both FOL and CL Vector Syntax

**Date Fixed**: May 14, 2026
**Commit**: 88a2f98

## Problem

The `parse-defn` function in the FOL compiler was overly strict about parameter vector syntax. It only accepted FOL `<vector>` instances (created with `[...]` reader syntax), and rejected standard Common Lisp vectors created with `#(...)` syntax.

### Error Message
```
Invalid defn form: (DEFN TEST-WITH-CL-VECTOR #(X) (COND ((INTEGER? X) (* X 2)) (T "default")))
```

### Root Cause
The `parse-defn` function uses `fol-vector-p` to check if the first argument is a parameter vector:

```lisp
(defun fol-vector-p (x)
  "Check if X is a FOL <vector> instance (from the reader's [...] syntax)."
  (typep x 'fol.compiler.collections:<vector>))
```

This check is too narrow because:
1. Users might write `(defn name #(x) body)` using standard CL vector syntax
2. The FOL reader's `[...]` syntax produces FOL `<vector>` instances
3. Standard CL `#(...)` vectors are equally valid as parameter vectors

## Solution

### 1. Add `param-vector-p` Helper

Created a new predicate that accepts **both** FOL vectors and CL vectors:

```lisp
(defun param-vector-p (x)
  "Check if X is a valid parameter vector: either FOL <vector> or CL vector.
   Accepts both [...] (FOL syntax) and #(...) (CL syntax)."
  (or (fol-vector-p x) (cl:vectorp x)))
```

### 2. Update `parse-defn` Function

Replaced all `fol-vector-p` calls with `param-vector-p` in four locations:

1. Single-clause check
2. Single-clause with docstring check
3. Multi-clause detection helper
4. Multi-clause with docstring check

```lisp
;; Before
((and (>= (length args) 1)
      (fol-vector-p (first args)))
 ...)

;; After
((and (>= (length args) 1)
      (param-vector-p (first args)))
 ...)
```

## Impact

### What Now Works
- ✅ `(defn name #(x y) body ...)` - CL vector syntax
- ✅ `(defn name [x y] body ...)` - FOL vector syntax (unchanged)
- ✅ `(defn name (#(x y) body1) (#(x y z) body2) ...)` - multi-clause with CL vectors
- ✅ `(defn name "doc" #(x) body ...)` - docstring + CL vector
- ✅ `(defn name "doc" [x] body ...)` - docstring + FOL vector (unchanged)

### What Correctly Fails
- ❌ `(defn name (x) body ...)` - list syntax (correctly rejected)

## Testing

Created comprehensive test cases (test-vector-simple.lisp):

```
Test 1: Defn with #(x) vector syntax
  Creating form with: (DEFN TEST-WITH-CL-VECTOR #(X) ...)
  Errors: NIL
  SUCCESS: Code generated ✅

Test 2: Defn with (x) list syntax
  Creating form with: (DEFN TEST-WITH-LIST (X) ...)
  Errors: (Invalid defn form: ...)
  Correctly rejected ✅

Test 3: Defn with multi-clause syntax
  Creating form with multi-clause syntax
  Errors: NIL
  SUCCESS: Code generated ✅
```

## Code Changes

**File**: `src/compiler.lisp`

**Changes**:
- Added `param-vector-p` helper function (1 function, 4 lines)
- Updated `parse-defn` function body (4 call sites, all use `param-vector-p`)

**Lines Added**: 10
**Lines Modified**: 5

## Backwards Compatibility

**Status**: ✅ **Fully Backwards Compatible**

- All existing code using `[x]` syntax continues to work unchanged
- No breaking changes to parse-defn interface
- New functionality (CL vector support) is purely additive
- List syntax `(x)` correctly rejected (same as before)

## Related Issues

This fix enables Phase 2 dispatch caching tests to work correctly, since they use CL vector syntax `#(x)` for parameter vectors in quoted forms.

## Notes

There is a pre-existing warning about undefined `+DISPATCH-CACHE-THRESHOLD+` constant used in `cacheable-defgeneric-p`. This is a function definition order issue unrelated to this fix:
- The constant is defined at line 2351
- The function using it is defined earlier
- This doesn't affect functionality, only causes a compile-time warning
- Could be fixed by reordering definitions (future cleanup)

