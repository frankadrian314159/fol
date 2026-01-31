(in-package :fol.tests)

;;; ============================================================================
;;; Boolean Tests - Comprehensive test suite for FOL boolean operations
;;; ============================================================================

(def-suite* :fol.bool-tests)

;;; ---------------------------------------------------------------------------
;;; Boolean Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test bool-predicate-raw-true
  "Test <bool>? predicate with raw T."
  (is-true (<bool>? t)))

(test bool-predicate-raw-nil
  "Test <bool>? predicate with raw NIL."
  (is-true (<bool>? nil)))

(test bool-predicate-wrapped-true
  "Test <bool>? predicate with wrapped T."
  (is-true (<bool>? (wrap-bool t))))

(test bool-predicate-wrapped-nil
  "Test <bool>? predicate with wrapped NIL."
  (is-true (<bool>? (wrap-bool nil))))

(test bool-predicate-non-booleans
  "Test <bool>? predicate returns NIL for non-booleans."
  (is-false (<bool>? 0))
  (is-false (<bool>? 1))
  (is-false (<bool>? "true"))
  (is-false (<bool>? "false"))
  (is-false (<bool>? 'true))
  (is-false (<bool>? :true))
  (is-false (<bool>? #\T))
  (is-false (<bool>? '()))  ; empty list is NIL, which is a boolean
  )

;;; ---------------------------------------------------------------------------
;;; Boolean Wrapping/Unwrapping Tests
;;; ---------------------------------------------------------------------------

(test bool-wrap-unwrap-true
  "Test wrapping and unwrapping of T."
  (let ((wrapped (wrap-bool t)))
    (is (typep wrapped '<bool>))
    (is (eq t (fol-value wrapped)))
    (is (eq t (unwrap-bool wrapped)))))

(test bool-wrap-unwrap-nil
  "Test wrapping and unwrapping of NIL."
  (let ((wrapped (wrap-bool nil)))
    (is (typep wrapped '<bool>))
    (is (eq nil (fol-value wrapped)))
    (is (eq nil (unwrap-bool wrapped)))))

(test bool-wrap-roundtrip
  "Test that wrap/unwrap is identity for booleans."
  (is (eq t (unwrap-bool (wrap-bool t))))
  (is (eq nil (unwrap-bool (wrap-bool nil)))))

(test bool-fol-value-raw
  "Test fol-value on raw booleans (pass-through)."
  (is (eq t (fol-value t)))
  (is (eq nil (fol-value nil))))

(test bool-fol-type-of
  "Test fol-type-of for booleans."
  (is (eq '<bool> (fol-type-of t)))
  (is (eq '<bool> (fol-type-of nil)))
  (is (eq '<bool> (fol-type-of (wrap-bool t))))
  (is (eq '<bool> (fol-type-of (wrap-bool nil)))))

;;; ---------------------------------------------------------------------------
;;; Boolean Equality Tests
;;; ---------------------------------------------------------------------------

(test bool-equality-raw-raw
  "Test equality between raw booleans."
  (is-true (%= t t))
  (is-true (%= nil nil))
  (is-false (%= t nil))
  (is-false (%= nil t)))

(test bool-equality-wrapped-wrapped
  "Test equality between wrapped booleans."
  (let ((t1 (wrap-bool t))
        (t2 (wrap-bool t))
        (n1 (wrap-bool nil))
        (n2 (wrap-bool nil)))
    (is-true (%= t1 t2))
    (is-true (%= n1 n2))
    (is-false (%= t1 n1))
    (is-false (%= n1 t1))))

(test bool-equality-mixed
  "Test equality between raw and wrapped booleans."
  (let ((t-wrap (wrap-bool t))
        (nil-wrap (wrap-bool nil)))
    (is-true (%= t-wrap t))
    (is-true (%= t t-wrap))
    (is-true (%= nil-wrap nil))
    (is-true (%= nil nil-wrap))
    (is-false (%= t-wrap nil))
    (is-false (%= nil t-wrap))))

(test bool-inequality
  "Test inequality for booleans."
  (is-true (%/= t nil))
  (is-true (%/= nil t))
  (is-false (%/= t t))
  (is-false (%/= nil nil))
  (let ((t-wrap (wrap-bool t))
        (nil-wrap (wrap-bool nil)))
    (is-true (%/= t-wrap nil-wrap))
    (is-false (%/= t-wrap t))))

;;; ---------------------------------------------------------------------------
;;; Boolean Logical Operations Tests
;;; ---------------------------------------------------------------------------

(test bool-and-raw
  "Test AND operation with raw booleans."
  (is-true (%and t t))
  (is-false (%and t nil))
  (is-false (%and nil t))
  (is-false (%and nil nil)))

(test bool-and-wrapped
  "Test AND operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%and tt tt))
    (is-false (%and tt nn))
    (is-false (%and nn tt))
    (is-false (%and nn nn))))

(test bool-and-mixed
  "Test AND operation with mixed raw and wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%and tt t))
    (is-true (%and t tt))
    (is-false (%and tt nil))
    (is-false (%and nil tt))
    (is-false (%and nn t))
    (is-false (%and t nn))))

(test bool-or-raw
  "Test OR operation with raw booleans."
  (is-true (%or t t))
  (is-true (%or t nil))
  (is-true (%or nil t))
  (is-false (%or nil nil)))

(test bool-or-wrapped
  "Test OR operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%or tt tt))
    (is-true (%or tt nn))
    (is-true (%or nn tt))
    (is-false (%or nn nn))))

(test bool-or-mixed
  "Test OR operation with mixed raw and wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%or tt t))
    (is-true (%or t tt))
    (is-true (%or tt nil))
    (is-true (%or nil tt))
    (is-true (%or nn t))
    (is-true (%or t nn))
    (is-false (%or nn nil))
    (is-false (%or nil nn))))

(test bool-xor-raw
  "Test XOR operation with raw booleans."
  (is-false (%xor t t))
  (is-true (%xor t nil))
  (is-true (%xor nil t))
  (is-false (%xor nil nil)))

(test bool-xor-wrapped
  "Test XOR operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-false (%xor tt tt))
    (is-true (%xor tt nn))
    (is-true (%xor nn tt))
    (is-false (%xor nn nn))))

(test bool-xor-mixed
  "Test XOR operation with mixed raw and wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-false (%xor tt t))
    (is-false (%xor t tt))
    (is-true (%xor tt nil))
    (is-true (%xor nil tt))
    (is-true (%xor nn t))
    (is-true (%xor t nn))
    (is-false (%xor nn nil))
    (is-false (%xor nil nn))))

(test bool-not-raw
  "Test NOT operation with raw booleans."
  (is-false (not t))
  (is-true (not nil)))

(test bool-not-wrapped
  "Test NOT operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-false (not tt))
    (is-true (not nn))))

;;; ---------------------------------------------------------------------------
;;; Variadic Boolean Operations
;;; ---------------------------------------------------------------------------

(test bool-variadic-and
  "Test variadic AND operation."
  (is-true (and t t t))
  (is-true (and t t t t t))
  (is-false (and t t nil t))
  (is-false (and nil))
  (is-true (and t))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (and tt t tt))
    (is-false (and tt nn t))))

(test bool-variadic-or
  "Test variadic OR operation."
  (is-true (or t nil nil))
  (is-true (or nil nil nil t nil))
  (is-false (or nil nil nil))
  (is-false (or nil))
  (is-true (or t))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (or nn nil tt))
    (is-false (or nn nil nn))))

;;; ---------------------------------------------------------------------------
;;; Implies, NAND, NOR Operations
;;; ---------------------------------------------------------------------------

(test bool-implies-raw
  "Test IMPLIES operation with raw booleans."
  (is-true (implies t t))     ; T -> T = T
  (is-false (implies t nil))  ; T -> NIL = NIL
  (is-true (implies nil t))   ; NIL -> T = T
  (is-true (implies nil nil))) ; NIL -> NIL = T

(test bool-implies-wrapped
  "Test IMPLIES operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (implies tt tt))
    (is-false (implies tt nn))
    (is-true (implies nn tt))
    (is-true (implies nn nn))))

(test bool-implies-mixed
  "Test IMPLIES operation with mixed raw and wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (implies tt t))
    (is-false (implies t nn))
    (is-true (implies nn t))
    (is-true (implies nil tt))))

(test bool-nand-raw
  "Test NAND operation with raw booleans."
  (is-false (nand t t))
  (is-true (nand t nil))
  (is-true (nand nil t))
  (is-true (nand nil nil)))

(test bool-nand-wrapped
  "Test NAND operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-false (nand tt tt))
    (is-true (nand tt nn))
    (is-true (nand nn tt))
    (is-true (nand nn nn))))

(test bool-nor-raw
  "Test NOR operation with raw booleans."
  (is-false (nor t t))
  (is-false (nor t nil))
  (is-false (nor nil t))
  (is-true (nor nil nil)))

(test bool-nor-wrapped
  "Test NOR operation with wrapped booleans."
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-false (nor tt tt))
    (is-false (nor tt nn))
    (is-false (nor nn tt))
    (is-true (nor nn nn))))

;;; ---------------------------------------------------------------------------
;;; Boolean Logic Laws and Edge Cases
;;; ---------------------------------------------------------------------------

(test bool-double-negation
  "Test double negation: NOT(NOT x) = x."
  (is-true (not (not t)))
  (is-false (not (not nil)))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (not (not tt)))
    (is-false (not (not nn)))))

(test bool-de-morgans-law-and
  "Test De Morgan's Law: NOT(A AND B) = (NOT A) OR (NOT B)."
  (dolist (a '(t nil))
    (dolist (b '(t nil))
      (is (eq (not (%and a b))
              (%or (not a) (not b)))))))

(test bool-de-morgans-law-or
  "Test De Morgan's Law: NOT(A OR B) = (NOT A) AND (NOT B)."
  (dolist (a '(t nil))
    (dolist (b '(t nil))
      (is (eq (not (%or a b))
              (%and (not a) (not b)))))))

(test bool-idempotent-and
  "Test idempotence: A AND A = A."
  (is-true (%and t t))
  (is-false (%and nil nil))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%and tt tt))
    (is-false (%and nn nn))))

(test bool-idempotent-or
  "Test idempotence: A OR A = A."
  (is-true (%or t t))
  (is-false (%or nil nil))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%or tt tt))
    (is-false (%or nn nn))))

