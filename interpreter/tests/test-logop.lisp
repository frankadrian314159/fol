(in-package :fol.tests)

(def-suite logop-suite
  :description "Tests for FOL logical operations"
  :in fol-suite)

(in-suite logop-suite)

;;; ============================================================================
;;; Binary Primitive Operations (%and, %or, %xor)
;;; ============================================================================

(test binary-and-booleans-raw
  "Test %and with raw boolean values"
  (is (eq t (%and t t)))
  (is (eq nil (%and t nil)))
  (is (eq nil (%and nil t)))
  (is (eq nil (%and nil nil))))

(test binary-and-booleans-wrapped
  "Test %and with wrapped boolean values"
  (let ((wt (wrap t))
        (wnil (wrap nil)))
    (is (eq t (%and wt wt)))
    (is (eq nil (%and wt wnil)))
    (is (eq nil (%and wnil wt)))
    (is (eq nil (%and wnil wnil)))
    ;; Mixed wrapped/raw
    (is (eq t (%and wt t)))
    (is (eq nil (%and wt nil)))
    (is (eq t (%and t wt)))
    (is (eq nil (%and nil wt)))))

(test binary-and-integers-raw
  "Test %and (bitwise) with raw integers"
  ;; 12 = 1100, 10 = 1010, 12 & 10 = 1000 = 8
  (is (cl:= 8 (%and 12 10)))
  ;; 15 = 1111, 7 = 0111, 15 & 7 = 0111 = 7
  (is (cl:= 7 (%and 15 7)))
  ;; 5 = 0101, 3 = 0011, 5 & 3 = 0001 = 1
  (is (cl:= 1 (%and 5 3)))
  ;; Any number & 0 = 0
  (is (cl:= 0 (%and 255 0)))
  ;; -1 has all bits set
  (is (cl:= 5 (%and -1 5))))

(test binary-and-integers-wrapped
  "Test %and (bitwise) with wrapped integers"
  (let ((w12 (wrap 12))
        (w10 (wrap 10)))
    (is (cl:= 8 (%and w12 w10)))
    (is (cl:= 8 (%and w12 10)))
    (is (cl:= 8 (%and 12 w10)))))

(test binary-or-booleans-raw
  "Test %or with raw boolean values"
  (is (eq t (%or t t)))
  (is (eq t (%or t nil)))
  (is (eq t (%or nil t)))
  (is (eq nil (%or nil nil))))

(test binary-or-booleans-wrapped
  "Test %or with wrapped boolean values"
  (let ((wt (wrap t))
        (wnil (wrap nil)))
    (is (eq t (%or wt wt)))
    (is (eq t (%or wt wnil)))
    (is (eq t (%or wnil wt)))
    (is (eq nil (%or wnil wnil)))
    ;; Mixed wrapped/raw
    (is (eq t (%or wt t)))
    (is (eq t (%or wt nil)))
    (is (eq t (%or t wnil)))
    (is (eq nil (%or nil wnil)))))

(test binary-or-integers-raw
  "Test %or (bitwise) with raw integers"
  ;; 12 = 1100, 10 = 1010, 12 | 10 = 1110 = 14
  (is (cl:= 14 (%or 12 10)))
  ;; 8 = 1000, 4 = 0100, 8 | 4 = 1100 = 12
  (is (cl:= 12 (%or 8 4)))
  ;; 1 = 0001, 2 = 0010, 1 | 2 = 0011 = 3
  (is (cl:= 3 (%or 1 2)))
  ;; Any number | 0 = number
  (is (cl:= 42 (%or 42 0)))
  ;; n | -1 = -1
  (is (cl:= -1 (%or 5 -1))))

(test binary-or-integers-wrapped
  "Test %or (bitwise) with wrapped integers"
  (let ((w12 (wrap 12))
        (w10 (wrap 10)))
    (is (cl:= 14 (%or w12 w10)))
    (is (cl:= 14 (%or w12 10)))
    (is (cl:= 14 (%or 12 w10)))))

(test binary-xor-booleans-raw
  "Test %xor with raw boolean values"
  (is (eq nil (%xor t t)))
  (is (eq t (%xor t nil)))
  (is (eq t (%xor nil t)))
  (is (eq nil (%xor nil nil))))

