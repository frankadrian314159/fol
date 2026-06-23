;;; FOL Compiler Tests - Typed Arrays
;;;
;;; Tests for f64-array, f32-array, and fixnum-array constructors and operations.

(in-package :fol.compiler.tests)

;;; ============================================================================
;;; Test Suite: Typed Arrays
;;; ============================================================================

(def-suite typed-arrays-suite
  :description "Tests for typed array constructors and operations"
  :in compiler-tests)

(in-suite typed-arrays-suite)

;;; ============================================================================
;;; F64-Array (64-bit Float) Tests
;;; ============================================================================

(test f64-array-constructor-simple
  "Test f64-array constructor with simple arguments"
  (let ((arr (fol.compiler.collection-functions:f64-array 1.0d0 2.0d0 3.0d0)))
    (is (fol.compiler.collections:<f64-array>? arr))
    (is (= 3 (fol.compiler.collections:collection-size arr)))
    (is (equal '(3) (fol.compiler.collections:array-dimension arr)))))

(test f64-array-constructor-with-dimensions
  "Test f64-array constructor with explicit dimensions"
  (let ((arr (fol.compiler.collection-functions:f64-array
              :dimensions '(2 3)
              1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0)))
    (is (fol.compiler.collections:<f64-array>? arr))
    (is (= 6 (fol.compiler.collections:collection-size arr)))
    (is (equal '(2 3) (fol.compiler.collections:array-dimension arr)))))

(test f64-array-constructor-initial-element
  "Test f64-array constructor with initial-element"
  (let ((arr (fol.compiler.collection-functions:f64-array
              :dimensions '(4)
              :initial-element 0.0d0)))
    (is (fol.compiler.collections:<f64-array>? arr))
    (is (= 4 (fol.compiler.collections:collection-size arr)))))

(test f64-array-type-predicate
  "Test f64-array type predicate"
  (let ((arr (fol.compiler.collection-functions:f64-array 1.0d0)))
    (is (fol.compiler.collections:<f64-array>? arr))
    (is (fol.compiler.collections:<array-ops>? arr))
    (is (not (fol.compiler.collections:<f32-array>? arr)))
    (is (not (fol.compiler.collections:<fix64-array>? arr)))))

;;; ============================================================================
;;; F32-Array (32-bit Float) Tests
;;; ============================================================================

(test f32-array-constructor-simple
  "Test f32-array constructor with simple arguments"
  (let ((arr (fol.compiler.collection-functions:f32-array 1.0 2.0 3.0)))
    (is (fol.compiler.collections:<f32-array>? arr))
    (is (= 3 (fol.compiler.collections:collection-size arr)))
    (is (equal '(3) (fol.compiler.collections:array-dimension arr)))))

(test f32-array-constructor-with-dimensions
  "Test f32-array constructor with explicit dimensions"
  (let ((arr (fol.compiler.collection-functions:f32-array
              :dimensions '(2 2)
              1.0 2.0 3.0 4.0)))
    (is (fol.compiler.collections:<f32-array>? arr))
    (is (= 4 (fol.compiler.collections:collection-size arr)))
    (is (equal '(2 2) (fol.compiler.collections:array-dimension arr)))))

(test f32-array-constructor-initial-element
  "Test f32-array constructor with initial-element"
  (let ((arr (fol.compiler.collection-functions:f32-array
              :dimensions '(3)
              :initial-element 5.0)))
    (is (fol.compiler.collections:<f32-array>? arr))
    (is (= 3 (fol.compiler.collections:collection-size arr)))))

(test f32-array-type-predicate
  "Test f32-array type predicate"
  (let ((arr (fol.compiler.collection-functions:f32-array 1.0)))
    (is (fol.compiler.collections:<f32-array>? arr))
    (is (fol.compiler.collections:<array-ops>? arr))
    (is (not (fol.compiler.collections:<f64-array>? arr)))
    (is (not (fol.compiler.collections:<fix64-array>? arr)))))

;;; ============================================================================
;;; Fixnum-Array (64-bit Fixnum) Tests
;;; ============================================================================

(test fixnum-array-constructor-simple
  "Test fixnum-array constructor with simple arguments"
  (let ((arr (fol.compiler.collection-functions:fixnum-array 10 20 30)))
    (is (fol.compiler.collections:<fix64-array>? arr))
    (is (= 3 (fol.compiler.collections:collection-size arr)))
    (is (equal '(3) (fol.compiler.collections:array-dimension arr)))))

(test fixnum-array-constructor-with-dimensions
  "Test fixnum-array constructor with explicit dimensions"
  (let ((arr (fol.compiler.collection-functions:fixnum-array
              :dimensions '(2 3)
              1 2 3 4 5 6)))
    (is (fol.compiler.collections:<fix64-array>? arr))
    (is (= 6 (fol.compiler.collections:collection-size arr)))
    (is (equal '(2 3) (fol.compiler.collections:array-dimension arr)))))

(test fixnum-array-constructor-initial-element
  "Test fixnum-array constructor with initial-element"
  (let ((arr (fol.compiler.collection-functions:fixnum-array
              :dimensions '(5)
              :initial-element 42)))
    (is (fol.compiler.collections:<fix64-array>? arr))
    (is (= 5 (fol.compiler.collections:collection-size arr)))))

(test fixnum-array-type-predicate
  "Test fixnum-array type predicate"
  (let ((arr (fol.compiler.collection-functions:fixnum-array 42)))
    (is (fol.compiler.collections:<fix64-array>? arr))
    (is (fol.compiler.collections:<array-ops>? arr))
    (is (not (fol.compiler.collections:<f64-array>? arr)))
    (is (not (fol.compiler.collections:<f32-array>? arr)))))

;;; ============================================================================
;;; Array-Ops Base Class Tests
;;; ============================================================================

(test array-ops-base-class-predicate
  "Test that array-ops? predicate works for all typed arrays"
  (let ((f64 (fol.compiler.collection-functions:f64-array 1.0d0))
        (f32 (fol.compiler.collection-functions:f32-array 1.0))
        (fix (fol.compiler.collection-functions:fixnum-array 1)))
    (is (fol.compiler.collections:<array-ops>? f64))
    (is (fol.compiler.collections:<array-ops>? f32))
    (is (fol.compiler.collections:<array-ops>? fix))))

(test array-ops-dimension-inheritance
  "Test that all typed arrays inherit dimension slot from array-ops"
  (let ((f64 (fol.compiler.collection-functions:f64-array :dimensions '(3 4)
                                                          1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0
                                                          7.0d0 8.0d0 9.0d0 10.0d0 11.0d0 12.0d0))
        (f32 (fol.compiler.collection-functions:f32-array :dimensions '(2 2) 1.0 2.0 3.0 4.0))
        (fix (fol.compiler.collection-functions:fixnum-array :dimensions '(3 2)
                                                             1 2 3 4 5 6)))
    (is (equal '(3 4) (fol.compiler.collections:array-dimension f64)))
    (is (equal '(2 2) (fol.compiler.collections:array-dimension f32)))
    (is (equal '(3 2) (fol.compiler.collections:array-dimension fix)))))

;;; ============================================================================
;;; Collection Protocol Tests
;;; ============================================================================

(test typed-array-collection-size
  "Test collection-size protocol for typed arrays"
  (let ((f64 (fol.compiler.collection-functions:f64-array 1.0d0 2.0d0 3.0d0))
        (f32 (fol.compiler.collection-functions:f32-array 1.0 2.0))
        (fix (fol.compiler.collection-functions:fixnum-array 10 20 30 40)))
    (is (= 3 (fol.compiler.collections:collection-size f64)))
    (is (= 2 (fol.compiler.collections:collection-size f32)))
    (is (= 4 (fol.compiler.collections:collection-size fix)))))

;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'typed-arrays-suite)