(test bool-identity-and
  "Test identity: A AND T = A."
  (is-true (%and t t))
  (is-false (%and nil t))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%and tt t))
    (is-false (%and nn t))))

(test bool-identity-or
  "Test identity: A OR NIL = A."
  (is-true (%or t nil))
  (is-false (%or nil nil))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%or tt nil))
    (is-false (%or nn nil))))

(test bool-annihilator-and
  "Test annihilator: A AND NIL = NIL."
  (is-false (%and t nil))
  (is-false (%and nil nil))
  (let ((tt (wrap-bool t)))
    (is-false (%and tt nil))))

(test bool-annihilator-or
  "Test annihilator: A OR T = T."
  (is-true (%or t t))
  (is-true (%or nil t))
  (let ((nn (wrap-bool nil)))
    (is-true (%or nn t))))

(test bool-complement-and
  "Test complement: A AND (NOT A) = NIL."
  (is-false (%and t (not t)))
  (is-false (%and nil (not nil)))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-false (%and tt (not tt)))
    (is-false (%and nn (not nn)))))

(test bool-complement-or
  "Test complement: A OR (NOT A) = T."
  (is-true (%or t (not t)))
  (is-true (%or nil (not nil)))
  (let ((tt (wrap-bool t))
        (nn (wrap-bool nil)))
    (is-true (%or tt (not tt)))
    (is-true (%or nn (not nn)))))