(test binary-xor-booleans-wrapped
  "Test %xor with wrapped boolean values"
  (let ((wt (wrap t))
        (wnil (wrap nil)))
    (is (eq nil (%xor wt wt)))
    (is (eq t (%xor wt wnil)))
    (is (eq t (%xor wnil wt)))
    (is (eq nil (%xor wnil wnil)))
    ;; Mixed wrapped/raw
    (is (eq nil (%xor wt t)))
    (is (eq t (%xor wt nil)))
    (is (eq t (%xor nil wt)))
    (is (eq nil (%xor t wt)))))

(test binary-xor-integers-raw
  "Test %xor (bitwise) with raw integers"
  ;; 12 = 1100, 10 = 1010, 12 ^ 10 = 0110 = 6
  (is (cl:= 6 (%xor 12 10)))
  ;; 5 = 0101, 3 = 0011, 5 ^ 3 = 0110 = 6
  (is (cl:= 6 (%xor 5 3)))
  ;; n ^ 0 = n
  (is (cl:= 42 (%xor 42 0)))
  ;; n ^ n = 0
  (is (cl:= 0 (%xor 17 17))))

(test binary-xor-integers-wrapped
  "Test %xor (bitwise) with wrapped integers"
  (let ((w12 (wrap 12))
        (w10 (wrap 10)))
    (is (cl:= 6 (%xor w12 w10)))
    (is (cl:= 6 (%xor w12 10)))
    (is (cl:= 6 (%xor 12 w10)))))

;;; ============================================================================
;;; NOT Operation
;;; ============================================================================

(test not-booleans-raw
  "Test not with raw boolean values"
  (is (eq t (not nil)))
  (is (eq nil (not t))))

(test not-booleans-wrapped
  "Test not with wrapped boolean values"
  (let ((wt (wrap t))
        (wnil (wrap nil)))
    (is (eq nil (not wt)))
    (is (eq t (not wnil)))))

(test not-integers-raw
  "Test not (bitwise complement) with raw integers"
  ;; One's complement
  (is (cl:= -1 (not 0)))
  (is (cl:= -2 (not 1)))
  (is (cl:= -6 (not 5)))
  (is (cl:= 0 (not -1)))
  (is (cl:= -256 (not 255))))

(test not-integers-wrapped
  "Test not (bitwise complement) with wrapped integers"
  (is (cl:= -1 (not (wrap 0))))
  (is (cl:= -2 (not (wrap 1))))
  (is (cl:= 0 (not (wrap -1)))))

;;; ============================================================================
;;; Variadic AND Operation
;;; ============================================================================

(test variadic-and-identity
  "Test and with zero or one argument"
  ;; No arguments: identity is true
  (is (eq t (and)))
  ;; Single argument: returns its value
  (is (eq t (and t)))
  (is (eq nil (and nil)))
  (is (eq t (and (wrap t))))
  (is (eq nil (and (wrap nil)))))

(test variadic-and-booleans
  "Test variadic and with boolean values"
  (is (eq t (and t t)))
  (is (eq nil (and t nil)))
  (is (eq nil (and nil t)))
  (is (eq nil (and nil nil)))
  (is (eq t (and t t t)))
  (is (eq nil (and t t nil)))
  (is (eq nil (and t nil t)))
  (is (eq nil (and nil nil nil)))
  (is (eq t (and t t t t t))))

(test variadic-and-integers
  "Test variadic and (bitwise) with integer values"
  ;; 15 & 7 & 3 = 1111 & 0111 & 0011 = 0011 = 3
  (is (cl:= 3 (and 15 7 3)))
  ;; 255 & 127 & 63 & 31 = 31
  (is (cl:= 31 (and 255 127 63 31)))
  ;; Single integer arg
  (is (cl:= 42 (and 42))))

(test variadic-and-mixed-wrapped-raw
  "Test variadic and with mixed wrapped and raw values"
  (is (eq t (and t (wrap t) t)))
  (is (eq nil (and t (wrap nil) t)))
  (is (cl:= 3 (and (wrap 15) 7 (wrap 3)))))

