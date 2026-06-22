# Planning Updates: Operator Overloading & Clojure Naming

**Completed**: June 21, 2026 (Session 2)  
**Focus**: Generic function architecture for operator overloading

---

## What Changed

### 1. ✅ Operator Overloading Architecture Finalized

**Decision**: Use CLOS generic functions to implement symbol-based operators

**Benefits**:
- Clean syntax: `(+ arr1 arr2)` instead of `(add arr1 arr2)`
- Automatic type dispatch (scalar/vector/array)
- Broadcasting support: `(+ 10 arr)` broadcasts scalar
- Varargs support: `(+ a b c d)` reduces correctly
- CL primitives still accessible: `(cl:+ 1 2)`

**Implementation Pattern**:
```lisp
;; Generic operator
(defgeneric + (&rest args))

;; Scalar dispatch (delegate to CL)
(defmethod + ((a number) &rest rest)
  (if (null rest) a (+ (cl:+ a (car rest)) (cdr rest))))

;; Vector dispatch (element-wise)
(defmethod + ((a <vector>) (b <vector>) &rest rest)
  (let ((result (element-wise-add a b)))
    (if (null rest) result (+ result (car rest) (cdr rest)))))

;; Scalar + Vector dispatch (broadcasting)
(defmethod + ((a number) (b <vector>) &rest rest)
  (let ((result (broadcast-add a b)))
    (if (null rest) result (+ result (car rest) (cdr rest)))))
```

---

### 2. ✅ Operator & Function Naming Updated

**Operators** (Symbol-based, generic functions):
```
Arithmetic:   +  -  *  /
Comparison:   =  <  >  <=  >=  not=
Logical:      and  or  not
```

**Functions** (Named, kebab-case):
```
Core:         mod, abs, sqrt, pow, min, max, xor, gcd, lcm
Collections:  fold, scan, each, map-array, select, reject
Adverbs:      window, group-by, partition, zip, mapcat
```

**Map Q → Clojure**:
- Q's `+` → Clojure `+` (operator)
- Q's `%` → Clojure `/` (division)
- Q's `=` → Clojure `=` (operator)
- Q's `<>` → Clojure `not=` (function)
- Q's `&` → Clojure `and` (operator)
- Q's `|` → Clojure `or` (operator)
- Q's `~` → Clojure `not` (operator)
- Q's `mod` → Clojure `mod` (function)
- Q's `abs` → Clojure `abs` (function)

---

### 3. ✅ Documentation Updated

**Files Modified**:

1. **[q-functions-adverbs-reference.md](q-functions-adverbs-reference.md)**
   - Added "Operators" section distinguishing symbols from named functions
   - Updated all tables to show both Q and Clojure names
   - Added usage examples with operator syntax
   - Clarified implementation approach (generic functions)

2. **[IMPLEMENTATION_PLAN_PHASE123.md](IMPLEMENTATION_PLAN_PHASE123.md)**
   - Added "Part 2: Generic Function Architecture" section
   - Explained shadowing and package setup
   - Added generic function implementation pattern
   - Updated function naming tables to use operators
   - Added "Generic Function Definitions (1 day)" to Phase 1

3. **[PLANNING_SUMMARY.md](PLANNING_SUMMARY.md)**
   - Updated "Clojure-Style Naming" to "Operator Overloading via Generic Functions"
   - Added detailed key features list
   - Added "Generic Function Operators Guide" to deliverables

**Files Created**:

1. **[GENERIC_FUNCTION_OPERATORS.md](GENERIC_FUNCTION_OPERATORS.md)** (700+ LOC)
   - Complete implementation guide
   - Step-by-step patterns for each operator type
   - Package setup with shadowing
   - Testing strategy
   - Performance notes
   - Migration path

---

## Phase 1 Implementation Changes

### New First Step: Generic Function Definitions (1 day)

Before any other work in Phase 1:

```
Week 1:
  Day 1: Generic function definitions
    - Define generic functions: +, -, *, /, =, <, >, <=, >=, not=, and, or, not
    - Define named generics: mod, abs, sqrt, pow, min, max, xor
    - Set up package.lisp shadowing
    - Verify CL operators still accessible
    - Write dispatch tests
  
  Days 2-3: Index translation
  Days 4-5: Broadcasting
  Days 6-7: Element-wise arithmetic
  
Week 2:
  Days 1-2: Comparisons & logical
  Days 3-4: Fold/Scan (full reduction)
  Days 5-6: Each, Selection
  Day 7: Mapping
```

### Modified Implementation Order

All arithmetic/comparison/logical operations now defer to generic function methods:

1. **Scalar path**: `(+ 1 2 3)` → dispatches to `+` → calls `cl:+`
2. **Vector path**: `(+ arr1 arr2)` → dispatches to `+` → calls `element-wise-add`
3. **Mixed path**: `(+ 10 arr)` → dispatches to `+` → calls `broadcast-add`