(test bool-implies-equivalence
  "Test that (A IMPLIES B) = ((NOT A) OR B)."
  (dolist (a '(t nil))
    (dolist (b '(t nil))
      (is (eq (implies a b)
              (%or (not a) b))))))

(test bool-xor-equivalence
  "Test that (A XOR B) = ((A AND (NOT B)) OR ((NOT A) AND B))."
  (dolist (a '(t nil))
    (dolist (b '(t nil))
      (is (eq (%xor a b)
              (%or (%and a (not b))
                             (%and (not a) b)))))))

(test bool-nand-equivalence
  "Test that (A NAND B) = NOT(A AND B)."
  (dolist (a '(t nil))
    (dolist (b '(t nil))
      (is (eq (nand a b)
              (not (%and a b)))))))

(test bool-nor-equivalence
  "Test that (A NOR B) = NOT(A OR B)."
  (dolist (a '(t nil))
    (dolist (b '(t nil))
      (is (eq (nor a b)
              (not (%or a b)))))))

;;; ---------------------------------------------------------------------------
;;; parse-bool Tests
;;; ---------------------------------------------------------------------------

(test parse-bool-t-lowercase
  "Test parse-bool with lowercase 't'."
  (let ((result (parse-bool "t")))
    (is (typep result '<bool>))
    (is-true (fol-value result))))

(test parse-bool-t-uppercase
  "Test parse-bool with uppercase 'T'."
  (let ((result (parse-bool "T")))
    (is (typep result '<bool>))
    (is-true (fol-value result))))

(test parse-bool-nil-lowercase
  "Test parse-bool with lowercase 'nil'."
  (let ((result (parse-bool "nil")))
    (is (typep result '<bool>))
    (is-false (fol-value result))))

(test parse-bool-nil-uppercase
  "Test parse-bool with uppercase 'NIL'."
  (let ((result (parse-bool "NIL")))
    (is (typep result '<bool>))
    (is-false (fol-value result))))

(test parse-bool-nil-mixed-case
  "Test parse-bool with mixed case 'Nil'."
  (let ((result (parse-bool "Nil")))
    (is (typep result '<bool>))
    (is-false (fol-value result))))

(test parse-bool-empty-list
  "Test parse-bool with empty list '()'."
  (let ((result (parse-bool "()")))
    (is (typep result '<bool>))
    (is-false (fol-value result))))

(test parse-bool-invalid-true
  "Test parse-bool with invalid 'true' string."
  (signals error (parse-bool "true")))

(test parse-bool-invalid-false
  "Test parse-bool with invalid 'false' string."
  (signals error (parse-bool "false")))

(test parse-bool-invalid-number
  "Test parse-bool with invalid number string."
  (signals error (parse-bool "1")))

(test parse-bool-invalid-type
  "Test parse-bool with invalid input type."
  (signals error (parse-bool 42)))
