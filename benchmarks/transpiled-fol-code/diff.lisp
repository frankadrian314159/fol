;;; Transpiled from diff.fol
(in-package :fol.core)

(DEFPACKAGE "DIFF"
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
  (:EXPORT <METRIC> RUN-BENCH))

(IN-PACKAGE "DIFF")

(DEFCLASS <DIFFABLE> (<PERSISTENT-OBJECT>)
          ((_CHANGES :INITARG :_CHANGES :INITFORM 0))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<DIFFABLE> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<DIFFABLE>)) . #1#))

'<DIFFABLE>

(DEFMETHOD ASSOC :AROUND ((OBJ <DIFFABLE>) KEY VAL &REST FOL.COMPILER::KVPS)
  (DECLARE (SPECIAL OBJ KEY VAL FOL.COMPILER::KVPS)
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

(DEFUN FOL.CORE::MAKE-<METRIC> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<METRIC>)) . #1#))

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
