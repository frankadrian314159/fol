# Generic Function Operators: Implementation Guide

**Approach**: Operator overloading via CLOS generic functions  
**Pattern**: Dispatch on argument types (number, vector, array)  
**Goal**: Seamless `(+ arr1 arr2)` syntax with proper type handling

---

## Architecture

### Generic Functions (Operators)

These become FOL's arithmetic, comparison, and logical operators:

```lisp
;; In src/array-functions.lisp

(defgeneric + (&rest args)
  (:documentation "Addition: numbers, vectors, arrays.
    Varargs: reduces left-to-right via repeated dispatch"))

(defgeneric - (&rest args)
  (:documentation "Subtraction: a - b - c = (- (- a b) c)"))

(defgeneric * (&rest args)
  (:documentation "Multiplication: numbers, vectors, arrays"))

(defgeneric / (&rest args)
  (:documentation "Division: numbers, vectors, arrays"))

;; Comparison operators
(defgeneric = (&rest args))
(defgeneric not= (a b &rest rest))
(defgeneric < (&rest args))
(defgeneric > (&rest args))
(defgeneric <= (&rest args))
(defgeneric >= (&rest args))

;; Logical operators
(defgeneric and (&rest args))
(defgeneric or (&rest args))
(defgeneric not (a))
(defgeneric xor (a b))
```

### Methods by Type Combination

For each generic, implement methods for:

1. **Scalar dispatch** (delegate to CL)
2. **Vector + Vector** (element-wise)
3. **Scalar + Vector** (broadcast left)
4. **Vector + Scalar** (broadcast right)
5. **Array dispatch** (same as vector, uses `<array>` class)

---

## Implementation Pattern: `+` Operator

### Step 1: Define Generic

```lisp
(defgeneric + (&rest args)
  (:documentation "Addition supporting scalars, vectors, arrays.
    (+ 1 2 3) → 6
    (+ arr1 arr2) → element-wise sum
    (+ 10 arr) → broadcast to array
    (+ arr1 arr2 arr3) → ((arr1+arr2)+arr3)"))
```

### Step 2: Scalar-Only Method (Base Case)

```lisp
(defmethod + ((a number) &rest rest)
  "Scalar case: delegate to CL:+ and recurse on result"
  (if (null rest)
      a
      (+ (cl:+ a (car rest)) (cdr rest))))
```

**Usage**:
```lisp
(+ 1 2 3)                    ;; → 6
(+ 1 2.5)                    ;; → 3.5
(+ 1 2 3 4.5 5)              ;; → 15.5
```

### Step 3: Vector + Vector Method

```lisp
(defmethod + ((a <vector>) (b <vector>) &rest rest)
  "Vector case: element-wise addition"
  (let ((result (element-wise-add a b)))
    (if (null rest)
        result
        (+ result (car rest) (cdr rest)))))

;; Helper function (lives in array-functions.lisp)
(defun element-wise-add (v1 v2)
  "Add two vectors element-by-element.
   Shapes must match or broadcast."
  (let* ((shape1 (array-dimension v1))
         (shape2 (array-dimension v2))
         (final-shape (broadcast-shapes shape1 shape2)))
    (make-instance '<vector>
      :dimension final-shape
      :storage (map-nd-indices
                 (lambda (i1 i2)
                   (cl:+ (aref-nd v1 i1) (aref-nd v2 i2)))
                 shape1 shape2 final-shape))))
```

**Usage**:
```lisp
(+ arr1 arr2)                ;; Element-wise sum (same shape)
(+ arr1 arr2 arr3)           ;; ((arr1+arr2)+arr3)
```

### Step 4: Scalar + Vector Method (Broadcasting)

```lisp
(defmethod + ((a number) (b <vector>) &rest rest)
  "Broadcast scalar to vector"
  (let ((result (broadcast-add a b)))
    (if (null rest)
        result
        (+ result (car rest) (cdr rest)))))

(defun broadcast-add (scalar vec)
  "Add scalar to every element of vector"
  (make-instance '<vector>
    :dimension (array-dimension vec)
    :storage (map-over-storage
              (lambda (elem) (cl:+ scalar elem))
              (storage vec))))
```

**Usage**:
```lisp
(+ 10 arr)                   ;; 10 + each element
(+ 10 arr1 arr2)             ;; (10+arr1)+arr2
```

### Step 5: Vector + Scalar Method (Commute)

```lisp
(defmethod + ((a <vector>) (b number) &rest rest)
  "Commute: vector + scalar = scalar + vector"
  (+ b a (car rest) (cdr rest)))
```

**Usage**:
```lisp
(+ arr 10)                   ;; Same as (+ 10 arr)
```

---

## Pattern for Comparison Operators

Comparison operators return **boolean vectors**, not reducing to a single value:

```lisp
(defgeneric = (&rest args)
  (:documentation "Equality test: returns boolean or boolean vector.
    (= 1 1 1) → true
    (= arr 5) → boolean vector (one bool per element)
    (= arr1 arr2) → boolean vector (element-wise comparison)"))

;; Scalar case
(defmethod = ((a t) &rest rest)
  (if (null rest)
      t
      (and (cl:= a (car rest)) (apply #'= (cdr rest)))))

;; Vector + Scalar
(defmethod = ((a <vector>) (b number) &rest rest)
  (let ((result (element-wise-eq a b)))
    (if (null rest)
        result
        (apply #'= result rest))))

(defun element-wise-eq (vec scalar)
  "Compare each element of vector to scalar"
  (make-instance '<boolean-vector>
    :storage (map-over-storage
              (lambda (elem) (cl:= elem scalar))
              (storage vec))))
```

