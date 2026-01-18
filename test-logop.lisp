(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; NOT Operation Tests
;;; ============================================================================

(test not-boolean
  "Test NOT operation on booleans"
  ;; Basic boolean NOT
  (is (eq *true-instance* (not *false-instance*)))
  (is (eq *false-instance* (not *true-instance*)))
  (is (eq *true-instance* (not #f)))
  (is (eq *false-instance* (not #t))))

(test not-integer
  "Test bitwise NOT operation on integers"
  ;; Bitwise NOT (one's complement)
  (is (= -1 (unwrap (not (wrap 0)))))
  (is (= -2 (unwrap (not (wrap 1)))))
  (is (= -6 (unwrap (not (wrap 5)))))
  (is (= 0 (unwrap (not (wrap -1)))))
  (is (= -256 (unwrap (not (wrap 255))))))

;;; ============================================================================
;;; AND Operation Tests
;;; ============================================================================

(test and-boolean-identity
  "Test AND identity for booleans"
  ;; No arguments: identity is true
  (is (eq *true-instance* (and)))
  ;; Single argument: returns itself
  (is (eq *true-instance* (and #t)))
  (is (eq *false-instance* (and #f))))

(test and-boolean-two-args
  "Test binary AND on booleans"
  (is (eq *true-instance* (and #t #t)))
  (is (eq *false-instance* (and #t #f)))
  (is (eq *false-instance* (and #f #t)))
  (is (eq *false-instance* (and #f #f))))

(test and-boolean-multi-args
  "Test variadic AND on booleans"
  (is (eq *true-instance* (and #t #t #t)))
  (is (eq *false-instance* (and #t #t #f)))
  (is (eq *false-instance* (and #t #f #t)))
  (is (eq *false-instance* (and #f #f #f)))
  (is (eq *true-instance* (and #t #t #t #t #t))))

(test and-integer-two-args
  "Test bitwise AND on integers"
  ;; 12 = 1100, 10 = 1010, 12 & 10 = 1000 = 8
  (is (= 8 (unwrap (and (wrap 12) (wrap 10)))))
  ;; 15 = 1111, 7 = 0111, 15 & 7 = 0111 = 7
  (is (= 7 (unwrap (and (wrap 15) (wrap 7)))))
  ;; 5 = 0101, 3 = 0011, 5 & 3 = 0001 = 1
  (is (= 1 (unwrap (and (wrap 5) (wrap 3)))))
  ;; Any number & 0 = 0
  (is (= 0 (unwrap (and (wrap 255) (wrap 0))))))

(test and-integer-multi-args
  "Test variadic bitwise AND on integers"
  ;; 15 & 7 & 3 = 1111 & 0111 & 0011 = 0011 = 3
  (is (= 3 (unwrap (and (wrap 15) (wrap 7) (wrap 3)))))
  ;; 255 & 127 & 63 & 31 = 11111111 & 01111111 & 00111111 & 00011111 = 00011111 = 31
  (is (= 31 (unwrap (and (wrap 255) (wrap 127) (wrap 63) (wrap 31))))))

(test and-negative-integers
  "Test bitwise AND with negative integers"
  ;; -1 has all bits set, so -1 & n = n
  (is (= 5 (unwrap (and (wrap -1) (wrap 5)))))
  (is (= 42 (unwrap (and (wrap -1) (wrap 42))))))

;;; ============================================================================
;;; OR Operation Tests
;;; ============================================================================

(test or-boolean-identity
  "Test OR identity for booleans"
  ;; No arguments: identity is false
  (is (eq *false-instance* (or)))
  ;; Single argument: returns itself
  (is (eq *true-instance* (or #t)))
  (is (eq *false-instance* (or #f))))

(test or-boolean-two-args
  "Test binary OR on booleans"
  (is (eq *true-instance* (or #t #t)))
  (is (eq *true-instance* (or #t #f)))
  (is (eq *true-instance* (or #f #t)))
  (is (eq *false-instance* (or #f #f))))

(test or-boolean-multi-args
  "Test variadic OR on booleans"
  (is (eq *true-instance* (or #t #t #t)))
  (is (eq *true-instance* (or #t #f #f)))
  (is (eq *true-instance* (or #f #f #t)))
  (is (eq *false-instance* (or #f #f #f)))
  (is (eq *true-instance* (or #f #f #f #f #t))))

(test or-integer-two-args
  "Test bitwise OR on integers"
  ;; 12 = 1100, 10 = 1010, 12 | 10 = 1110 = 14
  (is (= 14 (unwrap (or (wrap 12) (wrap 10)))))
  ;; 8 = 1000, 4 = 0100, 8 | 4 = 1100 = 12
  (is (= 12 (unwrap (or (wrap 8) (wrap 4)))))
  ;; 1 = 0001, 2 = 0010, 1 | 2 = 0011 = 3
  (is (= 3 (unwrap (or (wrap 1) (wrap 2)))))
  ;; Any number | 0 = number
  (is (= 42 (unwrap (or (wrap 42) (wrap 0))))))

(test or-integer-multi-args
  "Test variadic bitwise OR on integers"
  ;; 1 | 2 | 4 = 001 | 010 | 100 = 111 = 7
  (is (= 7 (unwrap (or (wrap 1) (wrap 2) (wrap 4)))))
  ;; 16 | 8 | 4 | 2 | 1 = 10000 | 01000 | 00100 | 00010 | 00001 = 11111 = 31
  (is (= 31 (unwrap (or (wrap 16) (wrap 8) (wrap 4) (wrap 2) (wrap 1))))))

(test or-negative-integers
  "Test bitwise OR with negative integers"
  ;; -1 has all bits set, so n | -1 = -1
  (is (= -1 (unwrap (or (wrap 5) (wrap -1)))))
  (is (= -1 (unwrap (or (wrap -1) (wrap 42))))))

;;; ============================================================================
;;; XOR Operation Tests
;;; ============================================================================

(test xor-boolean-identity
  "Test XOR identity for booleans"
  ;; No arguments: identity is false
  (is (eq *false-instance* (xor)))
  ;; Single argument: returns itself
  (is (eq *true-instance* (xor #t)))
  (is (eq *false-instance* (xor #f))))

(test xor-boolean-two-args
  "Test binary XOR on booleans"
  (is (eq *false-instance* (xor #t #t)))
  (is (eq *true-instance* (xor #t #f)))
  (is (eq *true-instance* (xor #f #t)))
  (is (eq *false-instance* (xor #f #f))))

(test xor-boolean-multi-args
  "Test variadic XOR on booleans (odd number of trues)"
  ;; XOR is true if odd number of true values
  (is (eq *true-instance* (xor #t)))           ; 1 true = odd
  (is (eq *false-instance* (xor #t #t)))       ; 2 trues = even
  (is (eq *true-instance* (xor #t #t #t)))     ; 3 trues = odd
  (is (eq *false-instance* (xor #t #t #t #t))) ; 4 trues = even
  (is (eq *true-instance* (xor #t #f #f)))     ; 1 true = odd
  (is (eq *false-instance* (xor #f #f #f))))   ; 0 trues = even)

(test xor-integer-two-args
  "Test bitwise XOR on integers"
  ;; 12 = 1100, 10 = 1010, 12 ^ 10 = 0110 = 6
  (is (= 6 (unwrap (xor (wrap 12) (wrap 10)))))
  ;; 5 = 0101, 3 = 0011, 5 ^ 3 = 0110 = 6
  (is (= 6 (unwrap (xor (wrap 5) (wrap 3)))))
  ;; n ^ 0 = n
  (is (= 42 (unwrap (xor (wrap 42) (wrap 0)))))
  ;; n ^ n = 0
  (is (= 0 (unwrap (xor (wrap 17) (wrap 17))))))

(test xor-integer-multi-args
  "Test variadic bitwise XOR on integers"
  ;; 5 ^ 3 ^ 6 = 0101 ^ 0011 ^ 0110 = 0110 ^ 0110 = 0000 = 0
  (is (= 0 (unwrap (xor (wrap 5) (wrap 3) (wrap 6)))))
  ;; 1 ^ 2 ^ 4 = 001 ^ 010 ^ 100 = 011 ^ 100 = 111 = 7
  (is (= 7 (unwrap (xor (wrap 1) (wrap 2) (wrap 4))))))

;;; ============================================================================
;;; IMPLIES Operation Tests
;;; ============================================================================

(test implies-boolean
  "Test logical implication on booleans"
  ;; Truth table for IMPLIES
  (is (eq *true-instance* (implies #t #t)))    ; T -> T = T
  (is (eq *false-instance* (implies #t #f)))   ; T -> F = F
  (is (eq *true-instance* (implies #f #t)))    ; F -> T = T
  (is (eq *true-instance* (implies #f #f))))   ; F -> F = T

(test implies-integer
  "Test bitwise implication on integers"
  ;; Bitwise: (~A) | B
  ;; 12 = 1100, ~12 = ...11110011, 10 = 1010
  ;; ~12 | 10 = ...11110011 | 00001010 = ...11111011 = -5
  (is (= -5 (unwrap (implies (wrap 12) (wrap 10)))))
  ;; 0 implies anything = -1 (all bits set)
  (is (= -1 (unwrap (implies (wrap 0) (wrap 5))))))

;;; ============================================================================
;;; NAND Operation Tests
;;; ============================================================================

(test nand-boolean-identity
  "Test NAND identity for booleans"
  ;; No arguments: NAND() = NOT(AND()) = NOT(T) = F
  (is (eq *false-instance* (nand)))
  ;; Single argument: NAND(x) = NOT(x)
  (is (eq *false-instance* (nand #t)))
  (is (eq *true-instance* (nand #f))))

(test nand-boolean-two-args
  "Test binary NAND on booleans"
  (is (eq *false-instance* (nand #t #t)))
  (is (eq *true-instance* (nand #t #f)))
  (is (eq *true-instance* (nand #f #t)))
  (is (eq *true-instance* (nand #f #f))))

(test nand-boolean-multi-args
  "Test variadic NAND on booleans"
  (is (eq *false-instance* (nand #t #t #t)))
  (is (eq *true-instance* (nand #t #t #f)))
  (is (eq *true-instance* (nand #t #f #t)))
  (is (eq *true-instance* (nand #f #f #f))))

(test nand-integer-two-args
  "Test bitwise NAND on integers"
  ;; 12 = 1100, 10 = 1010, 12 & 10 = 1000 = 8, NOT 8 = -9
  (is (= -9 (unwrap (nand (wrap 12) (wrap 10)))))
  ;; 15 = 1111, 7 = 0111, 15 & 7 = 0111 = 7, NOT 7 = -8
  (is (= -8 (unwrap (nand (wrap 15) (wrap 7)))))
  ;; n NAND 0 = NOT(0) = -1
  (is (= -1 (unwrap (nand (wrap 42) (wrap 0))))))

(test nand-integer-multi-args
  "Test variadic bitwise NAND on integers"
  ;; 15 & 7 & 3 = 0011 = 3, NOT 3 = -4
  (is (= -4 (unwrap (nand (wrap 15) (wrap 7) (wrap 3)))))
  ;; Single arg: NOT(255) = -256
  (is (= -256 (unwrap (nand (wrap 255))))))

;;; ============================================================================
;;; NOR Operation Tests
;;; ============================================================================

(test nor-boolean-identity
  "Test NOR identity for booleans"
  ;; No arguments: NOR() = NOT(OR()) = NOT(F) = T
  (is (eq *true-instance* (nor)))
  ;; Single argument: NOR(x) = NOT(x)
  (is (eq *false-instance* (nor #t)))
  (is (eq *true-instance* (nor #f))))

(test nor-boolean-two-args
  "Test binary NOR on booleans"
  (is (eq *false-instance* (nor #t #t)))
  (is (eq *false-instance* (nor #t #f)))
  (is (eq *false-instance* (nor #f #t)))
  (is (eq *true-instance* (nor #f #f))))

(test nor-boolean-multi-args
  "Test variadic NOR on booleans"
  (is (eq *false-instance* (nor #t #t #t)))
  (is (eq *false-instance* (nor #t #f #f)))
  (is (eq *false-instance* (nor #f #f #t)))
  (is (eq *true-instance* (nor #f #f #f))))

(test nor-integer-two-args
  "Test bitwise NOR on integers"
  ;; 12 = 1100, 10 = 1010, 12 | 10 = 1110 = 14, NOT 14 = -15
  (is (= -15 (unwrap (nor (wrap 12) (wrap 10)))))
  ;; 1 = 0001, 2 = 0010, 1 | 2 = 0011 = 3, NOT 3 = -4
  (is (= -4 (unwrap (nor (wrap 1) (wrap 2)))))
  ;; 0 NOR 0 = NOT(0) = -1
  (is (= -1 (unwrap (nor (wrap 0) (wrap 0))))))

(test nor-integer-multi-args
  "Test variadic bitwise NOR on integers"
  ;; 1 | 2 | 4 = 111 = 7, NOT 7 = -8
  (is (= -8 (unwrap (nor (wrap 1) (wrap 2) (wrap 4)))))
  ;; Single arg: NOT(0) = -1
  (is (= -1 (unwrap (nor (wrap 0))))))