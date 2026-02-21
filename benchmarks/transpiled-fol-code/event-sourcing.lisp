;;; Transpiled from event-sourcing.fol
(in-package :fol.core)

(DEFPACKAGE "EVENT-SOURCING"
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
  (:EXPORT <ACCOUNT> APPLY-COMMAND REPLAY-TO RUN-BENCH))

(IN-PACKAGE "EVENT-SOURCING")

(DEFCLASS <ACCOUNT> (<PERSISTENT-OBJECT>)
          ((BALANCE :INITFORM 0) (EVENTS :INITFORM (VECTOR)))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<ACCOUNT> (&KEY BALANCE EVENTS)
  (MAKE-INSTANCE '<ACCOUNT> :BALANCE BALANCE :EVENTS EVENTS))

'<ACCOUNT>

(DEFUN NOW () (GET-INTERNAL-RUN-TIME))

(DEFGENERIC APPLY-COMMAND
    (AGG CMD))

(DEFMETHOD APPLY-COMMAND :AROUND (AGG CMD)
  (DECLARE (SPECIAL CMD NOW))
  (LET ((RESULT (CALL-NEXT-METHOD)))
    (LET ((EVENT
           (DICT :TIMESTAMP
                 (IF (FBOUNDP 'NOW)
                     (NOW)
                     (LET ((#1=#:VAL271 NOW))
                       (COND ((FUNCTIONP #1#) (FUNCALL #1#))
                             (T
                              (ERROR "~S is not a function or collection"
                                     'NOW)))))
                 :COMMAND CMD)))
      (ASSOC RESULT :EVENTS (CONJ (GET RESULT :EVENTS) EVENT)))))

(DEFUN DEPOSIT? (CMD) (= (GET CMD :TYPE) :DEPOSIT))

(DEFUN WITHDRAW? (CMD) (= (GET CMD :TYPE) :WITHDRAW))

(DEFMETHOD APPLY-COMMAND #1=(AGG CMD)
  (DECLARE (SPECIAL CMD AGG))
  (COND
   ((DEPOSIT? CMD)
    (ASSOC AGG :BALANCE (+ (GET AGG :BALANCE) (GET CMD :AMOUNT))))
   ((WITHDRAW? CMD)
    (ASSOC AGG :BALANCE (- (GET AGG :BALANCE) (GET CMD :AMOUNT))))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S" 'APPLY-COMMAND
           (COMMON-LISP:LIST . #1#)))))

(DEFUN REPLAY-TO (AGGREGATE EVENTS) (REDUCE #'APPLY-COMMAND AGGREGATE EVENTS))

(DEFUN RUN-BENCH (ITERATIONS)
  (DECLARE (SPECIAL REPLAY-TO))
  (LET ((ACC (MAKE '<ACCOUNT>)))
    (LET ((CMDS
           (MAP
            (LAMBDA (I)
              (DICT :TYPE
                    (IF (TRUTHY? (= (MOD I 2) 0))
                        :DEPOSIT
                        :WITHDRAW)
                    :AMOUNT 10))
            (RANGE ITERATIONS))))
      (IF (FBOUNDP 'REPLAY-TO)
          (REPLAY-TO . #1=(ACC CMDS))
          (LET ((#2=#:VAL272 REPLAY-TO))
            (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                  ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                  ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                  ((TYPEP #2# '<SET>) (GET #2# . #1#))
                  (T
                   (ERROR "~S is not a function or collection"
                          'REPLAY-TO))))))))
