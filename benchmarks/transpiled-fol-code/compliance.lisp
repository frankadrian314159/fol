(in-package :fol.core)

(PROGN
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
  (DEFCLASS <TRADE> (<PERSISTENT-OBJECT>)
            ((SYMBOL :INITARG :SYMBOL) (AMOUNT :INITARG :AMOUNT)
             (PRICE :INITARG :PRICE) (SIDE :INITARG :SIDE))
            (:METACLASS PERSISTENT-CLASS))
  (DEFUN TRADE-SYMBOL (FOL.COMPILER::OBJECT)
    (SYCAMORE:HASH-MAP-FIND
     (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
     :SYMBOL))
  (DEFUN TRADE-AMOUNT (FOL.COMPILER::OBJECT)
    (SYCAMORE:HASH-MAP-FIND
     (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
     :AMOUNT))
  (DEFUN TRADE-PRICE (FOL.COMPILER::OBJECT)
    (SYCAMORE:HASH-MAP-FIND
     (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
     :PRICE))
  (DEFUN TRADE-SIDE (FOL.COMPILER::OBJECT)
    (SYCAMORE:HASH-MAP-FIND
     (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
     :SIDE))
  (DEFUN MAKE-<TRADE> (&KEY SYMBOL AMOUNT PRICE SIDE)
    (MAKE-INSTANCE '<TRADE> :SYMBOL SYMBOL :AMOUNT AMOUNT :PRICE PRICE :SIDE
                   SIDE))
  '<TRADE>)
 (DEFUN TRADE-TOTAL-PRICE (TRADE)
   (*
    (IF (FBOUNDP 'TRADE-PRICE)
        (TRADE-PRICE TRADE)
        (LET ((#:VAL342 TRADE-PRICE))
          (COND ((TYPEP #:VAL342 '<DICT>) (GET #:VAL342 TRADE))
                ((TYPEP #:VAL342 '<VECTOR>) (NTH #:VAL342 TRADE))
                ((TYPEP #:VAL342 '<SET>) (GET #:VAL342 TRADE))
                (T
                 (ERROR "~S is not a function or collection" 'TRADE-PRICE)))))
    (IF (FBOUNDP 'TRADE-AMOUNT)
        (TRADE-AMOUNT TRADE)
        (LET ((#:VAL343 TRADE-AMOUNT))
          (COND ((TYPEP #:VAL343 '<DICT>) (GET #:VAL343 TRADE))
                ((TYPEP #:VAL343 '<VECTOR>) (NTH #:VAL343 TRADE))
                ((TYPEP #:VAL343 '<SET>) (GET #:VAL343 TRADE))
                (T
                 (ERROR "~S is not a function or collection"
                        'TRADE-AMOUNT)))))))
 (DEFUN RESTRICTED-SYMBOL? (A0)
   (COND
    ((GET (SET 'META 'GOOG 'MSFT 'AMZN)
          (IF (FBOUNDP 'TRADE-SYMBOL)
              (TRADE-SYMBOL A0)
              (LET ((#:VAL344 TRADE-SYMBOL))
                (COND ((TYPEP #:VAL344 '<DICT>) (GET #:VAL344 A0))
                      ((TYPEP #:VAL344 '<VECTOR>) (NTH #:VAL344 A0))
                      ((TYPEP #:VAL344 '<SET>) (GET #:VAL344 A0))
                      (T
                       (ERROR "~S is not a function or collection"
                              'TRADE-SYMBOL))))))
     (LET ((TRADE A0))
       T))
    (T
     (LET ((TRADE A0))
       NIL))
    (T
     (ERROR "No matching fn clause for arguments: ~S" (COMMON-LISP:LIST A0)))))
 (DEFUN HIGH-VALUE? (A0)
   (COND
    ((>
      (IF (FBOUNDP 'TRADE-TOTAL-PRICE)
          (TRADE-TOTAL-PRICE A0)
          (LET ((#:VAL345 TRADE-TOTAL-PRICE))
            (COND ((TYPEP #:VAL345 '<DICT>) (GET #:VAL345 A0))
                  ((TYPEP #:VAL345 '<VECTOR>) (NTH #:VAL345 A0))
                  ((TYPEP #:VAL345 '<SET>) (GET #:VAL345 A0))
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
     (ERROR "No matching fn clause for arguments: ~S" (COMMON-LISP:LIST A0)))))
 (DEFUN IS-BUY-SIDE-TRADE? (A0)
   (COND
    ((=
      (IF (FBOUNDP 'TRADE-SIDE)
          (TRADE-SIDE A0)
          (LET ((#:VAL346 TRADE-SIDE))
            (COND ((TYPEP #:VAL346 '<DICT>) (GET #:VAL346 A0))
                  ((TYPEP #:VAL346 '<VECTOR>) (NTH #:VAL346 A0))
                  ((TYPEP #:VAL346 '<SET>) (GET #:VAL346 A0))
                  (T
                   (ERROR "~S is not a function or collection" 'TRADE-SIDE)))))
      :BUY)
     (LET ((TRADE A0))
       T))
    (T
     (LET ((TRADE A0))
       NIL))
    (T
     (ERROR "No matching fn clause for arguments: ~S" (COMMON-LISP:LIST A0)))))
 (DEFUN IS-PENNY-STOCK? (A0)
   (COND
    ((<
      (IF (FBOUNDP 'TRADE-PRICE)
          (TRADE-PRICE A0)
          (LET ((#:VAL347 TRADE-PRICE))
            (COND ((TYPEP #:VAL347 '<DICT>) (GET #:VAL347 A0))
                  ((TYPEP #:VAL347 '<VECTOR>) (NTH #:VAL347 A0))
                  ((TYPEP #:VAL347 '<SET>) (GET #:VAL347 A0))
                  (T
                   (ERROR "~S is not a function or collection"
                          'TRADE-PRICE)))))
      5.0)
     (LET ((TRADE A0))
       T))
    (T
     (LET ((TRADE A0))
       NIL))
    (T
     (ERROR "No matching fn clause for arguments: ~S" (COMMON-LISP:LIST A0)))))
 (DEFUN PENNY-STOCK-BUY? (TRADE)
   (AND
    (IF (FBOUNDP 'IS-BUY-SIDE-TRADE?)
        (IS-BUY-SIDE-TRADE? TRADE)
        (LET ((#:VAL348 IS-BUY-SIDE-TRADE?))
          (COND ((TYPEP #:VAL348 '<DICT>) (GET #:VAL348 TRADE))
                ((TYPEP #:VAL348 '<VECTOR>) (NTH #:VAL348 TRADE))
                ((TYPEP #:VAL348 '<SET>) (GET #:VAL348 TRADE))
                (T
                 (ERROR "~S is not a function or collection"
                        'IS-BUY-SIDE-TRADE?)))))
    (IF (FBOUNDP 'IS-PENNY-STOCK?)
        (IS-PENNY-STOCK? TRADE)
        (LET ((#:VAL349 IS-PENNY-STOCK?))
          (COND ((TYPEP #:VAL349 '<DICT>) (GET #:VAL349 TRADE))
                ((TYPEP #:VAL349 '<VECTOR>) (NTH #:VAL349 TRADE))
                ((TYPEP #:VAL349 '<SET>) (GET #:VAL349 TRADE))
                (T
                 (ERROR "~S is not a function or collection"
                        'IS-PENNY-STOCK?)))))))
 (DEFGENERIC VALIDATE-TRADE
     (TRADE))
 (DEFUN VALIDATE-TRADE (TRD)
   (COND
    ((RESTRICTED-SYMBOL? TRD)
     (DICT :STATUS :REJECTED :REASON
           (STR "Symbol "
                (IF (FBOUNDP 'TRADE-SYMBOL)
                    (TRADE-SYMBOL TRD)
                    (LET ((#:VAL350 TRADE-SYMBOL))
                      (COND ((TYPEP #:VAL350 '<DICT>) (GET #:VAL350 TRD))
                            ((TYPEP #:VAL350 '<VECTOR>) (NTH #:VAL350 TRD))
                            ((TYPEP #:VAL350 '<SET>) (GET #:VAL350 TRD))
                            (T
                             (ERROR "~S is not a function or collection"
                                    'TRADE-SYMBOL)))))
                " is on the restricted list")))
    ((HIGH-VALUE? TRD)
     (DICT :STATUS :MANUAL-REVIEW :REASON "Trade value exceeds $1M limit"))
    ((PENNY-STOCK-BUY? TRD)
     (DICT :STATUS :WARNING :REASON "High risk penny stock purchase" :TRADE
           TRD))
    (T (DICT :STATUS :APPROVED :ID (GENSYM "TRD")))
    (T
     (ERROR "No matching method clause for ~A with arguments: ~S"
            'VALIDATE-TRADE (COMMON-LISP:LIST TRD)))))
 (IN-PACKAGE :FOL.CORE)) 
(PROGN
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
 (DEFVAR T1 (MAKE '<TRADE> :SYMBOL 'NU :AMOUNT 100 :PRICE 18.0 :SIDE :BUY))
 (DEFVAR T2 (MAKE '<TRADE> :SYMBOL 'GOOG :AMOUNT 50 :PRICE 150.0 :SIDE :SELL))
 (DEFVAR T3 (MAKE '<TRADE> :SYMBOL 'IBM :AMOUNT 10000 :PRICE 150.0 :SIDE :BUY))
 (DEFVAR T4 (MAKE '<TRADE> :SYMBOL 'F :AMOUNT 1000 :PRICE 12.0 :SIDE :BUY))
 (PRINT
  (STR "T1: "
       (IF (FBOUNDP 'VALIDATE-TRADE)
           (VALIDATE-TRADE T1)
           (LET ((#:VAL351 VALIDATE-TRADE))
             (COND ((TYPEP #:VAL351 '<DICT>) (GET #:VAL351 T1))
                   ((TYPEP #:VAL351 '<VECTOR>) (NTH #:VAL351 T1))
                   ((TYPEP #:VAL351 '<SET>) (GET #:VAL351 T1))
                   (T
                    (ERROR "~S is not a function or collection"
                           'VALIDATE-TRADE)))))))
 (PRINT
  (STR "T2: "
       (IF (FBOUNDP 'VALIDATE-TRADE)
           (VALIDATE-TRADE T2)
           (LET ((#:VAL352 VALIDATE-TRADE))
             (COND ((TYPEP #:VAL352 '<DICT>) (GET #:VAL352 T2))
                   ((TYPEP #:VAL352 '<VECTOR>) (NTH #:VAL352 T2))
                   ((TYPEP #:VAL352 '<SET>) (GET #:VAL352 T2))
                   (T
                    (ERROR "~S is not a function or collection"
                           'VALIDATE-TRADE)))))))
 (PRINT
  (STR "T3: "
       (IF (FBOUNDP 'VALIDATE-TRADE)
           (VALIDATE-TRADE T3)
           (LET ((#:VAL353 VALIDATE-TRADE))
             (COND ((TYPEP #:VAL353 '<DICT>) (GET #:VAL353 T3))
                   ((TYPEP #:VAL353 '<VECTOR>) (NTH #:VAL353 T3))
                   ((TYPEP #:VAL353 '<SET>) (GET #:VAL353 T3))
                   (T
                    (ERROR "~S is not a function or collection"
                           'VALIDATE-TRADE)))))))
 (PRINT
  (STR "T4: "
       (IF (FBOUNDP 'VALIDATE-TRADE)
           (VALIDATE-TRADE T4)
           (LET ((#:VAL354 VALIDATE-TRADE))
             (COND ((TYPEP #:VAL354 '<DICT>) (GET #:VAL354 T4))
                   ((TYPEP #:VAL354 '<VECTOR>) (NTH #:VAL354 T4))
                   ((TYPEP #:VAL354 '<SET>) (GET #:VAL354 T4))
                   (T
                    (ERROR "~S is not a function or collection"
                           'VALIDATE-TRADE)))))))
 (IN-PACKAGE :FOL.CORE)) 