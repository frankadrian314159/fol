;;; Transpiled from diff.fol
(in-package :fol.core)

(DEFPACKAGE "DIFF"
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
  (:EXPORT <METRIC> RUN-BENCH))

(IN-PACKAGE "DIFF")

(DEFCLASS <DIFFABLE> (<PERSISTENT-OBJECT>)
          ((_CHANGES :INITARG :_CHANGES :INITFORM 0))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<DIFFABLE> (&KEY _CHANGES)
  (MAKE-INSTANCE '<DIFFABLE> :_CHANGES _CHANGES))

'<DIFFABLE>

(DEFMETHOD ASSOC :AROUND ((OBJ <DIFFABLE>) KEY VAL &REST FOL.COMPILER::KVPS)
  (DECLARE (SPECIAL FOL.COMPILER::KVPS VAL KEY OBJ)
           (IGNORE FOL.COMPILER::KVPS))
  (LET ((OLD-VAL (GET OBJ KEY)))
    (LET ((RESULT (CALL-NEXT-METHOD)))
      (IF (TRUTHY? (AND (NOT (= KEY :_CHANGES)) (NOT (= OLD-VAL VAL))))
          (ASSOC RESULT :_CHANGES (INC (GET RESULT :_CHANGES)))
          RESULT))))

(DEFCLASS <METRIC> (<DIFFABLE> <PERSISTENT-OBJECT>)
          ((CPU :INITARG :CPU :INITFORM 0.0)
           (MEMORY :INITARG :MEMORY :INITFORM 0.0)
           (DISK :INITARG :DISK :INITFORM 0.0)
           (NET :INITARG :NET :INITFORM 0.0) (IOPS :INITARG :IOPS :INITFORM 0))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<METRIC> (&KEY CPU MEMORY DISK NET IOPS)
  (MAKE-INSTANCE '<METRIC> :CPU CPU :MEMORY MEMORY :DISK DISK :NET NET :IOPS
                 IOPS))

'<METRIC>

(DEFUN RUN-BENCH (ITERATIONS)
  (LET ((M (MAKE '<METRIC> :CPU 0.0 :MEMORY 0.0 :DISK 0.0 :NET 0.0 :IOPS 0)))
    (BLOCK LOOP-BLOCK-1
      (LET ((I 0) (A M) (TOTAL 0))
        (TAGBODY
         LOOP-1
          (LET ((RESULT-1
                 (PROGN
                  (IF (TRUTHY? (< I ITERATIONS))
                      (LET ((A2
                             (ASSOC
                              (ASSOC
                               (ASSOC
                                (ASSOC
                                 (ASSOC (ASSOC A :_CHANGES 0) :CPU (+ 1.0 I))
                                 :MEMORY (+ 2.0 I))
                                :DISK (+ 3.0 I))
                               :NET (+ 4.0 I))
                              :IOPS (INC I))))
                        (PROGN
                         (PSETQ I (INC I)
                                A A2
                                TOTAL (+ TOTAL (GET A2 :_CHANGES)))
                         (GO LOOP-1)))
                      TOTAL))))
            (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))
