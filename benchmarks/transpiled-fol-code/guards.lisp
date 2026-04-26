;;; Transpiled from guards.fol
(in-package :fol.core)

(DEFPACKAGE "GUARDS"
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
  (:EXPORT <ACCOUNT> DEPOSIT WITHDRAW RUN-BENCH))

(IN-PACKAGE "GUARDS")

(DEFCLASS <ACCOUNT> (<PERSISTENT-OBJECT>)
          ((OWNER :INITARG :OWNER) (BALANCE :INITARG :BALANCE :INITFORM 0))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<ACCOUNT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<ACCOUNT>)) . #1#))

'<ACCOUNT>

(DEFMETHOD ASSOC :AROUND ((ACC <ACCOUNT>) SLOT VAL &REST FOL.COMPILER::KVPS)
  (DECLARE (SPECIAL ACC SLOT VAL FOL.COMPILER::KVPS)
           (IGNORE FOL.COMPILER::KVPS))
  (LET ((RESULT (CALL-NEXT-METHOD)))
    (PROGN
     (IF (TRUTHY? (< (GET RESULT :BALANCE) 0))
         (PROGN (ERROR "~A: balance cannot go negative" (GET ACC :OWNER)))
         NIL)
     RESULT)))

(DEFUN DEPOSIT (ACC AMOUNT) (ASSOC ACC :BALANCE (+ (GET ACC :BALANCE) AMOUNT)))

(DEFUN WITHDRAW (ACC AMOUNT) (ASSOC ACC :BALANCE (- (GET ACC :BALANCE) AMOUNT)))

(DEFUN RUN-BENCH (ITERATIONS)
  (LET ((ACC (MAKE '<ACCOUNT> :OWNER "Alice" :BALANCE 0)))
    (BLOCK LOOP-BLOCK-6
      (LET ((I 0) (A ACC))
        (TAGBODY
         LOOP-6
          (LET ((RESULT-6
                 (PROGN
                  (IF (TRUTHY? (< I ITERATIONS))
                      (PROGN
                       (PSETQ I (INC I)
                              A (DEPOSIT A 1))
                       (GO LOOP-6))
                      (GET A :BALANCE)))))
            (RETURN-FROM LOOP-BLOCK-6 RESULT-6)))))))
