;;; Transpiled from hierarchical-speculative-execution.fol
(in-package :fol.core)

(DEFPACKAGE "HSE"
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
  (:EXPORT <REGULATED-ACCOUNT> DEPOSIT RUN-BENCH))

(IN-PACKAGE "HSE")

(DEFCLASS <VALIDATED> (<PERSISTENT-OBJECT>)
          ((OWNER :INITARG :OWNER :INITFORM "")) (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<VALIDATED> (&KEY OWNER) (MAKE-INSTANCE '<VALIDATED> :OWNER OWNER))

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

(DEFUN MAKE-<BOUNDED-ACCOUNT> (&KEY BALANCE LIMIT)
  (MAKE-INSTANCE '<BOUNDED-ACCOUNT> :BALANCE BALANCE :LIMIT LIMIT))

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

(DEFUN FOL.CORE::MAKE-<REGULATED-ACCOUNT> (&KEY TX-CAP)
  (MAKE-INSTANCE '<REGULATED-ACCOUNT> :TX-CAP TX-CAP))

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
    (BLOCK LOOP-BLOCK-1
      (LET ((I 0) (A ACC))
        (TAGBODY
         LOOP-1
          (LET ((RESULT-1
                 (PROGN
                  (IF (TRUTHY? (< I ITERATIONS))
                      (PROGN
                       (PSETQ I (INC I)
                              A (DEPOSIT A 1))
                       (GO LOOP-1))
                      (GET A :BALANCE)))))
            (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))
