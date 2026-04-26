;;; Transpiled from compliance.fol
(in-package :fol.core)

(DEFPACKAGE "COMPLIANCE"
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
  (:EXPORT <TRADE>
           VALIDATE-TRADE
           TRADE-SYMBOL
           TRADE-AMOUNT
           TRADE-PRICE
           TRADE-SIDE))

(IN-PACKAGE "COMPLIANCE")

(DEFCLASS <TRADE> (<PERSISTENT-OBJECT>)
          ((SYMBOL :INITARG :SYMBOL) (AMOUNT :INITARG :AMOUNT)
           (PRICE :INITARG :PRICE) (SIDE :INITARG :SIDE))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN TRADE-SYMBOL (FOL.COMPILER::OBJECT) (GET FOL.COMPILER::OBJECT :SYMBOL))

(DEFUN TRADE-AMOUNT (FOL.COMPILER::OBJECT) (GET FOL.COMPILER::OBJECT :AMOUNT))

(DEFUN TRADE-PRICE (FOL.COMPILER::OBJECT) (GET FOL.COMPILER::OBJECT :PRICE))

(DEFUN TRADE-SIDE (FOL.COMPILER::OBJECT) (GET FOL.COMPILER::OBJECT :SIDE))

(DEFUN FOL.CORE::MAKE-<TRADE> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT (LOAD-TIME-VALUE (FIND-CLASS '<TRADE>))
                     . #1#))

'<TRADE>

(DEFUN TRADE-TOTAL-PRICE (TRADE)
  (DECLARE (SPECIAL TRADE-AMOUNT TRADE-PRICE))
  (*
   (IF (FBOUNDP 'TRADE-PRICE)
       (TRADE-PRICE . #1=(TRADE))
       (LET ((#2=#:VAL447 TRADE-PRICE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
               ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
               ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
               (T
                (ERROR #6="~S is not a function or collection"
                       'TRADE-PRICE)))))
   (IF (FBOUNDP 'TRADE-AMOUNT)
       (TRADE-AMOUNT . #7=(TRADE))
       (LET ((#8=#:VAL448 TRADE-AMOUNT))
         (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
               ((TYPEP #8# . #3#) (GET #8# . #7#))
               ((TYPEP #8# . #4#) (NTH #8# . #7#))
               ((TYPEP #8# . #5#) (GET #8# . #7#))
               (T (ERROR #6# 'TRADE-AMOUNT)))))))

(DEFUN RESTRICTED-SYMBOL? (TRADE)
  (DECLARE (SPECIAL TRADE-SYMBOL))
  (CONTAINS? (SET :AMZN :MSFT :GOOG :META)
             (IF (FBOUNDP 'TRADE-SYMBOL)
                 (TRADE-SYMBOL . #1=(TRADE))
                 (LET ((#2=#:VAL449 TRADE-SYMBOL))
                   (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                         ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                         ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                         ((TYPEP #2# '<SET>) (GET #2# . #1#))
                         (T
                          (ERROR "~S is not a function or collection"
                                 'TRADE-SYMBOL)))))))

(DEFUN HIGH-VALUE? (TRADE) (> (TRADE-TOTAL-PRICE TRADE) 1000000.0))

(DEFUN IS-BUY-SIDE-TRADE? (TRADE)
  (DECLARE (SPECIAL TRADE-SIDE))
  (=
   (IF (FBOUNDP 'TRADE-SIDE)
       (TRADE-SIDE . #1=(TRADE))
       (LET ((#2=#:VAL450 TRADE-SIDE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# '<DICT>) (GET #2# . #1#))
               ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
               ((TYPEP #2# '<SET>) (GET #2# . #1#))
               (T (ERROR "~S is not a function or collection" 'TRADE-SIDE)))))
   :BUY))

(DEFUN IS-PENNY-STOCK? (TRADE)
  (DECLARE (SPECIAL TRADE-PRICE))
  (<
   (IF (FBOUNDP 'TRADE-PRICE)
       (TRADE-PRICE . #1=(TRADE))
       (LET ((#2=#:VAL451 TRADE-PRICE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# '<DICT>) (GET #2# . #1#))
               ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
               ((TYPEP #2# '<SET>) (GET #2# . #1#))
               (T (ERROR "~S is not a function or collection" 'TRADE-PRICE)))))
   5.0))

(DEFUN PENNY-STOCK-BUY? (TRADE)
  (AND (IS-BUY-SIDE-TRADE? TRADE) (IS-PENNY-STOCK? TRADE)))

(DEFUN VALIDATE-TRADE (TRD)
  (DECLARE (SPECIAL TRADE-SYMBOL))
  (IF (TRUTHY? (RESTRICTED-SYMBOL? TRD))
      (DICT :REASON
            (STR "Symbol "
                 (IF (FBOUNDP 'TRADE-SYMBOL)
                     (TRADE-SYMBOL . #1=(TRD))
                     (LET ((#2=#:VAL452 TRADE-SYMBOL))
                       (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                             ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                             ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                             ((TYPEP #2# '<SET>) (GET #2# . #1#))
                             (T
                              (ERROR "~S is not a function or collection"
                                     'TRADE-SYMBOL)))))
                 " is on the restricted list")
            :STATUS :REJECTED)
      (IF (TRUTHY? (HIGH-VALUE? TRD))
          (DICT :REASON "Trade value exceeds $1M limit" :STATUS :MANUAL-REVIEW)
          (IF (TRUTHY? (PENNY-STOCK-BUY? TRD))
              (DICT :TRADE TRD :REASON "High risk penny stock purchase" :STATUS
                    :WARNING)
              (IF (TRUTHY? :ELSE)
                  (DICT :ID (GENSYM "TRD") :STATUS :APPROVED)
                  NIL)))))

(DEFPACKAGE "TEST-COMPLIANCE"
  (:USE "COMPLIANCE" "FOL.CORE" "CL")
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
                          "KEYWORD"))

(IN-PACKAGE "TEST-COMPLIANCE")

(DEFUN COMPLIANCE ()
  (LET ((T1 (MAKE '<TRADE> :SYMBOL :NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY)))
    (LET ((T2
           (MAKE '<TRADE> :SYMBOL :GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL)))
      (LET ((T3
             (MAKE '<TRADE> :SYMBOL :IBM :AMOUNT 10000 :PRICE 150.0 :SIDE
                   :BUY)))
        (LET ((T4
               (MAKE '<TRADE> :SYMBOL :F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY)))
          (PROGN
           (PRINTLN (STR "T1: " (VALIDATE-TRADE T1)))
           (PRINTLN (STR "T2: " (VALIDATE-TRADE T2)))
           (PRINTLN (STR "T3: " (VALIDATE-TRADE T3)))
           (PRINTLN (STR "T4: " (VALIDATE-TRADE T4)))))))))

(DEFUN RUN-BENCH ()
  (LET ((T1 (MAKE '<TRADE> :SYMBOL :NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY)))
    (LET ((T2
           (MAKE '<TRADE> :SYMBOL :GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL)))
      (LET ((T3
             (MAKE '<TRADE> :SYMBOL :IBM :AMOUNT 10000 :PRICE 150.0 :SIDE
                   :BUY)))
        (LET ((T4
               (MAKE '<TRADE> :SYMBOL :F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY)))
          (BLOCK LOOP-BLOCK-2
            (LET ((I 0))
              (TAGBODY
               LOOP-2
                (LET ((RESULT-2
                       (PROGN
                        (IF (TRUTHY? (< I 1000))
                            (PROGN
                             (VALIDATE-TRADE T1)
                             (VALIDATE-TRADE T2)
                             (VALIDATE-TRADE T3)
                             (VALIDATE-TRADE T4)
                             (PROGN (PSETQ I (+ I 1)) (GO LOOP-2)))
                            NIL))))
                  (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))))))
