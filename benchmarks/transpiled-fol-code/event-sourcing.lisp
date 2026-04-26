;;; Transpiled from event-sourcing.fol
(in-package :fol.core)

(DEFPACKAGE "EVENT-SOURCING"
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
  (:EXPORT <ACCOUNT> APPLY-COMMAND REPLAY-TO RUN-BENCH))

(IN-PACKAGE "EVENT-SOURCING")

(DEFCLASS <ACCOUNT> (<PERSISTENT-OBJECT>)
          ((BALANCE :INITFORM 0 :INITARG :BALANCE)
           (EVENTS :INITFORM (VECTOR) :INITARG :EVENTS))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<ACCOUNT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<ACCOUNT>)) . #1#))

'<ACCOUNT>

(DEFUN NOW () (GET-INTERNAL-RUN-TIME))

(DEFGENERIC APPLY-COMMAND
    (AGG CMD))

(DEFMETHOD APPLY-COMMAND :AROUND (AGG CMD)
  (DECLARE (SPECIAL CMD))
  (LET ((RESULT (CALL-NEXT-METHOD)))
    (LET ((EVENT (DICT :COMMAND CMD :TIMESTAMP (NOW))))
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
  (LET ((ACC (MAKE '<ACCOUNT>)))
    (LET ((CMDS
           (MAP
            (LAMBDA (I)
              (DICT :AMOUNT 10 :TYPE
                    (IF (TRUTHY? (= (MOD I 2) 0))
                        :DEPOSIT
                        :WITHDRAW)))
            (RANGE ITERATIONS))))
      (REPLAY-TO ACC CMDS))))
