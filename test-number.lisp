(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test number-creation
  (is (equal (format nil "~{~A ~}" (mapcar #'wrap '(42 10000000000000000000 3.14 3.14d0 3.14f0 2/3 #C(1 2) #C(3.0 4.0))))
             "42 10000000000000000000 3.14 3.14d0 3.14 2/3 #C(1 2) #C(3.0 4.0) "))

(test type-operations
  (is (unwrap (<number>? (wrap 42))))
  (is (unwrap (<real>? (wrap 3.14))))
  (is (unwrap (<rational>? (wrap 42))))
  (is (unwrap (not (<ratio>? (wrap 718)))))
  (is (unwrap (<integer>? (wrap 42))))
  (is (unwrap (<fixnum>? (wrap 1000000))))
  (is (unwrap (<bignum>? (wrap 100000000000000000000000000000000000000))))
  (is (unwrap (<float>? (wrap 3.14))))
  (is (unwrap (<double-float>? (wrap 3.14d0))))
  (is (unwrap (<single-float>? (wrap 3.14f0))))
  (is (unwrap (<bool>? *true-instance*)))
  (is (unwrap (<bool>? *false-instance*)))
  (is (unwrap (not (<complex>? (wrap 1000000)))))))

(test odd?-predicate
  ;; Odd numbers
  (is (unwrap (odd? (wrap 1))))
  (is (unwrap (odd? (wrap 3))))
  (is (unwrap (odd? (wrap -1))))
  (is (unwrap (odd? (wrap -7))))
  (is (unwrap (odd? (wrap 999))))
  ;; Bignum odd
  (is (unwrap (odd? (wrap 10000000000000000001))))
  ;; Even numbers (should return false)
  (is (unwrap (not (odd? (wrap 0)))))
  (is (unwrap (not (odd? (wrap 2)))))
  (is (unwrap (not (odd? (wrap 4)))))
  (is (unwrap (not (odd? (wrap -2)))))
  (is (unwrap (not (odd? (wrap 1000)))))
  ;; Bignum even
  (is (unwrap (not (odd? (wrap 10000000000000000000)))))
  ;; Error cases - non-integer numbers
  (signals error (odd? (wrap 3.5)))
  (signals error (odd? (wrap 2/3)))
  (signals error (odd? (wrap #C(1 2))))
  ;; Error cases - non-numbers
  (signals error (odd? (wrap #\a)))
  (signals error (odd? (wrap "hello"))))

(test even?-predicate
  ;; Even numbers
  (is (unwrap (even? (wrap 0))))
  (is (unwrap (even? (wrap 2))))
  (is (unwrap (even? (wrap 4))))
  (is (unwrap (even? (wrap -2))))
  (is (unwrap (even? (wrap 1000))))
  ;; Bignum even
  (is (unwrap (even? (wrap 10000000000000000000))))
  ;; Odd numbers (should return false)
  (is (unwrap (not (even? (wrap 1)))))
  (is (unwrap (not (even? (wrap 3)))))
  (is (unwrap (not (even? (wrap -1)))))
  (is (unwrap (not (even? (wrap -7)))))
  (is (unwrap (not (even? (wrap 999)))))
  ;; Bignum odd
  (is (unwrap (not (even? (wrap 10000000000000000001)))))
  ;; Error cases - non-integer numbers
  (signals error (even? (wrap 3.5)))
  (signals error (even? (wrap 2/3)))
  (signals error (even? (wrap #C(1 2))))
  ;; Error cases - non-numbers
  (signals error (even? (wrap #\a)))
  (signals error (even? (wrap "hello"))))

(test zero?-predicate
  ;; Zero in various forms
  (is (unwrap (zero? (wrap 0))))
  (is (unwrap (zero? (wrap 0.0))))
  (is (unwrap (zero? (wrap 0.0d0))))
  (is (unwrap (zero? (wrap 0/1))))
  (is (unwrap (zero? (wrap #C(0 0)))))
  ;; Non-zero numbers (should return false)
  (is (unwrap (not (zero? (wrap 1)))))
  (is (unwrap (not (zero? (wrap -1)))))
  (is (unwrap (not (zero? (wrap 3.14)))))
  (is (unwrap (not (zero? (wrap 2/3)))))
  (is (unwrap (not (zero? (wrap #C(1 0))))))
  (is (unwrap (not (zero? (wrap #C(0 1))))))
  (is (unwrap (not (zero? (wrap 10000000000000000000)))))
  ;; Error cases - non-numbers
  (signals error (zero? (wrap #\a)))
  (signals error (zero? (wrap "hello")))
  (signals error (zero? *true-instance*)))

(test positive?-predicate
  ;; Positive integers
  (is (unwrap (positive? (wrap 1))))
  (is (unwrap (positive? (wrap 42))))
  (is (unwrap (positive? (wrap 999))))
  ;; Positive bignum
  (is (unwrap (positive? (wrap 10000000000000000000))))
  ;; Positive floats
  (is (unwrap (positive? (wrap 3.14))))
  (is (unwrap (positive? (wrap 0.0001))))
  (is (unwrap (positive? (wrap 3.14d0))))
  ;; Positive rationals
  (is (unwrap (positive? (wrap 1/2))))
  (is (unwrap (positive? (wrap 22/7))))
  ;; Zero and negative numbers (should return false)
  (is (unwrap (not (positive? (wrap 0)))))
  (is (unwrap (not (positive? (wrap 0.0)))))
  (is (unwrap (not (positive? (wrap 0/1)))))
  (is (unwrap (not (positive? (wrap -1)))))
  (is (unwrap (not (positive? (wrap -42)))))
  (is (unwrap (not (positive? (wrap -3.14)))))
  (is (unwrap (not (positive? (wrap -1/2)))))
  (is (unwrap (not (positive? (wrap -10000000000000000000)))))
  ;; Error cases - complex numbers
  (signals error (positive? (wrap #C(1 2))))
  (signals error (positive? (wrap #C(0 1))))
  (is (not (positive? (wrap #C(5 0)))))
  ;; Error cases - non-numbers
  (signals error (positive? (wrap #\a)))
  (signals error (positive? (wrap "hello")))
  (signals error (positive? *true-instance*)))

(test negative?-predicate
  ;; Negative integers
  (is (unwrap (negative? (wrap -1))))
  (is (unwrap (negative? (wrap -42))))
  (is (unwrap (negative? (wrap -999))))
  ;; Negative bignum
  (is (unwrap (negative? (wrap -10000000000000000000))))
  ;; Negative floats
  (is (unwrap (negative? (wrap -3.14))))
  (is (unwrap (negative? (wrap -0.0001))))
  (is (unwrap (negative? (wrap -3.14d0))))
  ;; Negative rationals
  (is (unwrap (negative? (wrap -1/2))))
  (is (unwrap (negative? (wrap -22/7))))
  ;; Zero and positive numbers (should return false)
  (is (unwrap (not (negative? (wrap 0)))))
  (is (unwrap (not (negative? (wrap 0.0)))))
  (is (unwrap (not (negative? (wrap 0/1)))))
  (is (unwrap (not (negative? (wrap 1)))))
  (is (unwrap (not (negative? (wrap 42)))))
  (is (unwrap (not (negative? (wrap 3.14)))))
  (is (unwrap (not (negative? (wrap 1/2)))))
  (is (unwrap (not (negative? (wrap 10000000000000000000)))))
  ;; Error cases - complex numbers
  (signals error (negative? (wrap #C(1 2))))
  (signals error (negative? (wrap #C(0 -1))))
  (is (not (negative? (wrap #C(-5 0)))))
  ;; Error cases - non-numbers
  (signals error (negative? (wrap #\a)))
  (signals error (negative? (wrap "hello")))
  (signals error (negative? *false-instance*)))

  
(test integral?-predicate
  ;; Integer types - always integral
  (is (unwrap (integral? (wrap 0))))
  (is (unwrap (integral? (wrap 1))))
  (is (unwrap (integral? (wrap -5))))
  (is (unwrap (integral? (wrap 42))))
  (is (unwrap (integral? (wrap -999))))
  ;; Bignum integers
  (is (unwrap (integral? (wrap 10000000000000000000))))
  (is (unwrap (integral? (wrap -10000000000000000000))))
  ;; Floats with integer values
  (is (unwrap (not (integral? (wrap 0.0)))))
  (is (unwrap (not (integral? (wrap 5.0)))))
  (is (unwrap (not (integral? (wrap -3.0)))))
  (is (unwrap (not (integral? (wrap 100.0d0)))))
  ;; Ratios that equal integers
  (is (unwrap (integral? (wrap 10/2))))
  (is (unwrap (integral? (wrap 6/3))))
  (is (unwrap (integral? (wrap -8/4))))
  (is (unwrap (integral? (wrap 0/1))))
  ;; Non-integral floats (should return false)
  (is (unwrap (not (integral? (wrap 3.14)))))
  (is (unwrap (not (integral? (wrap 0.5)))))
  (is (unwrap (not (integral? (wrap -2.7)))))
  (is (unwrap (not (integral? (wrap 0.0001)))))
  (is (unwrap (not (integral? (wrap 3.14d0)))))
  ;; Non-integral ratios (should return false)
  (is (unwrap (not (integral? (wrap 1/2)))))
  (is (unwrap (not (integral? (wrap 5/3)))))
  (is (unwrap (not (integral? (wrap -7/4)))))
  (is (unwrap (not (integral? (wrap 22/7)))))
  ;; Error cases - complex numbers
  (is (unwrap (not (integral? (wrap #C(1 2)))))
  (is (unwrap (integral? (wrap #C(5 0)))))
  (signals error (integral? (wrap #C(0 1))))
  ;; Error cases - non-numbers
  (signals error (integral? (wrap #\a)))
  (signals error (integral? (wrap "hello")))
  (signals error (integral? *true-instance*))))