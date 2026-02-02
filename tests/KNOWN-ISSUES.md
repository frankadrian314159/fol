# Known Issues in FOL Integration Tests

This document tracks features that have tests written but are currently disabled due to implementation issues.

## Eduction

**Status**: Tests disabled
**Location**: `tests/test-transducers.lisp` lines 196-203

**Issue**: The `eduction` function returns an empty sequence instead of applying the transducer.

**Tests affected**:
- `eduction-basic`
- `eduction-composed`

**Expected behavior**:
```clojure
(first (eduction (map inc) [1 2 3]))  ; should return 2
(into [] (eduction (map inc) [1 2 3]))  ; should return [2 3 4]
```

**Actual behavior**: Returns `nil` and empty vector respectively.

**Root cause**: The `eduction` implementation in `bootstrap/standard-names.lisp` (lines 2741-2772) appears to have issues with the lazy sequence generation logic.

---

## Delay/Deref

**Status**: Tests disabled
**Location**: `tests/test-transducers.lisp` lines 244-250

**Issue**: The `delay` macro and `deref` function don't return the expected values.

**Tests affected**:
- `delay-creates-deferred`
- `delay-caches-result`

**Expected behavior**:
```clojure
(deref (delay 42))  ; should return 42
(bind [d (delay (+ 20 22))] (deref d))  ; should return 42
```

**Actual behavior**: Returns incorrect values.

**Root cause**: The `make-delay-macro` in `bootstrap/standard-names.lisp` (lines 331-343) creates delays, but the deref mechanism may not be properly unwrapping them.

---

## For Macro with :when

**Status**: Tests disabled
**Location**: `tests/test-transducers.lisp` lines 319-321

**Issue**: The `for` macro doesn't support `:when` filtering clauses.

**Tests affected**:
- `for-with-filter`

**Expected behavior**:
```clojure
(into [] (for [x (range 10) :when (even? x)] x))
; should return [0 2 4 6 8]
```

**Actual behavior**: Returns `[0 1 2 3 4 5 6 7 8 9]` (all elements, filter ignored).

**Root cause**: The `make-for-macro` in `bootstrap/standard-names.lisp` doesn't implement `:when` clause handling.

---

## For Macro with Nested Bindings

**Status**: Tests disabled
**Location**: `tests/test-transducers.lisp` lines 323-325

**Issue**: The `for` macro doesn't properly handle nested binding vectors.

**Tests affected**:
- `for-nested`

**Expected behavior**:
```clojure
(into [] (for [x [1 2 3] y [:a :b :c]] [x y]))
; should return [[1 :a] [1 :b] [1 :c] [2 :a] [2 :b] [2 :c] [3 :a] [3 :b] [3 :c]]
; size should be 9
```

**Actual behavior**: Returns only 3 elements instead of 9.

**Root cause**: The `make-for-macro` doesn't implement proper nested iteration - it only processes the first binding.

---

## Every with Lazy Sequences

**Status**: Tests disabled
**Location**: `tests/test-transducers.lisp` lines 383-386

**Issue**: The `every` predicate returns incorrect results when applied to lazy sequences.

**Tests affected**:
- `every-with-lazy`

**Expected behavior**:
```clojure
(every pos? (range 1 10))  ; should return true
(every even? (range 1 10))  ; should return false
```

**Actual behavior**: Returns incorrect boolean values.

**Root cause**: The `every` function may not be properly realizing the lazy sequence or may have issues with short-circuit evaluation.

---

## Not-any with Lazy Sequences

**Status**: Tests disabled
**Location**: `tests/test-transducers.lisp` lines 388-391

**Issue**: The `not-any` predicate returns incorrect results when applied to lazy sequences.

**Tests affected**:
- `not-any-with-lazy`

**Expected behavior**:
```clojure
(not-any neg? (range 10))  ; should return true
(not-any even? (range 10))  ; should return false
```

**Actual behavior**: Returns incorrect boolean values.

**Root cause**: Similar to `every`, may have issues with lazy sequence realization or logic.

---

## Resolution Strategy

To fix these issues:

1. **Eduction**: Debug the `eduction-seq` helper function in `standard-names.lisp`
2. **Delay**: Investigate the `make-delay` and deref interaction
3. **For :when**: Extend the `for` macro to parse and handle `:when` clauses
4. **For nested**: Implement proper cartesian product logic for multiple bindings
5. **Every/not-any**: Fix lazy sequence handling to ensure proper realization and evaluation

All these features are implemented in the bootstrap but have bugs that need to be addressed. The tests are written and ready to be enabled once the underlying implementations are fixed.
