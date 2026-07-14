;;; Transpiled from derived-value-invalidation.fol
(in-package :fol.core)

(DEFPACKAGE "DERIVED-VALUE-INVALIDATION"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
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

(DEFCLASS <CART> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((ITEMS :INITARG :ITEMS :INITFORM
            (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR))
           (_TOTAL :INITARG :_TOTAL :INITFORM NIL))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<CART> (&KEY (ITEMS . #1=(NIL)) (_TOTAL . #1#))
  (LET ((FOL.COMPILER::OBJ
         (ALLOCATE-INSTANCE (LOAD-TIME-VALUE (FIND-CLASS '<CART>)))))
    (LET ((FOL.COMPILER.PERSISTENT::*INITIALIZING-PERSISTENT-OBJECT* T))
      (SETF (SLOT-VALUE FOL.COMPILER::OBJ 'ITEMS) ITEMS)
      (SETF (SLOT-VALUE FOL.COMPILER::OBJ '_TOTAL) _TOTAL)
      (SETF (FOL.COMPILER.PERSISTENT::%TRANSIENT-OWNER
             . #2=(FOL.COMPILER::OBJ))
              . #1#)
      (SETF (FOL.COMPILER.PERSISTENT::%SCHEMA-VERSION . #2#)
              (FOL.COMPILER.PERSISTENT::PERSISTENT-CLASS-VERSION-COUNTER
               (CLASS-OF . #2#))))
    . #2#))

'<CART>

(FOL.COMPILER.SUMMARIES:CLEAR-INFERRED-SUMMARY 'ASSOC)

(PROG1
    (DEFMETHOD ASSOC :AROUND ((CART <CART>) SLOT VAL &REST #1=#:REST237)
      (DECLARE (IGNORE #1#))
      (COND
       ((= SLOT :ITEMS)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:ASSOC (CALL-NEXT-METHOD) :_TOTAL
                                                 NIL))
       (T (CALL-NEXT-METHOD))))
  (FOL.COMPILER.WORLD:NOTE-REDEFINITION 'ASSOC))

(FOL.COMPILER.SUMMARIES:CLEAR-INFERRED-SUMMARY 'ADD-ITEM)

(PROG1
    (DEFUN ADD-ITEM (CART PRICE)
      (FOL.COMPILER.COLLECTION-FUNCTIONS:ASSOC CART :ITEMS
                                               (CONJ
                                                (FOL.COMPILER.COLLECTIONS:GET
                                                 CART :ITEMS)
                                                PRICE)))
  (FOL.COMPILER.WORLD:NOTE-REDEFINITION 'ADD-ITEM))

(FOL.COMPILER.SUMMARIES:CLEAR-INFERRED-SUMMARY 'CART-TOTAL)

(PROG1
    (DEFUN CART-TOTAL (CART)
      (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
           (NIL? (FOL.COMPILER.COLLECTIONS:GET CART :_TOTAL)))
          (REDUCE #'+ 0 (FOL.COMPILER.COLLECTIONS:GET CART :ITEMS))
          (FOL.COMPILER.COLLECTIONS:GET CART :_TOTAL)))
  (FOL.COMPILER.WORLD:NOTE-REDEFINITION 'CART-TOTAL))

(FOL.COMPILER.SUMMARIES:CLEAR-INFERRED-SUMMARY 'SUM-READS)

(PROG1
    (DEFUN SUM-READS (CART N-READS)
      (BLOCK LOOP-BLOCK-1
        (LET ((J 0) (S 0))
          (TAGBODY
           LOOP-1
            (LET ((RESULT-1
                   (PROGN
                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< J N-READS))
                        (PROGN
                         (PSETQ J (INC J)
                                S (+ S (CART-TOTAL CART)))
                         (GO LOOP-1))
                        S))))
              (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))
  (FOL.COMPILER.WORLD:NOTE-REDEFINITION 'SUM-READS))

(FOL.COMPILER.SUMMARIES:CLEAR-INFERRED-SUMMARY 'RUN-BENCH)

(PROG1
    (DEFUN RUN-BENCH (N-ITEMS READS-PER-ITEM)
      (BLOCK LOOP-BLOCK-2
        (LET ((I 0) (CART (MAKE '<CART>)) (TOTAL 0))
          (TAGBODY
           LOOP-2
            (LET ((RESULT-2
                   (PROGN
                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< I N-ITEMS))
                        (LET ((C1 (ADD-ITEM CART I)))
                          (LET ((T1 (CART-TOTAL C1)))
                            (LET ((C2
                                   (FOL.COMPILER.COLLECTION-FUNCTIONS:ASSOC C1
                                                                            :_TOTAL
                                                                            T1)))
                              (LET ((READS (SUM-READS C2 READS-PER-ITEM)))
                                (PROGN
                                 (PSETQ I (INC I)
                                        CART C2
                                        TOTAL (+ TOTAL READS))
                                 (GO LOOP-2))))))
                        TOTAL))))
              (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))
  (FOL.COMPILER.WORLD:NOTE-REDEFINITION 'RUN-BENCH))
