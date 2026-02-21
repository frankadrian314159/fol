;;; Transpiled from compliance.fol
(in-package :fol.core)

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

(DEFCLASS <TRADE> (<PERSISTENT-OBJECT>)
          ((SYMBOL :INITARG :SYMBOL) (AMOUNT :INITARG :AMOUNT)
           (PRICE :INITARG :PRICE) (SIDE :INITARG :SIDE))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN TRADE-SYMBOL #1=(FOL.COMPILER::OBJECT)
  (SYCAMORE:HASH-MAP-FIND (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE . #1#)
                          :SYMBOL))

(DEFUN TRADE-AMOUNT #1=(FOL.COMPILER::OBJECT)
  (SYCAMORE:HASH-MAP-FIND (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE . #1#)
                          :AMOUNT))

(DEFUN TRADE-PRICE #1=(FOL.COMPILER::OBJECT)
  (SYCAMORE:HASH-MAP-FIND (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE . #1#)
                          :PRICE))

(DEFUN TRADE-SIDE #1=(FOL.COMPILER::OBJECT)
  (SYCAMORE:HASH-MAP-FIND (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE . #1#)
                          :SIDE))

(DEFUN MAKE-<TRADE> (&KEY SYMBOL AMOUNT PRICE SIDE)
  (MAKE-INSTANCE '<TRADE> :SYMBOL SYMBOL :AMOUNT AMOUNT :PRICE PRICE :SIDE
                 SIDE))

'<TRADE>

(DEFUN TRADE-TOTAL-PRICE (TRADE)
  (DECLARE (SPECIAL TRADE-AMOUNT TRADE-PRICE))
  (*
   (IF (FBOUNDP 'TRADE-PRICE)
       (TRADE-PRICE . #1=(TRADE))
       (LET ((#2=#:VAL279 TRADE-PRICE))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
               ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
               ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
               (T
                (ERROR #6="~S is not a function or collection"
                       'TRADE-PRICE)))))
   (IF (FBOUNDP 'TRADE-AMOUNT)
       (TRADE-AMOUNT . #7=(TRADE))
       (LET ((#8=#:VAL280 TRADE-AMOUNT))
         (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
               ((TYPEP #8# . #3#) (GET #8# . #7#))
               ((TYPEP #8# . #4#) (NTH #8# . #7#))
               ((TYPEP #8# . #5#) (GET #8# . #7#))
               (T (ERROR #6# 'TRADE-AMOUNT)))))))

(DEFUN RESTRICTED-SYMBOL? #1=(A0)
  (DECLARE (SPECIAL TRADE-SYMBOL A0))
  (COND
   ((GET (SET 'META 'GOOG 'MSFT 'AMZN)
         (IF (FBOUNDP 'TRADE-SYMBOL)
             (TRADE-SYMBOL . #2=(A0))
             (LET ((#3=#:VAL281 TRADE-SYMBOL))
               (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                     ((TYPEP #3# '<DICT>) (GET #3# . #2#))
                     ((TYPEP #3# '<VECTOR>) (NTH #3# . #2#))
                     ((TYPEP #3# '<SET>) (GET #3# . #2#))
                     (T
                      (ERROR "~S is not a function or collection"
                             'TRADE-SYMBOL))))))
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T
    (ERROR "No matching fn clause for arguments: ~S"
           (COMMON-LISP:LIST . #1#)))))

(DEFUN HIGH-VALUE? #1=(A0)
  (DECLARE (SPECIAL TRADE-TOTAL-PRICE A0))
  (COND
   ((>
     (IF (FBOUNDP 'TRADE-TOTAL-PRICE)
         (TRADE-TOTAL-PRICE . #2=(A0))
         (LET ((#3=#:VAL282 TRADE-TOTAL-PRICE))
           (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                 ((TYPEP #3# '<DICT>) (GET #3# . #2#))
                 ((TYPEP #3# '<VECTOR>) (NTH #3# . #2#))
                 ((TYPEP #3# '<SET>) (GET #3# . #2#))
                 (T
                  (ERROR "~S is not a function or collection"
                         'TRADE-TOTAL-PRICE)))))
     1000000.0)
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T
    (ERROR "No matching fn clause for arguments: ~S"
           (COMMON-LISP:LIST . #1#)))))

(DEFUN IS-BUY-SIDE-TRADE? #1=(A0)
  (DECLARE (SPECIAL TRADE-SIDE A0))
  (COND
   ((=
     (IF (FBOUNDP 'TRADE-SIDE)
         (TRADE-SIDE . #2=(A0))
         (LET ((#3=#:VAL283 TRADE-SIDE))
           (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                 ((TYPEP #3# '<DICT>) (GET #3# . #2#))
                 ((TYPEP #3# '<VECTOR>) (NTH #3# . #2#))
                 ((TYPEP #3# '<SET>) (GET #3# . #2#))
                 (T
                  (ERROR "~S is not a function or collection" 'TRADE-SIDE)))))
     :BUY)
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T
    (ERROR "No matching fn clause for arguments: ~S"
           (COMMON-LISP:LIST . #1#)))))

(DEFUN IS-PENNY-STOCK? #1=(A0)
  (DECLARE (SPECIAL TRADE-PRICE A0))
  (COND
   ((<
     (IF (FBOUNDP 'TRADE-PRICE)
         (TRADE-PRICE . #2=(A0))
         (LET ((#3=#:VAL284 TRADE-PRICE))
           (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                 ((TYPEP #3# '<DICT>) (GET #3# . #2#))
                 ((TYPEP #3# '<VECTOR>) (NTH #3# . #2#))
                 ((TYPEP #3# '<SET>) (GET #3# . #2#))
                 (T
                  (ERROR "~S is not a function or collection" 'TRADE-PRICE)))))
     5.0)
    (LET ((TRADE A0))
      T))
   (T
    (LET ((TRADE A0))
      NIL))
   (T
    (ERROR "No matching fn clause for arguments: ~S"
           (COMMON-LISP:LIST . #1#)))))

(DEFUN PENNY-STOCK-BUY? (TRADE)
  (DECLARE (SPECIAL IS-PENNY-STOCK? IS-BUY-SIDE-TRADE?))
  (AND
   (IF (FBOUNDP 'IS-BUY-SIDE-TRADE?)
       (IS-BUY-SIDE-TRADE? . #1=(TRADE))
       (LET ((#2=#:VAL285 IS-BUY-SIDE-TRADE?))
         (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
               ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
               ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
               ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
               (T
                (ERROR #6="~S is not a function or collection"
                       'IS-BUY-SIDE-TRADE?)))))
   (IF (FBOUNDP 'IS-PENNY-STOCK?)
       (IS-PENNY-STOCK? . #7=(TRADE))
       (LET ((#8=#:VAL286 IS-PENNY-STOCK?))
         (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
               ((TYPEP #8# . #3#) (GET #8# . #7#))
               ((TYPEP #8# . #4#) (NTH #8# . #7#))
               ((TYPEP #8# . #5#) (GET #8# . #7#))
               (T (ERROR #6# 'IS-PENNY-STOCK?)))))))

(DEFGENERIC VALIDATE-TRADE
    (TRADE))

(DEFUN VALIDATE-TRADE #1=(TRD)
  (COND
   ((RESTRICTED-SYMBOL? TRD)
    (VECTOR :STATUS :REJECTED :REASON
            (STR "Symbol "
                 (IF (FBOUNDP 'TRADE-SYMBOL)
                     (TRADE-SYMBOL . #2=(TRD))
                     (LET ((#3=#:VAL287 TRADE-SYMBOL))
                       (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                             ((TYPEP #3# '<DICT>) (GET #3# . #2#))
                             ((TYPEP #3# '<VECTOR>) (NTH #3# . #2#))
                             ((TYPEP #3# '<SET>) (GET #3# . #2#))
                             (T
                              (ERROR "~S is not a function or collection"
                                     'TRADE-SYMBOL)))))
                 " is on the restricted list")))
   ((HIGH-VALUE? TRD)
    (VECTOR :STATUS :MANUAL-REVIEW :REASON "Trade value exceeds $1M limit"))
   ((PENNY-STOCK-BUY? TRD)
    (VECTOR :STATUS :WARNING :REASON "High risk penny stock purchase" :TRADE
            TRD))
   (T (VECTOR :STATUS :APPROVED :ID (GENSYM "TRD")))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S"
           'VALIDATE-TRADE (COMMON-LISP:LIST . #1#)))))

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
  (DECLARE (SPECIAL VALIDATE-TRADE T4 T3 T2 T1))
  (DEFVAR T1 (MAKE '<TRADE> :SYMBOL 'NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY))
  (DEFVAR T2 (MAKE '<TRADE> :SYMBOL 'GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL))
  (DEFVAR T3
    (MAKE '<TRADE> :SYMBOL 'IBM :AMOUNT 10000 :PRICE 150.0 :SIDE :BUY))
  (DEFVAR T4 (MAKE '<TRADE> :SYMBOL 'F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY))
  (PRINT
   (STR "T1: "
        (IF (FBOUNDP 'VALIDATE-TRADE)
            (VALIDATE-TRADE . #1=(T1))
            (LET ((#2=#:VAL288 VALIDATE-TRADE))
              (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                    ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                    ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                    ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                    (T
                     (ERROR #6="~S is not a function or collection"
                            'VALIDATE-TRADE)))))))
  (PRINT
   (STR "T2: "
        (IF (FBOUNDP 'VALIDATE-TRADE)
            (VALIDATE-TRADE . #7=(T2))
            (LET ((#8=#:VAL289 VALIDATE-TRADE))
              (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                    ((TYPEP #8# . #3#) (GET #8# . #7#))
                    ((TYPEP #8# . #4#) (NTH #8# . #7#))
                    ((TYPEP #8# . #5#) (GET #8# . #7#))
                    (T (ERROR #6# 'VALIDATE-TRADE)))))))
  (PRINT
   (STR "T3: "
        (IF (FBOUNDP 'VALIDATE-TRADE)
            (VALIDATE-TRADE . #9=(T3))
            (LET ((#10=#:VAL290 VALIDATE-TRADE))
              (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                    ((TYPEP #10# . #3#) (GET #10# . #9#))
                    ((TYPEP #10# . #4#) (NTH #10# . #9#))
                    ((TYPEP #10# . #5#) (GET #10# . #9#))
                    (T (ERROR #6# 'VALIDATE-TRADE)))))))
  (PRINT
   (STR "T4: "
        (IF (FBOUNDP 'VALIDATE-TRADE)
            (VALIDATE-TRADE . #11=(T4))
            (LET ((#12=#:VAL291 VALIDATE-TRADE))
              (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                    ((TYPEP #12# . #3#) (GET #12# . #11#))
                    ((TYPEP #12# . #4#) (NTH #12# . #11#))
                    ((TYPEP #12# . #5#) (GET #12# . #11#))
                    (T (ERROR #6# 'VALIDATE-TRADE))))))))

(IN-PACKAGE :FOL.CORE)

(IF (FBOUNDP 'COMPLIANCE)
    (COMPLIANCE)
    (LET ((#1=#:VAL292 COMPLIANCE))
      (COND ((FUNCTIONP #1#) (FUNCALL #1#))
            (T (ERROR "~S is not a function or collection" 'COMPLIANCE)))))
