;;; Transpiled from observable.fol
(in-package :fol.core)

(DEFPACKAGE "OBSERVABLE"
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
  (:EXPORT <SENSOR> ON-CHANGE RUN-BENCH))

(IN-PACKAGE "OBSERVABLE")

(DEFCLASS <SENSOR> (<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME) (READING :INITARG :READING :INITFORM 0)
           (STATUS :INITARG :STATUS :INITFORM :NORMAL))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<SENSOR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<SENSOR>)) . #1#))

'<SENSOR>

(DEFUN MAKE-CHANGE (OBJ SLOT OLD-VAL NEW-VAL)
  (DICT :NEW NEW-VAL :SLOT SLOT :OBJECT OBJ :OLD OLD-VAL))

(DEFUN UPDATED (OBJ SNEXT NEW-VAL)
  (LET ((OLD-VAL (GET OBJ SNEXT)))
    (LET ((NEW-OBJ (ASSOC OBJ SNEXT NEW-VAL)))
      (DICT :OBJECT NEW-OBJ :CHANGE (MAKE-CHANGE OBJ SNEXT OLD-VAL NEW-VAL)))))

(DEFUN SPIKE? (CH)
  (LET ((CHANGE (GET CH :CHANGE)))
    (AND (= (GET CHANGE :SLOT) :READING)
         (> (- (GET CHANGE :NEW) (GET CHANGE :OLD)) 50))))

(DEFUN CRITICAL? (CH)
  (LET ((CHANGE (GET CH :CHANGE)))
    (AND (= (GET CHANGE :SLOT) :STATUS) (= (GET CHANGE :NEW) :CRITICAL))))

(DEFGENERIC ON-CHANGE
    (CHANGE))

(DEFMETHOD ON-CHANGE #1=(C)
  (DECLARE (SPECIAL C))
  (COND
   ((SPIKE? C)
    (DICT :ALERT :SPIKE :MESSAGE
          (STR "Spike detected: " (GET (GET C :CHANGE) :OLD) " -> "
               (GET (GET C :CHANGE) :NEW))))
   ((CRITICAL? C)
    (DICT :ALERT :CRITICAL :MESSAGE "Sensor entered critical state"))
   (T
    (DICT :ALERT :INFO :MESSAGE
          (STR "Slot " (GET (GET C :CHANGE) :SLOT) " changed: "
               (GET (GET C :CHANGE) :OLD) " -> " (GET (GET C :CHANGE) :NEW))))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S" 'ON-CHANGE
           (COMMON-LISP:LIST . #1#)))))

(DEFUN RUN-BENCH (ITERATIONS)
  (LET ((SENSOR (MAKE '<SENSOR> :NAME "S1" :READING 0 :STATUS :NORMAL)))
    (BLOCK LOOP-BLOCK-10
      (LET ((I 0) (S SENSOR))
        (TAGBODY
         LOOP-10
          (LET ((RESULT-10
                 (PROGN
                  (IF (TRUTHY? (< I ITERATIONS))
                      (LET ((VAL
                             (IF (TRUTHY? (= (MOD I 100) 0))
                                 60
                                 1)))
                        (LET ((RES
                               (UPDATED S :READING (+ (GET S :READING) VAL))))
                          (PROGN
                           (ON-CHANGE RES)
                           (PROGN
                            (PSETQ I (INC I)
                                   S (GET RES :OBJECT))
                            (GO LOOP-10)))))
                      S))))
            (RETURN-FROM LOOP-BLOCK-10 RESULT-10)))))))