**Usage**:
```lisp
(= 5 5)                      ;; → T
(= arr 5)                    ;; → boolean vector
(= arr1 arr2)                ;; → boolean vector (element-wise)
(< arr 5)                    ;; → boolean vector
```

---

## Pattern for Logical Operators

Logical operators work on boolean values and vectors:

```lisp
(defgeneric and (&rest args)
  (:documentation "Logical AND: scalars or boolean vectors"))

;; Scalar case (short-circuit like CL:and)
(defmethod and ((a t) &rest rest)
  (if (or (not a) (null rest))
      a
      (apply #'and rest)))

;; Boolean vector case (element-wise)
(defmethod and ((a <boolean-vector>) (b <boolean-vector>) &rest rest)
  (let ((result (element-wise-and a b)))
    (if (null rest)
        result
        (apply #'and result rest))))
```

---

## Handling Arrays

Arrays (`<array>` class) inherit from `<vector>`, so the same methods apply:

```lisp
;; These work automatically for arrays too
(+ arr1 arr2)                ;; Array element-wise addition
(= arr 5)                    ;; Array element-wise comparison
(and bool-arr1 bool-arr2)    ;; Array element-wise AND
```

If arrays need special handling (e.g., respecting shape metadata), add specific methods:

```lisp
(defmethod + ((a <array>) (b <array>) &rest rest)
  "Arrays: validate compatible shapes, then element-wise add"
  (unless (equal (array-dimension a) (array-dimension b))
    (error "Shape mismatch: ~A vs ~A" (array-dimension a) (array-dimension b)))
  (let ((result (element-wise-add a b)))
    (if (null rest)
        result
        (+ result (car rest) (cdr rest)))))
```

---

## Package Setup

In `src/package.lisp`:

```lisp
(defpackage :fol
  (:use :cl)
  
  ;; Shadow CL operators to replace them with FOL generics
  (:shadow 
    +                  ;; arithmetic
    - * /
    =                  ;; comparison
    < > <= >= not=
    and or not         ;; logical
    )
  
  ;; Export FOL versions
  (:export
    +                  ;; arithmetic (generic)
    - * /
    =                  ;; comparison (generic)
    < > <= >= not=
    and or not         ;; logical (generic)
    
    ;; Named operators (generic)
    mod abs sqrt pow min max
    xor gcd lcm
    
    ;; Collections
    <vector> <array> <f64-array> <f32-array>
    ;; ... etc
    ))
```

### Accessing CL Primitives

Users can still use CL's operators when needed:

```lisp
(cl:+ 1 2 3)                 ;; CL addition (not generic)
(+ 1 2 3)                    ;; FOL addition (generic)

;; In FOL code, bare + uses FOL version
(defun my-sum (arr)
  (fold #'+ arr))            ;; Calls FOL +, dispatch via fold
```

---

## Testing Strategy

### Test Categories

1. **Scalar dispatch** (delegates to CL)
   - `(+ 1 2 3)` → `6`
   - `(= 5 5)` → `T`
   - `(and T F)` → `F`

2. **Vector dispatch** (element-wise)
   - `(+ arr1 arr2)` → vector
   - `(= arr 5)` → boolean vector
   - `(< arr 10)` → boolean vector

3. **Broadcasting** (scalar + vector)
   - `(+ 10 arr)` → vector
   - `(* scalar arr)` → vector

4. **Varargs** (reduce left-to-right)
   - `(+ arr1 arr2 arr3)` → reduces correctly
   - `(= a b c)` → correct chaining

5. **Type errors** (graceful failure)
   - `(+ "hello" 5)` → error
   - Proper error messages

### Test File Structure

```lisp
(in-package :fol.compiler.tests)

(in-suite array-functions-tests)

;; Arithmetic operators
(test generic-plus-scalars
  "Test + with scalars")

(test generic-plus-vectors
  "Test + with vectors")

(test generic-plus-broadcast
  "Test + with scalar and vector")

(test generic-plus-varargs
  "Test + with multiple arguments")

;; Comparison operators
(test generic-equals-scalars)
(test generic-equals-vectors)
(test generic-equals-broadcast)

;; Logical operators
(test generic-and-scalars)
(test generic-and-vectors)

;; Error cases
(test generic-operator-type-error
  "Invalid type combinations raise errors")
```

---

## Performance Notes

### Dispatch Cost

Generic function dispatch adds small overhead (~5-10% on modern CLOS):
- Acceptable for vectorized operations (amortized over many elements)
- Negligible for large arrays

### Optimization Opportunities

1. **Inline declarations** for scalar-only path
2. **Compiler macros** to bypass dispatch for literals
3. **Specialized versions** for common types (number, simple-vector)

Example optimization:

```lisp
(define-compiler-macro + (&whole form &rest args)
  "If all args are known to be numbers, use CL:+"
  (if (every (lambda (arg) 
              (or (numberp arg) 
                  (has-type-p arg 'number)))
            args)
      `(cl:+ ,@args)
      form))
```

---

## Migration Path (If Needed)

To revert to word-based names:

1. Remove shadowing from package.lisp
2. Change all `(+ ...)` calls to `(add ...)`
3. Export named functions instead of operators
4. Keep generic dispatch architecture (still useful)

This is future-proof; generic dispatch doesn't require symbol-based operators.

---

## References

- CLOS Method Dispatch: https://www.common-lisp.net/documentation
- Generic Arithmetic: https://lispcookbook.github.io/cl-cookbook/math.html
- Clojure Operators: https://clojure.org/reference/data_structures

