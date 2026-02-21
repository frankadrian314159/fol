;;; Transpiled from observable.fol
(in-package :fol.core)

(DEFPACKAGE "OBSERVABLE"
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
  (:EXPORT <SENSOR> ON-CHANGE RUN-BENCH))

(IN-PACKAGE "OBSERVABLE")

(DEFCLASS <SENSOR> (<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME) (READING :INITARG :READING :INITFORM 0)
           (STATUS :INITARG :STATUS :INITFORM :NORMAL))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<SENSOR> (&KEY NAME READING STATUS)
  (MAKE-INSTANCE '<SENSOR> :NAME NAME :READING READING :STATUS STATUS))

'<SENSOR>

(DEFUN MAKE-CHANGE (OBJ SLOT OLD-VAL NEW-VAL)
  (DICT :OLD OLD-VAL :OBJECT OBJ :SLOT SLOT :NEW NEW-VAL))

(DEFUN UPDATED (OBJ SNEXT NEW-VAL)
  (DECLARE (SPECIAL MAKE-CHANGE))
  (LET ((OLD-VAL (GET OBJ SNEXT)))
    (LET ((NEW-OBJ (ASSOC OBJ SNEXT NEW-VAL)))
      (DICT :CHANGE
            (IF (FBOUNDP 'MAKE-CHANGE)
                (MAKE-CHANGE . #1=(OBJ SNEXT OLD-VAL NEW-VAL))
                (LET ((#2=#:VAL271 MAKE-CHANGE))
                  (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                        (T
                         (ERROR "~S is not a function or collection"
                                'MAKE-CHANGE)))))
            :OBJECT NEW-OBJ))))

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
    (DICT :MESSAGE
          (STR "Spike detected: " (GET (GET C :CHANGE) :OLD) " -> "
               (GET (GET C :CHANGE) :NEW))
          :ALERT :SPIKE))
   ((CRITICAL? C)
    (DICT :MESSAGE "Sensor entered critical state" :ALERT :CRITICAL))
   (T
    (DICT :MESSAGE
          (STR "Slot " (GET (GET C :CHANGE) :SLOT) " changed: "
               (GET (GET C :CHANGE) :OLD) " -> " (GET (GET C :CHANGE) :NEW))
          :ALERT :INFO))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S" 'ON-CHANGE
           (COMMON-LISP:LIST . #1#)))))

(DEFUN RUN-BENCH (ITERATIONS)
  (DECLARE (SPECIAL ON-CHANGE UPDATED))
  (LET ((SENSOR (MAKE '<SENSOR> :NAME "S1" :READING 0 :STATUS :NORMAL)))
    (BLOCK LOOP-BLOCK-1
      (LET ((I 0) (S SENSOR))
        (TAGBODY
         LOOP-1
          (LET ((RESULT-1
                 (PROGN
                  (IF (TRUTHY? (< I ITERATIONS))
                      (LET ((VAL
                             (IF (TRUTHY? (= (MOD I 100) 0))
                                 60
                                 1)))
                        (LET ((RES
                               (IF (FBOUNDP 'UPDATED)
                                   (UPDATED
                                    . #1=(S :READING (+ (GET S :READING) VAL)))
                                   (LET ((#2=#:VAL272 UPDATED))
                                     (COND
                                      ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                      (T
                                       (ERROR
                                        #3="~S is not a function or collection"
                                        'UPDATED)))))))
                          (PROGN
                           (IF (FBOUNDP 'ON-CHANGE)
                               (ON-CHANGE . #4=(RES))
                               (LET ((#5=#:VAL273 ON-CHANGE))
                                 (COND ((FUNCTIONP #5#) (FUNCALL #5# . #4#))
                                       ((TYPEP #5# '<DICT>) (GET #5# . #4#))
                                       ((TYPEP #5# '<VECTOR>) (NTH #5# . #4#))
                                       ((TYPEP #5# '<SET>) (GET #5# . #4#))
                                       (T (ERROR #3# 'ON-CHANGE)))))
                           (PROGN
                            (PSETQ I (INC I)
                                   S (GET RES :OBJECT))
                            (GO LOOP-1)))))
                      S))))
            (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))
