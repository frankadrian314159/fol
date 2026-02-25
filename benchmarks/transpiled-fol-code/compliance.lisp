;;; Transpiled from compliance.fol
(in-package :fol.core)

(DEFPACKAGE "COMPLIANCE"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "*"
                          "TIME"
                          "BIT-NAND"
                          "UNION"
                          "MAX"
                          "LCM"
                          "SOME"
                          "DEFCLASS"
                          "SECOND"
                          "GCD"
                          "SORT"
                          ">"
                          "BUTLAST"
                          "<="
                          "DOTIMES"
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
                          "ASINH"
                          "GENSYM"
                          "VECTOR"
                          "="
                          "EXPT"
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
                          "TAN"
                          "INTERN"
                          "EVERY"
                          "FIRST"
                          ">="
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

(DEFUN FOL.CORE::MAKE-<TRADE> (&KEY SYMBOL AMOUNT PRICE SIDE)
  (MAKE-INSTANCE '<TRADE> :SYMBOL SYMBOL :AMOUNT AMOUNT :PRICE PRICE :SIDE
                 SIDE))

'<TRADE>

(DEFUN TRADE-TOTAL-PRICE (TRADE)
  (DECLARE (SPECIAL TRADE-AMOUNT TRADE-PRICE))
  (*
   (IF (FBOUNDP 'TRADE-PRICE)
       (TRADE-PRICE . #1=(TRADE))
       (LET ((#2=#:VAL371 TRADE-PRICE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
               ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
               ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
               (T
                (ERROR #6="~S is not a function or collection"
                       'TRADE-PRICE)))))
   (IF (FBOUNDP 'TRADE-AMOUNT)
       (TRADE-AMOUNT . #7=(TRADE))
       (LET ((#8=#:VAL372 TRADE-AMOUNT))
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
                 (LET ((#2=#:VAL373 TRADE-SYMBOL))
                   (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                         ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                         ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                         ((TYPEP #2# '<SET>) (GET #2# . #1#))
                         (T
                          (ERROR "~S is not a function or collection"
                                 'TRADE-SYMBOL)))))))

(DEFUN HIGH-VALUE? (TRADE)
  (DECLARE (SPECIAL TRADE-TOTAL-PRICE))
  (>
   (IF (FBOUNDP 'TRADE-TOTAL-PRICE)
       (TRADE-TOTAL-PRICE . #1=(TRADE))
       (LET ((#2=#:VAL374 TRADE-TOTAL-PRICE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# '<DICT>) (GET #2# . #1#))
               ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
               ((TYPEP #2# '<SET>) (GET #2# . #1#))
               (T
                (ERROR "~S is not a function or collection"
                       'TRADE-TOTAL-PRICE)))))
   1000000.0))

(DEFUN IS-BUY-SIDE-TRADE? (TRADE)
  (DECLARE (SPECIAL TRADE-SIDE))
  (=
   (IF (FBOUNDP 'TRADE-SIDE)
       (TRADE-SIDE . #1=(TRADE))
       (LET ((#2=#:VAL375 TRADE-SIDE))
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
       (LET ((#2=#:VAL376 TRADE-PRICE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# '<DICT>) (GET #2# . #1#))
               ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
               ((TYPEP #2# '<SET>) (GET #2# . #1#))
               (T (ERROR "~S is not a function or collection" 'TRADE-PRICE)))))
   5.0))

(DEFUN PENNY-STOCK-BUY? (TRADE)
  (DECLARE (SPECIAL IS-PENNY-STOCK? IS-BUY-SIDE-TRADE?))
  (AND
   (IF (FBOUNDP 'IS-BUY-SIDE-TRADE?)
       (IS-BUY-SIDE-TRADE? . #1=(TRADE))
       (LET ((#2=#:VAL377 IS-BUY-SIDE-TRADE?))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
               ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
               ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
               (T
                (ERROR #6="~S is not a function or collection"
                       'IS-BUY-SIDE-TRADE?)))))
   (IF (FBOUNDP 'IS-PENNY-STOCK?)
       (IS-PENNY-STOCK? . #7=(TRADE))
       (LET ((#8=#:VAL378 IS-PENNY-STOCK?))
         (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
               ((TYPEP #8# . #3#) (GET #8# . #7#))
               ((TYPEP #8# . #4#) (NTH #8# . #7#))
               ((TYPEP #8# . #5#) (GET #8# . #7#))
               (T (ERROR #6# 'IS-PENNY-STOCK?)))))))

(DEFUN VALIDATE-TRADE (TRD)
  (DECLARE
   (SPECIAL PENNY-STOCK-BUY? HIGH-VALUE? TRADE-SYMBOL RESTRICTED-SYMBOL?))
  (IF (TRUTHY?
       (IF (FBOUNDP 'RESTRICTED-SYMBOL?)
           (RESTRICTED-SYMBOL? . #1=(TRD))
           (LET ((#2=#:VAL379 RESTRICTED-SYMBOL?))
             (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                   ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                   ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                   ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                   (T
                    (ERROR #6="~S is not a function or collection"
                           'RESTRICTED-SYMBOL?))))))
      (MAKE '<LIST> :STATUS :REJECTED :REASON
            (STR "Symbol "
                 (IF (FBOUNDP 'TRADE-SYMBOL)
                     (TRADE-SYMBOL . #7=(TRD))
                     (LET ((#8=#:VAL380 TRADE-SYMBOL))
                       (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                             ((TYPEP #8# . #3#) (GET #8# . #7#))
                             ((TYPEP #8# . #4#) (NTH #8# . #7#))
                             ((TYPEP #8# . #5#) (GET #8# . #7#))
                             (T (ERROR #6# 'TRADE-SYMBOL)))))
                 " is on the restricted list"))
      (IF (TRUTHY?
           (IF (FBOUNDP 'HIGH-VALUE?)
               (HIGH-VALUE? . #9=(TRD))
               (LET ((#10=#:VAL381 HIGH-VALUE?))
                 (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                       ((TYPEP #10# . #3#) (GET #10# . #9#))
                       ((TYPEP #10# . #4#) (NTH #10# . #9#))
                       ((TYPEP #10# . #5#) (GET #10# . #9#))
                       (T (ERROR #6# 'HIGH-VALUE?))))))
          (MAKE '<LIST> :STATUS :MANUAL-REVIEW :REASON
                "Trade value exceeds $1M limit")
          (IF (TRUTHY?
               (IF (FBOUNDP 'PENNY-STOCK-BUY?)
                   (PENNY-STOCK-BUY? . #11=(TRD))
                   (LET ((#12=#:VAL382 PENNY-STOCK-BUY?))
                     (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                           ((TYPEP #12# . #3#) (GET #12# . #11#))
                           ((TYPEP #12# . #4#) (NTH #12# . #11#))
                           ((TYPEP #12# . #5#) (GET #12# . #11#))
                           (T (ERROR #6# 'PENNY-STOCK-BUY?))))))
              (MAKE '<LIST> :STATUS :WARNING :REASON
                    "High risk penny stock purchase" :TRADE TRD)
              (IF (TRUTHY? :ELSE)
                  (MAKE '<LIST> :STATUS :APPROVED :ID (GENSYM "TRD"))
                  NIL)))))

(DEFPACKAGE "TEST-COMPLIANCE"
  (:USE "COMPLIANCE" "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "*"
                          "TIME"
                          "BIT-NAND"
                          "UNION"
                          "MAX"
                          "LCM"
                          "SOME"
                          "DEFCLASS"
                          "SECOND"
                          "GCD"
                          "SORT"
                          ">"
                          "BUTLAST"
                          "<="
                          "DOTIMES"
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
                          "ASINH"
                          "GENSYM"
                          "VECTOR"
                          "="
                          "EXPT"
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
                          "TAN"
                          "INTERN"
                          "EVERY"
                          "FIRST"
                          ">="
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
                          "SYMBOL"))

(IN-PACKAGE "TEST-COMPLIANCE")

(DEFUN COMPLIANCE ()
  (DECLARE (SPECIAL VALIDATE-TRADE))
  (LET ((T1 (MAKE '<TRADE> :SYMBOL :NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY)))
    (LET ((T2
           (MAKE '<TRADE> :SYMBOL :GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL)))
      (LET ((T3
             (MAKE '<TRADE> :SYMBOL :IBM :AMOUNT 10000 :PRICE 150.0 :SIDE
                   :BUY)))
        (LET ((T4
               (MAKE '<TRADE> :SYMBOL :F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY)))
          (PROGN
           (PRINTLN
            (STR "T1: "
                 (IF (FBOUNDP 'VALIDATE-TRADE)
                     (VALIDATE-TRADE . #1=(T1))
                     (LET ((#2=#:VAL383 VALIDATE-TRADE))
                       (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                             ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                             ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                             ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                             (T
                              (ERROR #6="~S is not a function or collection"
                                     'VALIDATE-TRADE)))))))
           (PRINTLN
            (STR "T2: "
                 (IF (FBOUNDP 'VALIDATE-TRADE)
                     (VALIDATE-TRADE . #7=(T2))
                     (LET ((#8=#:VAL384 VALIDATE-TRADE))
                       (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                             ((TYPEP #8# . #3#) (GET #8# . #7#))
                             ((TYPEP #8# . #4#) (NTH #8# . #7#))
                             ((TYPEP #8# . #5#) (GET #8# . #7#))
                             (T (ERROR #6# 'VALIDATE-TRADE)))))))
           (PRINTLN
            (STR "T3: "
                 (IF (FBOUNDP 'VALIDATE-TRADE)
                     (VALIDATE-TRADE . #9=(T3))
                     (LET ((#10=#:VAL385 VALIDATE-TRADE))
                       (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                             ((TYPEP #10# . #3#) (GET #10# . #9#))
                             ((TYPEP #10# . #4#) (NTH #10# . #9#))
                             ((TYPEP #10# . #5#) (GET #10# . #9#))
                             (T (ERROR #6# 'VALIDATE-TRADE)))))))
           (PRINTLN
            (STR "T4: "
                 (IF (FBOUNDP 'VALIDATE-TRADE)
                     (VALIDATE-TRADE . #11=(T4))
                     (LET ((#12=#:VAL386 VALIDATE-TRADE))
                       (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                             ((TYPEP #12# . #3#) (GET #12# . #11#))
                             ((TYPEP #12# . #4#) (NTH #12# . #11#))
                             ((TYPEP #12# . #5#) (GET #12# . #11#))
                             (T (ERROR #6# 'VALIDATE-TRADE)))))))))))))

(DEFUN RUN-BENCH ()
  (DECLARE (SPECIAL VALIDATE-TRADE))
  (LET ((T1 (MAKE '<TRADE> :SYMBOL :NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY)))
    (LET ((T2
           (MAKE '<TRADE> :SYMBOL :GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL)))
      (LET ((T3
             (MAKE '<TRADE> :SYMBOL :IBM :AMOUNT 10000 :PRICE 150.0 :SIDE
                   :BUY)))
        (LET ((T4
               (MAKE '<TRADE> :SYMBOL :F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY)))
          (BLOCK LOOP-BLOCK-1
            (LET ((I 0))
              (TAGBODY
               LOOP-1
                (LET ((RESULT-1
                       (PROGN
                        (IF (TRUTHY? (< I 1000))
                            (PROGN
                             (IF (FBOUNDP 'VALIDATE-TRADE)
                                 (VALIDATE-TRADE . #1=(T1))
                                 (LET ((#2=#:VAL387 VALIDATE-TRADE))
                                   (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                         ((TYPEP #2# . #3=('<DICT>))
                                          (GET #2# . #1#))
                                         ((TYPEP #2# . #4=('<VECTOR>))
                                          (NTH #2# . #1#))
                                         ((TYPEP #2# . #5=('<SET>))
                                          (GET #2# . #1#))
                                         (T
                                          (ERROR
                                           #6="~S is not a function or collection"
                                           'VALIDATE-TRADE)))))
                             (IF (FBOUNDP 'VALIDATE-TRADE)
                                 (VALIDATE-TRADE . #7=(T2))
                                 (LET ((#8=#:VAL388 VALIDATE-TRADE))
                                   (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                                         ((TYPEP #8# . #3#) (GET #8# . #7#))
                                         ((TYPEP #8# . #4#) (NTH #8# . #7#))
                                         ((TYPEP #8# . #5#) (GET #8# . #7#))
                                         (T (ERROR #6# 'VALIDATE-TRADE)))))
                             (IF (FBOUNDP 'VALIDATE-TRADE)
                                 (VALIDATE-TRADE . #9=(T3))
                                 (LET ((#10=#:VAL389 VALIDATE-TRADE))
                                   (COND
                                    ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                                    ((TYPEP #10# . #3#) (GET #10# . #9#))
                                    ((TYPEP #10# . #4#) (NTH #10# . #9#))
                                    ((TYPEP #10# . #5#) (GET #10# . #9#))
                                    (T (ERROR #6# 'VALIDATE-TRADE)))))
                             (IF (FBOUNDP 'VALIDATE-TRADE)
                                 (VALIDATE-TRADE . #11=(T4))
                                 (LET ((#12=#:VAL390 VALIDATE-TRADE))
                                   (COND
                                    ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                                    ((TYPEP #12# . #3#) (GET #12# . #11#))
                                    ((TYPEP #12# . #4#) (NTH #12# . #11#))
                                    ((TYPEP #12# . #5#) (GET #12# . #11#))
                                    (T (ERROR #6# 'VALIDATE-TRADE)))))
                             (PROGN (PSETQ I (+ I 1)) (GO LOOP-1)))
                            NIL))))
                  (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))))))