;;; ============================================================================
;;; Variadic OR Operation
;;; ============================================================================

(test variadic-or-identity
  "Test or with zero or one argument"
  ;; No arguments: identity is false
  (is (eq nil (or)))
  ;; Single argument: returns its value
  (is (eq t (or t)))
  (is (eq nil (or nil)))
  (is (eq t (or (wrap t))))
  (is (eq nil (or (wrap nil)))))

(test variadic-or-booleans
  "Test variadic or with boolean values"
  (is (eq t (or t t)))
  (is (eq t (or t nil)))
  (is (eq t (or nil t)))
  (is (eq nil (or nil nil)))
  (is (eq t (or t nil nil)))
  (is (eq t (or nil nil t)))
  (is (eq nil (or nil nil nil)))
  (is (eq t (or nil nil nil nil t))))

(test variadic-or-integers
  "Test variadic or (bitwise) with integer values"
  ;; 1 | 2 | 4 = 001 | 010 | 100 = 111 = 7
  (is (cl:= 7 (or 1 2 4)))
  ;; 16 | 8 | 4 | 2 | 1 = 31
  (is (cl:= 31 (or 16 8 4 2 1)))
  ;; Single integer arg
  (is (cl:= 42 (or 42))))

(test variadic-or-mixed-wrapped-raw
  "Test variadic or with mixed wrapped and raw values"
  (is (eq t (or nil (wrap t) nil)))
  (is (eq nil (or nil (wrap nil) nil)))
  (is (cl:= 7 (or (wrap 1) 2 (wrap 4)))))

;;; ============================================================================
;;; Variadic XOR Operation
;;; ============================================================================

(test variadic-xor-identity
  "Test xor with zero or one argument"
  ;; No arguments: identity is false
  (is (eq nil (xor)))
  ;; Single argument: returns its value
  (is (eq t (xor t)))
  (is (eq nil (xor nil)))
  (is (eq t (xor (wrap t))))
  (is (eq nil (xor (wrap nil)))))

(test variadic-xor-booleans
  "Test variadic xor with boolean values (odd number of trues)"
  ;; XOR is true if odd number of true values
  (is (eq nil (xor t t)))       ; 2 trues = even
  (is (eq t (xor t nil)))       ; 1 true = odd
  (is (eq t (xor nil t)))       ; 1 true = odd
  (is (eq nil (xor nil nil)))   ; 0 trues = even
  (is (eq t (xor t t t)))       ; 3 trues = odd
  (is (eq nil (xor t t t t)))   ; 4 trues = even
  (is (eq t (xor t nil nil)))   ; 1 true = odd
  (is (eq nil (xor nil nil nil))) ; 0 trues = even)
  (is (eq nil (xor t t nil)))   ; t xor t = nil, nil xor nil = nil
  )

(test variadic-xor-integers
  "Test variadic xor (bitwise) with integer values"
  ;; 5 ^ 3 ^ 6 = 0101 ^ 0011 ^ 0110 = 0110 ^ 0110 = 0000 = 0
  (is (cl:= 0 (xor 5 3 6)))
  ;; 1 ^ 2 ^ 4 = 001 ^ 010 ^ 100 = 111 = 7
  (is (cl:= 7 (xor 1 2 4)))
  ;; Single integer arg
  (is (cl:= 42 (xor 42))))

(test variadic-xor-mixed-wrapped-raw
  "Test variadic xor with mixed wrapped and raw values"
  (is (eq t (xor t (wrap nil))))
  (is (eq nil (xor t (wrap t))))
  (is (cl:= 7 (xor (wrap 1) 2 (wrap 4)))))

;;; ============================================================================
;;; IMPLIES Operation
;;; ============================================================================

(test implies-booleans-raw
  "Test implies with raw boolean values"
  ;; Truth table: A -> B = (NOT A) OR B
  (is (eq t (implies t t)))     ; T -> T = T
  (is (eq nil (implies t nil))) ; T -> F = F
  (is (eq t (implies nil t)))   ; F -> T = T
  (is (eq t (implies nil nil))) ; F -> F = T
  )

