;;; Transpiled from derived-value-invalidation.fol
(in-package :fol.core)

(DEFPACKAGE "DERIVED-VALUE-INVALIDATION"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "*"
                          "TIME"
                          "BIT-NAND"
                          "UNION"
                          "MAX"
                          "GCD"
                          "SOME"
                          "DEFCLASS"
                          "SORT"
                          ">"
                          "BUTLAST"
                          "<="
                          "DOTIMES"
                          "EXPT"
                          "ASINH"
                          ">="
                          "POP"
                          "SUBSEQ"
                          "NTH"
                          "COS"
                          "NOT"
                          "DENOMINATOR"
                          "IDENTITY"
                          "THIRD"
                          "ABS"
                          "AND"
                          "REPLACE"
                          "<"
                          "MERGE"
                          "NUMERATOR"
                          "BIT-NOR"
                          "DEFMACRO"
                          "READ"
                          "BIT-ANDC2"
                          "PUSH"
                          "BIT-ANDC1"
                          "/="
                          "TANH"
                          "/"
                          "READ-LINE"
                          "INTERSECTION"
                          "GENSYM"
                          "VECTOR"
                          "="
                          "CLOSE"
                          "DEFGENERIC"
                          "DELETE-FILE"
                          "ASSOC"
                          "KEYWORD"
                          "FORMAT"
                          "SIN"
                          "SINH"
                          "COMPLEMENT"
                          "REDUCE"
                          "APPLY"
                          "REMOVE"
                          "MAP"
                          "BIT-ORC1"
                          "PPRINT"
                          "LCM"
                          "TAN"
                          "INTERN"
                          "EVERY"
                          "FIRST"
                          "ARRAY-DIMENSION"
                          "REVERSE"
                          "LOOP"
                          "+"
                          "REST"
                          "QUOTE"
                          "COMPILE-FILE"
                          "-"
                          "OR"
                          "CONS"
                          "ATAN"
                          "ASIN"
                          "SQRT"
                          "ACOSH"
                          "BIT-ORC2"
                          "ACOS"
                          "FIND"
                          "COND"
                          "MIN"
                          "COSH"
                          "MACROEXPAND-1"
                          "WHEN"
                          "IF"
                          "CHAR"
                          "MACROEXPAND"
                          "LIST"
                          "CONSTANTLY"
                          "SEQUENCE"
                          "CASE"
                          "SECOND"
                          "RATIONALIZE"
                          "ASSERT"
                          "ATANH"
                          "SET"
                          "DEFMETHOD"
                          "DO"
                          "PRINT"
                          "GET"
                          "COUNT"
                          "LAST"
                          "LIST*"
                          "ATOM"
                          "EXP"
                          "SYMBOL")
  (:EXPORT <CART> ADD-ITEM CART-TOTAL SUM-READS RUN-BENCH))

(IN-PACKAGE "DERIVED-VALUE-INVALIDATION")

(DEFCLASS <CART> (<PERSISTENT-OBJECT>)
          ((ITEMS :INITARG :ITEMS :INITFORM (VECTOR))
           (_TOTAL :INITARG :_TOTAL :INITFORM NIL))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<CART> (&KEY ITEMS _TOTAL)
  (MAKE-INSTANCE '<CART> :ITEMS ITEMS :_TOTAL _TOTAL))

'<CART>

;;; Automatic derived-value invalidation: fires whenever :items changes.
;;; Checks slot identity with EQL (predicate-specialiser equivalent).
;;; For non-:items slots the EQL test fails and the result passes through.
(DEFMETHOD ASSOC :AROUND ((CART <CART>) SLOT VAL &REST KVPS)
  (DECLARE (SPECIAL CART SLOT VAL KVPS) (IGNORE KVPS))
  (LET ((RESULT (CALL-NEXT-METHOD)))
    (IF (EQL SLOT :ITEMS)
        (ASSOC RESULT :_TOTAL NIL)
        RESULT)))

;;; Add PRICE to the items vector.
;;; The :around method fires for slot :items and clears :_total.
(DEFUN ADD-ITEM (CART PRICE)
  (DECLARE (SPECIAL CART PRICE))
  (ASSOC CART :ITEMS (CONJ (GET CART :ITEMS) PRICE)))

;;; Lazy total: return cached value if present, else recompute from items.
(DEFUN CART-TOTAL (CART)
  (DECLARE (SPECIAL CART))
  (LET ((CACHED (GET CART :_TOTAL)))
    (IF (NULL CACHED)
        (REDUCE #'+ 0 (GET CART :ITEMS))
        CACHED)))

;;; Inner benchmark loop: N-READS cache-hit reads from CART.
(DEFUN SUM-READS (CART N-READS)
  (DECLARE (SPECIAL CART N-READS))
  (BLOCK LOOP-BLOCK-1
    (LET ((J 0) (S 0))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (IF (TRUTHY? (< J N-READS))
                   (PROGN
                    (PSETQ J (INC J) S (+ S (CART-TOTAL CART)))
                    (GO LOOP-1))
                   S)))
          (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))

;;; Outer benchmark: N-ITEMS rounds of (add + reads-per-item cache reads).
(DEFUN RUN-BENCH (N-ITEMS READS-PER-ITEM)
  (DECLARE (SPECIAL N-ITEMS READS-PER-ITEM))
  (BLOCK LOOP-BLOCK-2
    (LET ((I 0) (CART (MAKE '<CART>)) (TOTAL 0))
      (TAGBODY
       LOOP-2
        (LET ((RESULT-2
               (IF (TRUTHY? (< I N-ITEMS))
                   (LET ((C1 (ADD-ITEM CART I)))
                     (LET ((T1 (CART-TOTAL C1)))
                       (LET ((C2 (ASSOC C1 :_TOTAL T1)))
                         (LET ((READS (SUM-READS C2 READS-PER-ITEM)))
                           (PROGN
                            (PSETQ I (INC I) CART C2 TOTAL (+ TOTAL READS))
                            (GO LOOP-2))))))
                   TOTAL)))
          (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))
