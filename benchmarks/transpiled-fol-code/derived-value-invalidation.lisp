;;; Transpiled from derived-value-invalidation.fol
(in-package :fol.core)

(DEFPACKAGE "DERIVED-VALUE-INVALIDATION"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "BIT-NAND"
                          "LCM"
                          "GCD"
                          "COS"
                          "DENOMINATOR"
                          "ABS"
                          "NUMERATOR"
                          "BIT-NOR"
                          "BIT-ANDC2"
                          "BIT-ANDC1"
                          "TANH"
                          "ASINH"
                          "GENSYM"
                          "EXPT"
                          "SIN"
                          "SINH"
                          "BIT-ORC1"
                          "TAN"
                          "ARRAY-DIMENSION"
                          "ATAN"
                          "ASIN"
                          "SQRT"
                          "ACOSH"
                          "BIT-ORC2"
                          "ACOS"
                          "COSH"
                          "SEQUENCE"
                          "RATIONALIZE"
                          "ATANH"
                          "+"
                          "-"
                          "*"
                          "/"
                          "<"
                          ">"
                          "<="
                          ">="
                          "="
                          "/="
                          "MIN"
                          "MAX"
                          "NOT"
                          "AND"
                          "OR"
                          "IDENTITY"
                          "CONSTANTLY"
                          "COMPLEMENT"
                          "APPLY"
                          "REPLACE"
                          "FIRST"
                          "REST"
                          "NTH"
                          "PUSH"
                          "POP"
                          "FIND"
                          "SUBSEQ"
                          "UNION"
                          "INTERSECTION"
                          "SORT"
                          "REVERSE"
                          "LIST"
                          "LIST*"
                          "VECTOR"
                          "MAP"
                          "REDUCE"
                          "REMOVE"
                          "SOME"
                          "EVERY"
                          "THIRD"
                          "SECOND"
                          "LAST"
                          "BUTLAST"
                          "INTERN"
                          "CHAR"
                          "FORMAT"
                          "COMPILE-FILE"
                          "MACROEXPAND-1"
                          "MACROEXPAND"
                          "DEFMACRO"
                          "DEFCLASS"
                          "DEFGENERIC"
                          "DEFMETHOD"
                          "LOOP"
                          "QUOTE"
                          "IF"
                          "DO"
                          "COND"
                          "CASE"
                          "WHEN"
                          "DOTIMES"
                          "TIME"
                          "ASSERT"
                          "ASSOC"
                          "DISSOC"
                          "CONJ"
                          "UPDATE"
                          "COUNT"
                          "MERGE"
                          "GET"
                          "PRINT"
                          "PPRINT"
                          "READ"
                          "READ-LINE"
                          "CLOSE"
                          "DELETE-FILE"
                          "ATOM"
                          "MAKE"
                          "NIL?"
                          "INC"
                          "DEC"
                          "RANGE"
                          "REPEAT"
                          "REPEATEDLY"
                          "ITERATE"
                          "ITERATION"
                          "INTERLEAVE"
                          "INTERPOSE"
                          "CYCLE"
                          "CONS"
                          "CONCAT"
                          "INTO"
                          "FILTER"
                          "FILTERV"
                          "MAPV"
                          "PMAP"
                          "MAPCAT"
                          "TAKE"
                          "DROP"
                          "TAKE-WHILE"
                          "DROP-WHILE"
                          "PARTITION"
                          "PARTITION-BY"
                          "GROUP-BY"
                          "DISTINCT"
                          "DEDUPE"
                          "FLATTEN"
                          "ZIPMAP"
                          "REDUCTIONS"
                          "REALIZED?"
                          "DORUN"
                          "DOALL"
                          "RUN!"
                          "RAND-NTH"
                          "VEC"
                          "SEQ"
                          "STR"
                          "SUBS"
                          "SPLIT"
                          "JOIN"
                          "TRIM"
                          "UPPER-CASE"
                          "LOWER-CASE"
                          "CAPITALIZE"
                          "CONTAINS?"
                          "EMPTY?"
                          "EVERY?"
                          "DISTINCT?"
                          "NOT-EVERY?"
                          "NOT-ANY?"
                          "PERSISTENT-CLASS"
                          "<PERSISTENT-OBJECT>"
                          "TRUTHY?"
                          "PRINTLN"
                          "DICT"
                          "SET"
                          "EXP"
                          "SYMBOL"
                          "KEYWORD")
  (:EXPORT <CART> ADD-ITEM CART-TOTAL SUM-READS RUN-BENCH))

(IN-PACKAGE "DERIVED-VALUE-INVALIDATION")

(DEFCLASS <CART> (<PERSISTENT-OBJECT>)
          ((ITEMS :INITARG :ITEMS :INITFORM (VECTOR))
           (_TOTAL :INITARG :_TOTAL :INITFORM NIL))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<CART> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT (LOAD-TIME-VALUE (FIND-CLASS '<CART>))
                     . #1#))

'<CART>

(DEFMETHOD ASSOC :AROUND (CART SLOT VAL &REST #1=#:REST239)
  (DECLARE (IGNORE #1#))
  (COND
   ((COMMON-LISP:AND (TYPEP CART '<CART>) (= SLOT :ITEMS))
    (ASSOC (CALL-NEXT-METHOD) :_TOTAL NIL))
   (T (CALL-NEXT-METHOD))))

(DEFUN ADD-ITEM (CART PRICE) (ASSOC CART :ITEMS (CONJ (GET CART :ITEMS) PRICE)))

(DEFUN CART-TOTAL (CART)
  (IF (TRUTHY? (NIL? (GET CART :_TOTAL)))
      (REDUCE #'+ 0 (GET CART :ITEMS))
      (GET CART :_TOTAL)))

(DEFUN SUM-READS (CART N-READS)
  (BLOCK LOOP-BLOCK-3
    (LET ((J 0) (S 0))
      (TAGBODY
       LOOP-3
        (LET ((RESULT-3
               (PROGN
                (IF (TRUTHY? (< J N-READS))
                    (PROGN
                     (PSETQ J (INC J)
                            S (+ S (CART-TOTAL CART)))
                     (GO LOOP-3))
                    S))))
          (RETURN-FROM LOOP-BLOCK-3 RESULT-3))))))

(DEFUN RUN-BENCH (N-ITEMS READS-PER-ITEM)
  (BLOCK LOOP-BLOCK-4
    (LET ((I 0) (CART (MAKE '<CART>)) (TOTAL 0))
      (TAGBODY
       LOOP-4
        (LET ((RESULT-4
               (PROGN
                (IF (TRUTHY? (< I N-ITEMS))
                    (LET ((C1 (ADD-ITEM CART I)))
                      (LET ((T1 (CART-TOTAL C1)))
                        (LET ((C2 (ASSOC C1 :_TOTAL T1)))
                          (LET ((READS (SUM-READS C2 READS-PER-ITEM)))
                            (PROGN
                             (PSETQ I (INC I)
                                    CART C2
                                    TOTAL (+ TOTAL READS))
                             (GO LOOP-4))))))
                    TOTAL))))
          (RETURN-FROM LOOP-BLOCK-4 RESULT-4))))))
