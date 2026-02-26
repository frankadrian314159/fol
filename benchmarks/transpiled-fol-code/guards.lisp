;;; Transpiled from guards.fol
(in-package :fol.core)

(DEFPACKAGE "GUARDS"
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
  (:EXPORT <ACCOUNT> DEPOSIT WITHDRAW RUN-BENCH))

(IN-PACKAGE "GUARDS")

(DEFCLASS <ACCOUNT> (<PERSISTENT-OBJECT>)
          ((OWNER :INITARG :OWNER)
           (BALANCE :INITARG :BALANCE :INITFORM 0))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<ACCOUNT> (&KEY OWNER BALANCE)
  (MAKE-INSTANCE '<ACCOUNT> :OWNER OWNER :BALANCE BALANCE))

'<ACCOUNT>

;;; Cross-cutting invariant guard: every (assoc <account> ...) call
;;; passes through this method.  No equivalent in plain CL -- each
;;; update function must repeat the (when (< new-balance 0) ...) check.
(DEFMETHOD ASSOC :AROUND ((ACC <ACCOUNT>) SLOT VAL &REST KVPS)
  (DECLARE (SPECIAL ACC SLOT VAL KVPS) (IGNORE KVPS))
  (LET ((RESULT (CALL-NEXT-METHOD)))
    (WHEN (< (GET RESULT :BALANCE) 0)
      (CL:ERROR "~A: balance cannot go negative" (GET ACC :OWNER)))
    RESULT))

(DEFUN DEPOSIT (ACC AMOUNT)
  (DECLARE (SPECIAL ACC AMOUNT))
  (ASSOC ACC :BALANCE (+ (GET ACC :BALANCE) AMOUNT)))

(DEFUN WITHDRAW (ACC AMOUNT)
  (DECLARE (SPECIAL ACC AMOUNT))
  (ASSOC ACC :BALANCE (- (GET ACC :BALANCE) AMOUNT)))

(DEFUN RUN-BENCH (ITERATIONS)
  (DECLARE (SPECIAL ITERATIONS))
  (LET ((ACC (MAKE '<ACCOUNT> :OWNER "Alice" :BALANCE 0)))
    (BLOCK LOOP-BLOCK-1
      (LET ((I 0) (A ACC))
        (TAGBODY
         LOOP-1
          (LET ((RESULT-1
                 (IF (TRUTHY? (< I ITERATIONS))
                     (PROGN
                      (PSETQ I (INC I) A (DEPOSIT A 1))
                      (GO LOOP-1))
                     (GET A :BALANCE))))
            (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))