(test implies-booleans-wrapped
  "Test implies with wrapped boolean values"
  (let ((wt (wrap t))
        (wnil (wrap nil)))
    (is (eq t (implies wt wt)))
    (is (eq nil (implies wt wnil)))
    (is (eq t (implies wnil wt)))
    (is (eq t (implies wnil wnil)))
    ;; Mixed
    (is (eq t (implies wt t)))
    (is (eq nil (implies wt nil)))
    (is (eq t (implies nil wt)))
    (is (eq t (implies t wt)))))

(test implies-integers-raw
  "Test implies (bitwise) with raw integers"
  ;; Bitwise: (~A) | B
  ;; 12 = 1100, ~12 = ...11110011, 10 = 1010
  ;; ~12 | 10 = ...11110011 | 00001010 = ...11111011 = -5
  (is (cl:= -5 (implies 12 10)))
  ;; 0 implies anything = -1 (all bits set, since ~0 = -1)
  (is (cl:= -1 (implies 0 5)))
  ;; -1 implies x = x (since ~(-1) = 0)
  (is (cl:= 42 (implies -1 42))))

(test implies-integers-wrapped
  "Test implies (bitwise) with wrapped integers"
  (let ((w12 (wrap 12))
        (w10 (wrap 10)))
    (is (cl:= -5 (implies w12 w10)))
    (is (cl:= -5 (implies w12 10)))
    (is (cl:= -5 (implies 12 w10)))))

;;; ============================================================================
;;; NAND Operation
;;; ============================================================================

(test nand-identity
  "Test nand with zero or one argument"
  ;; No arguments: NAND() = NOT(AND()) = NOT(T) = F
  (is (eq nil (nand)))
  ;; Single argument: NAND(x) = NOT(x)
  (is (eq nil (nand t)))
  (is (eq t (nand nil)))
  (is (eq nil (nand (wrap t))))
  (is (eq t (nand (wrap nil)))))

(test nand-booleans
  "Test nand with boolean values"
  (is (eq nil (nand t t)))
  (is (eq t (nand t nil)))
  (is (eq t (nand nil t)))
  (is (eq t (nand nil nil)))
  (is (eq nil (nand t t t)))
  (is (eq t (nand t t nil)))
  (is (eq t (nand t nil t)))
  (is (eq t (nand nil nil nil))))

(test nand-integers
  "Test nand (bitwise) with integer values"
  ;; 12 = 1100, 10 = 1010, 12 & 10 = 1000 = 8, NOT 8 = -9
  (is (cl:= -9 (nand 12 10)))
  ;; 15 = 1111, 7 = 0111, 15 & 7 = 0111 = 7, NOT 7 = -8
  (is (cl:= -8 (nand 15 7)))
  ;; n NAND 0 = NOT(0) = -1
  (is (cl:= -1 (nand 42 0)))
  ;; Multi-arg: 15 & 7 & 3 = 3, NOT 3 = -4
  (is (cl:= -4 (nand 15 7 3)))
  ;; Single arg: NOT(255) = -256
  (is (cl:= -256 (nand 255))))

(test nand-mixed-wrapped-raw
  "Test nand with mixed wrapped and raw values"
  (is (eq t (nand (wrap t) nil)))
  (is (eq nil (nand (wrap t) t)))
  (is (cl:= -9 (nand (wrap 12) 10))))

;;; ============================================================================
;;; NOR Operation
;;; ============================================================================

(test nor-identity
  "Test nor with zero or one argument"
  ;; No arguments: NOR() = NOT(OR()) = NOT(F) = T
  (is (eq t (nor)))
  ;; Single argument: NOR(x) = NOT(x)
  (is (eq nil (nor t)))
  (is (eq t (nor nil)))
  (is (eq nil (nor (wrap t))))
  (is (eq t (nor (wrap nil)))))

(test nor-booleans
  "Test nor with boolean values"
  (is (eq nil (nor t t)))
  (is (eq nil (nor t nil)))
  (is (eq nil (nor nil t)))
  (is (eq t (nor nil nil)))
  (is (eq nil (nor t t t)))
  (is (eq nil (nor t nil nil)))
  (is (eq nil (nor nil nil t)))
  (is (eq t (nor nil nil nil))))

