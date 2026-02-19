;;; Transpiled from compliance.fol by FOL compiler

;;; This file was automatically generated. Do not edit directly.

(DEFPACKAGE "compliance"
  (:USE :FOL.CORE :CL)
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
  (:EXPORT <TRADE>
           VALIDATE-TRADE
           TRADE-SYMBOL
           TRADE-AMOUNT
           TRADE-PRICE
           TRADE-SIDE))

(IN-PACKAGE "compliance")

(PROGN
 (DEFCLASS <TRADE> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
           ((SYMBOL :INITARG :SYMBOL) (AMOUNT :INITARG :AMOUNT)
            (PRICE :INITARG :PRICE) (SIDE :INITARG :SIDE))
           (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))
 (DEFUN TRADE-SYMBOL #1=(FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    #2=(FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE . #1#) :SYMBOL))
 (DEFUN TRADE-AMOUNT #1# (SYCAMORE:HASH-MAP-FIND #2# :AMOUNT))
 (DEFUN TRADE-PRICE #1# (SYCAMORE:HASH-MAP-FIND #2# :PRICE))
 (DEFUN TRADE-SIDE #1# (SYCAMORE:HASH-MAP-FIND #2# :SIDE))
 (DEFUN MAKE-<TRADE> (&KEY SYMBOL AMOUNT PRICE SIDE)
   (MAKE-INSTANCE '<TRADE> :SYMBOL SYMBOL :AMOUNT AMOUNT :PRICE PRICE :SIDE
                  SIDE))
 '<TRADE>)

(DEFUN TRADE-TOTAL-PRICE (TRADE)
  (*
   (IF (FBOUNDP 'TRADE-PRICE)
       (TRADE-PRICE . #1=(TRADE))
       (LET ((#2=#:VAL271 TRADE-PRICE))
         (COND
          ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
           (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
          ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
          ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
           (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
          (T (ERROR #6="~S is not a function or collection" 'TRADE-PRICE)))))
   (IF (FBOUNDP 'TRADE-AMOUNT)
       (TRADE-AMOUNT . #7=(TRADE))
       (LET ((#8=#:VAL272 TRADE-AMOUNT))
         (COND ((TYPEP #8# . #3#) (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
               ((TYPEP #8# . #4#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
               ((TYPEP #8# . #5#) (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
               (T (ERROR #6# 'TRADE-AMOUNT)))))))

(DEFUN RESTRICTED-SYMBOL? #1=(A0)
  (COND
   ((FOL.COMPILER.COLLECTIONS:GET
     (FOL.COMPILER.COLLECTION-FUNCTIONS:SET 'META 'GOOG 'MSFT 'AMZN)
     (IF (FBOUNDP 'TRADE-SYMBOL)
         (TRADE-SYMBOL . #2=(A0))
         (LET ((#3=#:VAL273 TRADE-SYMBOL))
           (COND
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            (T (ERROR "~S is not a function or collection" 'TRADE-SYMBOL))))))
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T (ERROR "No matching fn clause for arguments: ~S" (LIST . #1#)))))

(DEFUN HIGH-VALUE? #1=(A0)
  (COND
   ((>
     (IF (FBOUNDP 'TRADE-TOTAL-PRICE)
         (TRADE-TOTAL-PRICE . #2=(A0))
         (LET ((#3=#:VAL274 TRADE-TOTAL-PRICE))
           (COND
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            (T
             (ERROR "~S is not a function or collection"
                    'TRADE-TOTAL-PRICE)))))
     1000000.0)
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T (ERROR "No matching fn clause for arguments: ~S" (LIST . #1#)))))

(DEFUN IS-BUY-SIDE-TRADE? #1=(A0)
  (COND
   ((=
     (IF (FBOUNDP 'TRADE-SIDE)
         (TRADE-SIDE . #2=(A0))
         (LET ((#3=#:VAL275 TRADE-SIDE))
           (COND
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            (T (ERROR "~S is not a function or collection" 'TRADE-SIDE)))))
     :BUY)
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T (ERROR "No matching fn clause for arguments: ~S" (LIST . #1#)))))

(DEFUN IS-PENNY-STOCK? #1=(A0)
  (COND
   ((<
     (IF (FBOUNDP 'TRADE-PRICE)
         (TRADE-PRICE . #2=(A0))
         (LET ((#3=#:VAL276 TRADE-PRICE))
           (COND
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #3# . #2#))
            ((TYPEP #3# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
            (T (ERROR "~S is not a function or collection" 'TRADE-PRICE)))))
     5.0)
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T (ERROR "No matching fn clause for arguments: ~S" (LIST . #1#)))))

(DEFUN PENNY-STOCK-BUY? (TRADE)
  (AND
   (IF (FBOUNDP 'IS-BUY-SIDE-TRADE?)
       (IS-BUY-SIDE-TRADE? . #1=(TRADE))
       (LET ((#2=#:VAL277 IS-BUY-SIDE-TRADE?))
         (COND
          ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
           (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
          ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
          ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
           (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
          (T
           (ERROR #6="~S is not a function or collection"
                  'IS-BUY-SIDE-TRADE?)))))
   (IF (FBOUNDP 'IS-PENNY-STOCK?)
       (IS-PENNY-STOCK? . #7=(TRADE))
       (LET ((#8=#:VAL278 IS-PENNY-STOCK?))
         (COND ((TYPEP #8# . #3#) (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
               ((TYPEP #8# . #4#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
               ((TYPEP #8# . #5#) (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
               (T (ERROR #6# 'IS-PENNY-STOCK?)))))))

(DEFGENERIC VALIDATE-TRADE
    (TRADE))

(DEFUN VALIDATE-TRADE #1=(TRD)
  (COND
   ((RESTRICTED-SYMBOL? TRD)
    (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR :STATUS :REJECTED :REASON
                                              (IF (FBOUNDP 'STR)
                                                  (STR
                                                   . #2=("Symbol "
                                                         (IF (FBOUNDP
                                                              'TRADE-SYMBOL)
                                                             (TRADE-SYMBOL
                                                              . #3=(TRD))
                                                             (LET ((#4=#:VAL279
                                                                    TRADE-SYMBOL))
                                                               (COND
                                                                ((TYPEP #4#
                                                                        . #5=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                                 (FOL.COMPILER.COLLECTIONS:GET
                                                                  #4# . #3#))
                                                                ((TYPEP #4#
                                                                        . #6=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                  #4# . #3#))
                                                                ((TYPEP #4#
                                                                        . #7=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                                 (FOL.COMPILER.COLLECTIONS:GET
                                                                  #4# . #3#))
                                                                (T
                                                                 (ERROR
                                                                  #8="~S is not a function or collection"
                                                                  'TRADE-SYMBOL)))))
                                                         " is on the restricted list"))
                                                  (LET ((#9=#:VAL280 STR))
                                                    (COND
                                                     ((TYPEP #9# . #5#)
                                                      (FOL.COMPILER.COLLECTIONS:GET
                                                       #9# . #2#))
                                                     ((TYPEP #9# . #6#)
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                       #9# . #2#))
                                                     ((TYPEP #9# . #7#)
                                                      (FOL.COMPILER.COLLECTIONS:GET
                                                       #9# . #2#))
                                                     (T (ERROR #8# 'STR)))))))
   ((HIGH-VALUE? TRD)
    (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR :STATUS :MANUAL-REVIEW :REASON
                                              "Trade value exceeds $1M limit"))
   ((PENNY-STOCK-BUY? TRD)
    (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR :STATUS :WARNING :REASON
                                              "High risk penny stock purchase"
                                              :TRADE TRD))
   (T
    (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR :STATUS :APPROVED :ID
                                              (GENSYM "TRD")))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S"
           'VALIDATE-TRADE (LIST . #1#)))))

(IN-PACKAGE :FOL.CORE)

(DEFPACKAGE "test-compliance"
  (:USE "compliance" :FOL.CORE :CL)
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
                          "SYMBOL"))

(IN-PACKAGE "test-compliance")

(DEFUN COMPLIANCE ()
  (DECLARE (SPECIAL T1 T2 T3 T4))
  (DEFVAR T1
    (IF (FBOUNDP 'MAKE)
        (MAKE . #1=('<TRADE> :SYMBOL 'NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY))
        (LET ((#2=#:VAL281 MAKE))
          (COND
           ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
            (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
           ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
           ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
            (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
           (T (ERROR #6="~S is not a function or collection" 'MAKE))))))
  (DEFVAR T2
    (IF (FBOUNDP 'MAKE)
        (MAKE
         . #7=('<TRADE> :SYMBOL 'GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL))
        (LET ((#8=#:VAL282 MAKE))
          (COND ((TYPEP #8# . #3#) (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                ((TYPEP #8# . #4#)
                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
                ((TYPEP #8# . #5#) (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                (T (ERROR #6# 'MAKE))))))
  (DEFVAR T3
    (IF (FBOUNDP 'MAKE)
        (MAKE
         . #9=('<TRADE> :SYMBOL 'IBM :AMOUNT 10000 :PRICE 150.0 :SIDE :BUY))
        (LET ((#10=#:VAL283 MAKE))
          (COND ((TYPEP #10# . #3#) (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                ((TYPEP #10# . #4#)
                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #10# . #9#))
                ((TYPEP #10# . #5#) (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                (T (ERROR #6# 'MAKE))))))
  (DEFVAR T4
    (IF (FBOUNDP 'MAKE)
        (MAKE . #11=('<TRADE> :SYMBOL 'F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY))
        (LET ((#12=#:VAL284 MAKE))
          (COND ((TYPEP #12# . #3#) (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                ((TYPEP #12# . #4#)
                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #12# . #11#))
                ((TYPEP #12# . #5#) (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                (T (ERROR #6# 'MAKE))))))
  (PRINT
   (IF (FBOUNDP 'STR)
       (STR
        . #13=("T1: "
               (IF (FBOUNDP 'VALIDATE-TRADE)
                   (VALIDATE-TRADE . #14=(T1))
                   (LET ((#15=#:VAL285 VALIDATE-TRADE))
                     (COND
                      ((TYPEP #15# . #3#)
                       (FOL.COMPILER.COLLECTIONS:GET #15# . #14#))
                      ((TYPEP #15# . #4#)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #15# . #14#))
                      ((TYPEP #15# . #5#)
                       (FOL.COMPILER.COLLECTIONS:GET #15# . #14#))
                      (T (ERROR #6# 'VALIDATE-TRADE)))))))
       (LET ((#16=#:VAL286 STR))
         (COND ((TYPEP #16# . #3#) (FOL.COMPILER.COLLECTIONS:GET #16# . #13#))
               ((TYPEP #16# . #4#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #16# . #13#))
               ((TYPEP #16# . #5#) (FOL.COMPILER.COLLECTIONS:GET #16# . #13#))
               (T (ERROR #6# 'STR))))))
  (PRINT
   (IF (FBOUNDP 'STR)
       (STR
        . #17=("T2: "
               (IF (FBOUNDP 'VALIDATE-TRADE)
                   (VALIDATE-TRADE . #18=(T2))
                   (LET ((#19=#:VAL287 VALIDATE-TRADE))
                     (COND
                      ((TYPEP #19# . #3#)
                       (FOL.COMPILER.COLLECTIONS:GET #19# . #18#))
                      ((TYPEP #19# . #4#)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #19# . #18#))
                      ((TYPEP #19# . #5#)
                       (FOL.COMPILER.COLLECTIONS:GET #19# . #18#))
                      (T (ERROR #6# 'VALIDATE-TRADE)))))))
       (LET ((#20=#:VAL288 STR))
         (COND ((TYPEP #20# . #3#) (FOL.COMPILER.COLLECTIONS:GET #20# . #17#))
               ((TYPEP #20# . #4#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #20# . #17#))
               ((TYPEP #20# . #5#) (FOL.COMPILER.COLLECTIONS:GET #20# . #17#))
               (T (ERROR #6# 'STR))))))
  (PRINT
   (IF (FBOUNDP 'STR)
       (STR
        . #21=("T3: "
               (IF (FBOUNDP 'VALIDATE-TRADE)
                   (VALIDATE-TRADE . #22=(T3))
                   (LET ((#23=#:VAL289 VALIDATE-TRADE))
                     (COND
                      ((TYPEP #23# . #3#)
                       (FOL.COMPILER.COLLECTIONS:GET #23# . #22#))
                      ((TYPEP #23# . #4#)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #23# . #22#))
                      ((TYPEP #23# . #5#)
                       (FOL.COMPILER.COLLECTIONS:GET #23# . #22#))
                      (T (ERROR #6# 'VALIDATE-TRADE)))))))
       (LET ((#24=#:VAL290 STR))
         (COND ((TYPEP #24# . #3#) (FOL.COMPILER.COLLECTIONS:GET #24# . #21#))
               ((TYPEP #24# . #4#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #24# . #21#))
               ((TYPEP #24# . #5#) (FOL.COMPILER.COLLECTIONS:GET #24# . #21#))
               (T (ERROR #6# 'STR))))))
  (PRINT
   (IF (FBOUNDP 'STR)
       (STR
        . #25=("T4: "
               (IF (FBOUNDP 'VALIDATE-TRADE)
                   (VALIDATE-TRADE . #26=(T4))
                   (LET ((#27=#:VAL291 VALIDATE-TRADE))
                     (COND
                      ((TYPEP #27# . #3#)
                       (FOL.COMPILER.COLLECTIONS:GET #27# . #26#))
                      ((TYPEP #27# . #4#)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #27# . #26#))
                      ((TYPEP #27# . #5#)
                       (FOL.COMPILER.COLLECTIONS:GET #27# . #26#))
                      (T (ERROR #6# 'VALIDATE-TRADE)))))))
       (LET ((#28=#:VAL292 STR))
         (COND ((TYPEP #28# . #3#) (FOL.COMPILER.COLLECTIONS:GET #28# . #25#))
               ((TYPEP #28# . #4#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #28# . #25#))
               ((TYPEP #28# . #5#) (FOL.COMPILER.COLLECTIONS:GET #28# . #25#))
               (T (ERROR #6# 'STR)))))))

(IN-PACKAGE :FOL.CORE)

;; (TEST-COMPLIANCE::COMPLIANCE)

