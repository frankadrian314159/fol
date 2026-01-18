(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test compareop-numeric
  "Test numeric comparison operations"
  (is (unwrap (= (wrap 42) (wrap 42))))
  (is (unwrap (= (wrap 3.14) (wrap 3.14))))
  (is (unwrap (/= (wrap 3.14) (wrap 42))))
  (is (unwrap (< (wrap 2) (wrap 3))))
  (is (unwrap (<= (wrap 2) (wrap 2))))
  (is (unwrap (> (wrap 3) (wrap 2))))
  (is (unwrap (>= (wrap 3) (wrap 3))))
  (is (unwrap (/= (wrap 42) (wrap 3.14))))
  (is (unwrap (not (< (wrap 3) (wrap 2))))) 
  (is (unwrap (= (wrap 2) (wrap 2/1)))))

(test variadic-comparison
  (is (unwrap (= #f #f #f)))
  (is (unwrap (= #t #t #t)))
  (is (unwrap (not (= #t #f))))
  (is (unwrap (= #\a #\a #\a)))
  (is (unwrap (not (= #\a #\b))))
  (is (unwrap (not (= #t #t #f)))))

(test mixed-type-comparison
  "Test mixed type comparisons"
  (is (unwrap (= (wrap 42) 42)))
  (is (unwrap (= (wrap #\a) #\a)))
  (is (unwrap (not (= (wrap 42) #\a))))
  (is (unwrap (/= #t (wrap 42) #\a))))
  
(test char-comparison
  "Test character comparison operations"
  (let ((a (wrap #\a))
        (b (wrap #\b))
        (a2 (wrap #\a))
        (cap-a (wrap #\A)))
    ;; Equality
    (is (unwrap (= a a2)))
    (is (unwrap (not (= a b))))
    (is (unwrap (= a a a2)))
    
    ;; Inequality
    (is (unwrap (/= a b)))
    (is (unwrap (not (/= a a2))))
    (is (unwrap (/= a b cap-a)))
    
    ;; Less than
    (is (unwrap (< a b)))
    (is (unwrap (not (< b a))))
    (is (unwrap (< cap-a a)))  ; Uppercase comes before lowercase in ASCII
    
    ;; Greater than
    (is (unwrap (> b a)))
    (is (unwrap (not (> a b))))
    
    ;; Less than or equal
    (is (unwrap (<= a a2)))
    (is (unwrap (<= a b)))
    
    ;; Greater than or equal
    (is (unwrap (>= b a)))
    (is (unwrap (>= a a2)))))

  (test min-max-tests
  "Test min and max functions"
  ;; Numeric tests
  (is (= 1 (unwrap (min (wrap 1) (wrap 2) (wrap 3)))))
  (is (= 3 (unwrap (max (wrap 1) (wrap 2) (wrap 3)))))
  (is (= 1 (unwrap (min (wrap 3) (wrap 1) (wrap 2)))))
  (is (= 10 (unwrap (max (wrap 10) (wrap 5) (wrap -2)))))
  
  ;; Single argument
  (is (= 42 (unwrap (min (wrap 42)))))
  
  ;; Character tests
  (is (eq #\a (unwrap (min (wrap #\a) (wrap #\b) (wrap #\c)))))
  (is (eq #\z (unwrap (max (wrap #\x) (wrap #\y) (wrap #\z)))))
  
  ;; Boolean tests (where #f < #t)
  (is (eq nil (unwrap (min #t #f))))
  (is (eq t (unwrap (max #f #t))))

  ;; Char tests
  (is (= #\a (unwrap (min #\a #\b #\c))))
  (is (= #\c (unwrap (max #\a #\b #\c))))

  ;; String tests
  (is (= "apple" (unwrap (min "apple" "banana" "grape"))))
  (is (= "grape" (unwrap (max "apple" "banana" "grape"))))
  
  ;; Mixed types (provided they are comparable via %<)
  (is (= 1 (unwrap (min (wrap 5) 1)))))