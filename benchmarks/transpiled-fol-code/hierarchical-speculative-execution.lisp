;;; Transpiled from hierarchical-speculative-execution.fol
(in-package :fol.core)

(DEFPACKAGE "HSE"
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
  (:EXPORT <REGULATED-ACCOUNT> DEPOSIT RUN-BENCH))

(IN-PACKAGE "HSE")

(DEFCLASS <VALIDATED> (<PERSISTENT-OBJECT>)
          ((OWNER :INITARG :OWNER :INITFORM "")) (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<VALIDATED> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<VALIDATED>)) . #1#))

'<VALIDATED>

(DEFMETHOD ASSOC :AROUND ((OBJ <VALIDATED>) KEY VAL &REST FOL.COMPILER::KVPS)
  (DECLARE (SPECIAL OBJ KEY VAL FOL.COMPILER::KVPS)
           (IGNORE FOL.COMPILER::KVPS))
  (IF (TRUTHY? (< VAL 0))
      OBJ
      (CALL-NEXT-METHOD)))

(DEFCLASS <BOUNDED-ACCOUNT> (<VALIDATED> <PERSISTENT-OBJECT>)
          ((BALANCE :INITARG :BALANCE :INITFORM 0)
           (LIMIT :INITARG :LIMIT :INITFORM 1000))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<BOUNDED-ACCOUNT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<BOUNDED-ACCOUNT>)) . #1#))

'<BOUNDED-ACCOUNT>

(DEFMETHOD ASSOC :AROUND
           ((ACC <BOUNDED-ACCOUNT>) KEY VAL &REST FOL.COMPILER::KVPS)
  (DECLARE (SPECIAL ACC KEY VAL FOL.COMPILER::KVPS)
           (IGNORE FOL.COMPILER::KVPS))
  (LET ((TENTATIVE (CALL-NEXT-METHOD)))
    (IF (TRUTHY? (> (GET TENTATIVE :BALANCE) (GET ACC :LIMIT)))
        ACC
        TENTATIVE)))

(DEFCLASS <REGULATED-ACCOUNT> (<BOUNDED-ACCOUNT> <PERSISTENT-OBJECT>)
          ((TX-CAP :INITARG :TX-CAP :INITFORM 100))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<REGULATED-ACCOUNT>
       (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<REGULATED-ACCOUNT>)) . #1#))

'<REGULATED-ACCOUNT>

(DEFMETHOD ASSOC :AROUND
           ((ACC <REGULATED-ACCOUNT>) KEY VAL &REST FOL.COMPILER::KVPS)
  (DECLARE (SPECIAL ACC KEY VAL FOL.COMPILER::KVPS)
           (IGNORE FOL.COMPILER::KVPS))
  (IF (TRUTHY?
       (AND (= KEY :BALANCE) (> (- VAL (GET ACC :BALANCE)) (GET ACC :TX-CAP))))
      ACC
      (CALL-NEXT-METHOD)))

(DEFUN DEPOSIT (ACC AMOUNT) (ASSOC ACC :BALANCE (+ (GET ACC :BALANCE) AMOUNT)))

(DEFUN RUN-BENCH (ITERATIONS)
  (LET ((ACC
         (MAKE '<REGULATED-ACCOUNT> :OWNER "Alice" :BALANCE 0 :LIMIT 2000000
               :TX-CAP 1000000)))
    (BLOCK LOOP-BLOCK-2
      (LET ((I 0) (A ACC))
        (TAGBODY
         LOOP-2
          (LET ((RESULT-2
                 (PROGN
                  (IF (TRUTHY? (< I ITERATIONS))
                      (PROGN
                       (PSETQ I (INC I)
                              A (DEPOSIT A 1))
                       (GO LOOP-2))
                      (GET A :BALANCE)))))
            (RETURN-FROM LOOP-BLOCK-2 RESULT-2)))))))