This replaces the previous plan's separate `add`, `subtract`, `eq`, `lt` functions.

---

## Package Structure (Updated)

### `src/package.lisp`

```lisp
(defpackage :fol
  (:use :cl)
  
  ;; Shadow CL operators with FOL generic versions
  (:shadow 
    +                  ;; arithmetic
    - * /
    =                  ;; comparison
    < > <= >= not=
    and or not         ;; logical
    )
  
  ;; Export FOL versions (generic functions)
  (:export
    +                  ;; arithmetic
    - * /
    =                  ;; comparison
    < > <= >= not=
    and or not         ;; logical
    
    ;; Named operators
    mod abs sqrt pow min max
    xor gcd lcm
    
    ;; Collections
    <vector> <array> <f64-array> <f32-array>
    ;; ... rest of exports
    ))
```

### Usage Example

```lisp
;; In FOL code:
(+ 1 2 3)              ;; FOL generic + (calls CL:+)
(+ arr1 arr2)          ;; FOL generic + (element-wise)
(= arr 5)              ;; FOL generic = (boolean vector)

;; If needed, access CL directly:
(cl:+ 1 2)             ;; Raw CL addition
```

---

## Testing Strategy (Updated)

### New Test Suite: `src/tests/test-generic-operators.lisp`

```lisp
;; Arithmetic operators
(test generic-plus-scalars)
(test generic-plus-vectors)
(test generic-plus-broadcast)
(test generic-plus-varargs)
(test generic-minus-...)
(test generic-multiply-...)
(test generic-divide-...)

;; Comparison operators
(test generic-equals-scalars)
(test generic-equals-vectors)
(test generic-equals-broadcast)
(test generic-less-than-...)
(test generic-greater-than-...)
(test generic-not-equals-...)

;; Logical operators
(test generic-and-scalars)
(test generic-and-vectors)
(test generic-or-...)
(test generic-not-...)

;; Error handling
(test generic-operator-type-mismatch)
(test generic-operator-shape-mismatch)
```

---

## Backward Compatibility

### CL Operators Still Accessible

```lisp
;; Users can always access CL versions
(cl:+ 1 2 3)           ;; CL addition
(cl:= 5 5)             ;; CL equality
(cl:and T F)           ;; CL logical AND

;; Useful in cases where FOL dispatch not needed
(defun internal-sum (numbers)
  (reduce #'cl:+ numbers))  ;; Explicitly use CL version
```

### Migration If Needed

If symbol-based operators prove problematic:
1. Stop shadowing in package.lisp
2. Rename all operator calls to named versions
3. Keep generic function infrastructure (still useful)

---

## Performance Impact

### Dispatch Overhead
- Generic function dispatch: ~5-10% overhead per call
- Acceptable for vectorized operations (amortized over elements)
- Can optimize with compiler macros for literals

### Compiler Macro Optimization (Future)
```lisp
(define-compiler-macro + (&whole form &rest args)
  "If all args are numbers, use CL:+ directly"
  (if (all-numbers-p args)
      `(cl:+ ,@args)
      form))
```

---

## What's Ready Now

✅ **All planning complete**
- Architecture: generic functions with operator dispatch
- Naming: symbol-based operators + kebab-case functions
- Documentation: complete guides and patterns
- Testing: strategy defined, test file structure ready

✅ **Ready to implement Phase 1**
- Day 1: Generic function definitions
- Days 2-7: Element-wise operations + adverbs
- Tests: full coverage for all dispatch paths

---

## Files to Reference During Implementation

1. **[GENERIC_FUNCTION_OPERATORS.md](GENERIC_FUNCTION_OPERATORS.md)** — Implementation patterns
2. **[q-functions-adverbs-reference.md](q-functions-adverbs-reference.md)** — Function names & signatures
3. **[IMPLEMENTATION_PLAN_PHASE123.md](IMPLEMENTATION_PLAN_PHASE123.md)** — Overall architecture
4. **[PLANNING_SUMMARY.md](PLANNING_SUMMARY.md)** — Quick reference

---

## Summary

**Key Decision**: Use symbol-based operators (`+`, `-`, `=`, `<`, `and`, `or`, `not`) implemented as CLOS generic functions that dispatch on types.

**Benefits**:
- ✅ Clean, mathematical syntax
- ✅ Automatic broadcasting
- ✅ Seamless scalar/vector/array handling
- ✅ Clojure-familiar design
- ✅ CL primitives still accessible
- ✅ Extensible to new types

**Cost**:
- Small dispatch overhead (~5-10%)
- Package shadowing requires explicit naming when needed
- Learning curve for new users (minor)

**Timeline**:
- Phase 1 (2 weeks): Generics + element-wise + reduction
- Phase 2 (2 weeks): Single-axis operations
- Phase 3 (2 weeks): Advanced + optimization

Ready to build! 🚀