(test nor-integers
  "Test nor (bitwise) with integer values"
  ;; 12 = 1100, 10 = 1010, 12 | 10 = 1110 = 14, NOT 14 = -15
  (is (cl:= -15 (nor 12 10)))
  ;; 1 = 0001, 2 = 0010, 1 | 2 = 0011 = 3, NOT 3 = -4
  (is (cl:= -4 (nor 1 2)))
  ;; 0 NOR 0 = NOT(0) = -1
  (is (cl:= -1 (nor 0 0)))
  ;; Multi-arg: 1 | 2 | 4 = 7, NOT 7 = -8
  (is (cl:= -8 (nor 1 2 4)))
  ;; Single arg: NOT(0) = -1
  (is (cl:= -1 (nor 0))))

(test nor-mixed-wrapped-raw
  "Test nor with mixed wrapped and raw values"
  (is (eq nil (nor (wrap t) nil)))
  (is (eq t (nor (wrap nil) nil)))
  (is (cl:= -15 (nor (wrap 12) 10))))

;;; ============================================================================
;;; Edge Cases
;;; ============================================================================

(test logical-with-negative-integers
  "Test bitwise operations with negative integers"
  ;; -1 has all bits set
  (is (cl:= 5 (and -1 5)))
  (is (cl:= 5 (and 5 -1)))
  (is (cl:= -1 (or 5 -1)))
  (is (cl:= -1 (or -1 5)))
  (is (cl:= -6 (xor 5 -1)))  ; 5 ^ -1 = ~5 = -6
  )

(test logical-with-zero
  "Test bitwise operations with zero"
  (is (cl:= 0 (and 42 0)))
  (is (cl:= 0 (and 0 42)))
  (is (cl:= 42 (or 42 0)))
  (is (cl:= 42 (or 0 42)))
  (is (cl:= 42 (xor 42 0)))
  (is (cl:= 42 (xor 0 42))))

(test logical-self-operations
  "Test self-operations"
  (is (cl:= 42 (and 42 42)))
  (is (cl:= 42 (or 42 42)))
  (is (cl:= 0 (xor 42 42)))  ; n XOR n = 0
  )

(test logical-large-integers
  "Test bitwise operations with large integers"
  (let ((big1 (cl:expt 2 100))
        (big2 (cl:expt 2 50)))
    (is (cl:= 0 (and big1 big2)))  ; different bit positions
    (is (cl:= (cl:+ big1 big2) (or big1 big2)))
    (is (cl:= (cl:+ big1 big2) (xor big1 big2)))))

(test de-morgan-laws
  "Test De Morgan's laws: NOT(A AND B) = (NOT A) OR (NOT B)"
  ;; For booleans
  (is (eq (not (and t nil)) (or (not t) (not nil))))
  (is (eq (not (or t nil)) (and (not t) (not nil))))
  ;; For integers (bitwise)
  (is (cl:= (not (and 12 10)) (or (not 12) (not 10))))
  (is (cl:= (not (or 12 10)) (and (not 12) (not 10)))))

(test double-negation
  "Test double negation: NOT(NOT(x)) = x"
  (is (eq t (not (not t))))
  (is (eq nil (not (not nil))))
  (is (cl:= 42 (not (not 42))))
  (is (cl:= 0 (not (not 0))))
  (is (cl:= -5 (not (not -5)))))

(test xor-associativity
  "Test XOR associativity: (a XOR b) XOR c = a XOR (b XOR c)"
  (is (cl:= (xor (xor 5 3) 7) (xor 5 (xor 3 7))))
  (is (cl:= (xor (xor 12 10) 6) (xor 12 (xor 10 6)))))

;;; ============================================================================
;;; Error Cases
;;; ============================================================================

(test logical-type-errors
  "Test that logical operations signal errors for incompatible types"
  ;; Can't AND a boolean with an integer (they're different types)
  (signals error (%and t 5))
  (signals error (%and 5 t))
  (signals error (%or nil 42))
  (signals error (%xor t 10)))
