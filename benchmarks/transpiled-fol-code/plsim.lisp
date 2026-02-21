;;; Transpiled from plsim.fol
(in-package :fol.core)

(DEFPACKAGE "PLSIM"
  (:USE "FOL.LIB.REDUCERS" "FOL.CORE" "CL")
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
  (:EXPORT REGISTER-MODULE
           GET-MODULE
           <COMPONENT>
           <MODULE-DEF>
           <LOGIC-COMPONENT>
           COMPUTE-NEXT-STATE
           REGISTER-PRIMITIVE
           GET-PRIMITIVE
           DEFPART
           EXPAND-NETLIST
           EXPAND-SPEC
           RUN-SIMULATION
           MONITOR
           EVENTS
           ADDEVENTS
           RUNLSIM
           DISPLAYLSIM))

(IN-PACKAGE "PLSIM")

(DEFVAR *CIRCUIT-MODULES* (ATOM (DICT)))

(DEFUN REGISTER-MODULE (NAME DEF)
  (DECLARE (SPECIAL *CIRCUIT-MODULES*))
  (SWAP! *CIRCUIT-MODULES* (LAMBDA (M) (ASSOC M NAME DEF))))

(DEFUN GET-MODULE (NAME)
  (DECLARE (SPECIAL *CIRCUIT-MODULES*))
  (GET (DEREF *CIRCUIT-MODULES*) NAME))

(DEFCLASS <COMPONENT> (<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME) (TYPE :INITARG :TYPE)
           (CONNECTIONS :INITARG :CONNECTIONS))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<COMPONENT> (&KEY NAME TYPE CONNECTIONS)
  (MAKE-INSTANCE '<COMPONENT> :NAME NAME :TYPE TYPE :CONNECTIONS CONNECTIONS))

'<COMPONENT>

(DEFUN COMPONENT-NAME (OBJ) (GET OBJ :NAME))

(DEFUN COMPONENT-TYPE (OBJ) (GET OBJ :TYPE))

(DEFUN COMPONENT-CONNECTIONS (OBJ) (GET OBJ :CONNECTIONS))

(DEFCLASS <MODULE-DEF> (<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME) (PORTS :INITARG :PORTS) (BODY :INITARG :BODY))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<MODULE-DEF> (&KEY NAME PORTS BODY)
  (MAKE-INSTANCE '<MODULE-DEF> :NAME NAME :PORTS PORTS :BODY BODY))

'<MODULE-DEF>

(DEFUN MODULE-NAME (OBJ) (GET OBJ :NAME))

(DEFUN MODULE-PORTS (OBJ) (GET OBJ :PORTS))

(DEFUN MODULE-BODY (OBJ) (GET OBJ :BODY))

(DEFCLASS <LOGIC-COMPONENT> (<COMPONENT> <PERSISTENT-OBJECT>)
          ((INPUTS :INITARG :INPUTS) (OUTPUTS :INITARG :OUTPUTS)
           (DELAYS :INITARG :DELAYS) (LOGIC-FN :INITARG :LOGIC-FN))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<LOGIC-COMPONENT> (&KEY INPUTS OUTPUTS DELAYS LOGIC-FN)
  (MAKE-INSTANCE '<LOGIC-COMPONENT> :INPUTS INPUTS :OUTPUTS OUTPUTS :DELAYS
                 DELAYS :LOGIC-FN LOGIC-FN))

'<LOGIC-COMPONENT>

(DEFUN COMPONENT-INPUTS (OBJ) (GET OBJ :INPUTS))

(DEFUN COMPONENT-OUTPUTS (OBJ) (GET OBJ :OUTPUTS))

(DEFUN COMPONENT-DELAYS (OBJ) (GET OBJ :DELAYS))

(DEFUN COMPONENT-LOGIC-FN (OBJ) (GET OBJ :LOGIC-FN))

(DEFUN COMPUTE-NEXT-STATE (COMP INPUT-STATES CHANGED-INPUTS)
  (DECLARE (SPECIAL COMPONENT-OUTPUTS COMPONENT-DELAYS COMPONENT-LOGIC-FN))
  (LET ((LOGIC-FN
         (IF (FBOUNDP 'COMPONENT-LOGIC-FN)
             (COMPONENT-LOGIC-FN . #1=(COMP))
             (LET ((#2=#:VAL311 COMPONENT-LOGIC-FN))
               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                     ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                     ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                     ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                     (T
                      (ERROR #6="~S is not a function or collection"
                             'COMPONENT-LOGIC-FN)))))))
    (LET ((DELAYS
           (IF (FBOUNDP 'COMPONENT-DELAYS)
               (COMPONENT-DELAYS . #7=(COMP))
               (LET ((#8=#:VAL312 COMPONENT-DELAYS))
                 (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                       ((TYPEP #8# . #3#) (GET #8# . #7#))
                       ((TYPEP #8# . #4#) (NTH #8# . #7#))
                       ((TYPEP #8# . #5#) (GET #8# . #7#))
                       (T (ERROR #6# 'COMPONENT-DELAYS)))))))
      (LET ((NEW-STATES
             (LET ((#9=#:OP313 LOGIC-FN))
               (COND ((FUNCTIONP #9#) (FUNCALL #9# . #10=(INPUT-STATES)))
                     ((TYPEP #9# . #3#) (GET #9# . #10#))
                     ((TYPEP #9# . #4#) (NTH #9# . #10#))
                     ((TYPEP #9# . #5#) (GET #9# . #10#))
                     (T
                      (ERROR "Value ~S is not callable or a collection"
                             #9#))))))
        (MAP
         (LAMBDA (OUT-PORT)
           (LET ((DELAY
                  (REDUCE
                   (LAMBDA (MAX-D IN-PORT)
                     (LET ((D (GET (GET DELAYS IN-PORT) OUT-PORT)))
                       (IF (TRUTHY? D)
                           (IF (TRUTHY? (> D MAX-D))
                               D
                               MAX-D)
                           MAX-D)))
                   0 CHANGED-INPUTS)))
             (DICT :VALUE (GET NEW-STATES OUT-PORT) :DELAY DELAY :PORT
                   OUT-PORT)))
         (IF (FBOUNDP 'COMPONENT-OUTPUTS)
             (COMPONENT-OUTPUTS . #11=(COMP))
             (LET ((#12=#:VAL314 COMPONENT-OUTPUTS))
               (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                     ((TYPEP #12# . #3#) (GET #12# . #11#))
                     ((TYPEP #12# . #4#) (NTH #12# . #11#))
                     ((TYPEP #12# . #5#) (GET #12# . #11#))
                     (T (ERROR #6# 'COMPONENT-OUTPUTS))))))))))

(DEFVAR *PRIMITIVES* (ATOM (DICT)))

(DEFUN REGISTER-PRIMITIVE (NAME FACTORY)
  (DECLARE (SPECIAL *PRIMITIVES*))
  (SWAP! *PRIMITIVES* (LAMBDA (P) (ASSOC P NAME FACTORY))))

(DEFUN GET-PRIMITIVE (TYPE)
  (DECLARE (SPECIAL *PRIMITIVES*))
  (GET (DEREF *PRIMITIVES*) TYPE))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('NOT
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'NOT :CONNECTIONS CONNS
                   :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN (DICT :OUT 1)) :LOGIC-FN
                   (LAMBDA (S) (DICT :OUT (BITXOR (GET S :IN) 1)))))))
    (LET ((#2=#:VAL315 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('NAND
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'NAND :CONNECTIONS CONNS
                   :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
                   (LAMBDA (S)
                     (DICT :OUT
                           (BITXOR (BITAND (GET S :IN1) (GET S :IN2)) 1)))))))
    (LET ((#2=#:VAL316 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('NOR
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'NOR :CONNECTIONS CONNS
                   :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
                   (LAMBDA (S)
                     (DICT :OUT
                           (BITXOR (BITOR (GET S :IN1) (GET S :IN2)) 1)))))))
    (LET ((#2=#:VAL317 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('AND
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'AND :CONNECTIONS CONNS
                   :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                   (LAMBDA (S)
                     (DICT :OUT (BITAND (GET S :IN1) (GET S :IN2))))))))
    (LET ((#2=#:VAL318 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('OR
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'OR :CONNECTIONS CONNS
                   :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                   (LAMBDA (S)
                     (DICT :OUT (BITOR (GET S :IN1) (GET S :IN2))))))))
    (LET ((#2=#:VAL319 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('XOR
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'XOR :CONNECTIONS CONNS
                   :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                   (LAMBDA (S)
                     (DICT :OUT (BITXOR (GET S :IN1) (GET S :IN2))))))))
    (LET ((#2=#:VAL320 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('XNOR
           (LAMBDA (NAME PARAM CONNS)
             (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'XNOR :CONNECTIONS CONNS
                   :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                   (DICT :IN2 (DICT :OUT 4) :IN1 (DICT :OUT 4)) :LOGIC-FN
                   (LAMBDA (S)
                     (DICT :OUT
                           (BITXOR (BITXOR (GET S :IN1) (GET S :IN2)) 1)))))))
    (LET ((#2=#:VAL321 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE
     . #1=('DELAY
           (LAMBDA (NAME PARAM CONNS)
             (LET ((D
                    (IF (TRUTHY? PARAM)
                        PARAM
                        0)))
               (MAKE '<LOGIC-COMPONENT> :NAME NAME :TYPE 'DELAY :CONNECTIONS
                     CONNS :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN (DICT :OUT D)) :LOGIC-FN
                     (LAMBDA (S) (DICT :OUT (GET S :IN))))))))
    (LET ((#2=#:VAL322 REGISTER-PRIMITIVE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T
             (ERROR "~S is not a function or collection"
                    'REGISTER-PRIMITIVE)))))

(DEFUN QUALIFY-NAME (PREFIX NAME)
  (IF (TRUTHY? (NIL? PREFIX))
      NAME
      (SYMBOL (STR PREFIX "/" NAME))))

(DEFUN RESOLVE-NODE (NODE-SYM PREFIX BINDINGS)
  (DECLARE (SPECIAL QUALIFY-NAME))
  (LET ((KW (FIND-KEYWORD NODE-SYM)))
    (IF (TRUTHY? (CONTAINS? BINDINGS KW))
        (GET BINDINGS KW)
        (IF (FBOUNDP 'QUALIFY-NAME)
            (QUALIFY-NAME . #1=(PREFIX NODE-SYM))
            (LET ((#2=#:VAL323 QUALIFY-NAME))
              (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                    ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                    ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                    ((TYPEP #2# '<SET>) (GET #2# . #1#))
                    (T
                     (ERROR "~S is not a function or collection"
                            'QUALIFY-NAME))))))))

(DEFUN PARSE-CONNECTIONS (ARGS PREFIX BINDINGS)
  (DECLARE (SPECIAL RESOLVE-NODE))
  (BLOCK LOOP-BLOCK-3
    (LET ((REM ARGS) (ACC (DICT)))
      (TAGBODY
       LOOP-3
        (LET ((RESULT-3
               (PROGN
                (IF (TRUTHY? (EMPTY? REM))
                    ACC
                    (LET ((PORT (FIRST REM)))
                      (LET ((NODE-SYM (SECOND REM)))
                        (LET ((RESOLVED
                               (IF (FBOUNDP 'RESOLVE-NODE)
                                   (RESOLVE-NODE
                                    . #1=(NODE-SYM PREFIX BINDINGS))
                                   (LET ((#2=#:VAL324 RESOLVE-NODE))
                                     (COND
                                      ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                      (T
                                       (ERROR
                                        "~S is not a function or collection"
                                        'RESOLVE-NODE)))))))
                          (PROGN
                           (PSETQ REM (REST (REST REM))
                                  ACC (ASSOC ACC PORT RESOLVED))
                           (GO LOOP-3)))))))))
          (RETURN-FROM LOOP-BLOCK-3 RESULT-3))))))

(DEFUN EXPAND-SPEC (SPEC PREFIX BINDINGS)
  (DECLARE
   (SPECIAL MODULE-BODY GET-PRIMITIVE GET-MODULE PARSE-CONNECTIONS
    QUALIFY-NAME))
  (LET ((TYPE (FIRST SPEC)))
    (LET ((NAME (SECOND SPEC)))
      (LET ((RAW-ARGS (REST (REST SPEC))))
        (LET ((HAS-PARAM?
               (AND (NOT (EMPTY? RAW-ARGS))
                    (NOT (<KEYWORD>? (FIRST RAW-ARGS))))))
          (LET ((PARAM
                 (IF (TRUTHY? HAS-PARAM?)
                     (FIRST RAW-ARGS)
                     NIL)))
            (LET ((ARGS
                   (IF (TRUTHY? HAS-PARAM?)
                       (REST RAW-ARGS)
                       RAW-ARGS)))
              (LET ((FULL-NAME
                     (IF (FBOUNDP 'QUALIFY-NAME)
                         (QUALIFY-NAME . #1=(PREFIX NAME))
                         (LET ((#2=#:VAL325 QUALIFY-NAME))
                           (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                 ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                                 ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                                 ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                                 (T
                                  (ERROR
                                   #6="~S is not a function or collection"
                                   'QUALIFY-NAME)))))))
                (LET ((RESOLVED-CONNS
                       (IF (FBOUNDP 'PARSE-CONNECTIONS)
                           (PARSE-CONNECTIONS . #7=(ARGS PREFIX BINDINGS))
                           (LET ((#8=#:VAL326 PARSE-CONNECTIONS))
                             (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                                   (T (ERROR #6# 'PARSE-CONNECTIONS)))))))
                  (LET ((MODULE-DEF
                         (IF (FBOUNDP 'GET-MODULE)
                             (GET-MODULE . #9=(TYPE))
                             (LET ((#10=#:VAL327 GET-MODULE))
                               (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                                     ((TYPEP #10# . #3#) (GET #10# . #9#))
                                     ((TYPEP #10# . #4#) (NTH #10# . #9#))
                                     ((TYPEP #10# . #5#) (GET #10# . #9#))
                                     (T (ERROR #6# 'GET-MODULE)))))))
                    (LET ((PRIMITIVE-FACTORY
                           (IF (FBOUNDP 'GET-PRIMITIVE)
                               (GET-PRIMITIVE . #11=(TYPE))
                               (LET ((#12=#:VAL328 GET-PRIMITIVE))
                                 (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                                       ((TYPEP #12# . #3#) (GET #12# . #11#))
                                       ((TYPEP #12# . #4#) (NTH #12# . #11#))
                                       ((TYPEP #12# . #5#) (GET #12# . #11#))
                                       (T (ERROR #6# 'GET-PRIMITIVE)))))))
                      (IF (TRUTHY? MODULE-DEF)
                          (LET ((BODY
                                 (IF (FBOUNDP 'MODULE-BODY)
                                     (MODULE-BODY . #13=(MODULE-DEF))
                                     (LET ((#14=#:VAL329 MODULE-BODY))
                                       (COND
                                        ((FUNCTIONP #14#)
                                         (FUNCALL #14# . #13#))
                                        ((TYPEP #14# . #3#) (GET #14# . #13#))
                                        ((TYPEP #14# . #4#) (NTH #14# . #13#))
                                        ((TYPEP #14# . #5#) (GET #14# . #13#))
                                        (T (ERROR #6# 'MODULE-BODY)))))))
                            (REDUCE
                             (LAMBDA (ACC CHILD-SPEC)
                               (DECLARE (SPECIAL EXPAND-SPEC))
                               (CONCAT ACC
                                       (IF (FBOUNDP 'EXPAND-SPEC)
                                           (EXPAND-SPEC
                                            . #15=(CHILD-SPEC FULL-NAME
                                                   RESOLVED-CONNS))
                                           (LET ((#16=#:VAL330 EXPAND-SPEC))
                                             (COND
                                              ((FUNCTIONP #16#)
                                               (FUNCALL #16# . #15#))
                                              (T (ERROR #6# 'EXPAND-SPEC)))))))
                             (VECTOR) BODY))
                          (IF (TRUTHY? PRIMITIVE-FACTORY)
                              (VECTOR
                               (LET ((#17=#:OP331 PRIMITIVE-FACTORY))
                                 (COND
                                  ((FUNCTIONP #17#)
                                   (FUNCALL #17# FULL-NAME PARAM
                                            RESOLVED-CONNS))
                                  (T
                                   (ERROR
                                    "Value ~S is not callable or a collection"
                                    #17#)))))
                              (IF (TRUTHY? :ELSE)
                                  (VECTOR
                                   (MAKE '<COMPONENT> :NAME FULL-NAME :TYPE
                                         TYPE :CONNECTIONS RESOLVED-CONNS))
                                  NIL))))))))))))))

(DEFUN EXPAND-NETLIST (TOP-MODULE-NAME)
  (DECLARE (SPECIAL MODULE-BODY MODULE-PORTS GET-MODULE))
  (LET ((DEF
         (IF (FBOUNDP 'GET-MODULE)
             (GET-MODULE . #1=(TOP-MODULE-NAME))
             (LET ((#2=#:VAL332 GET-MODULE))
               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                     ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                     ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                     ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                     (T
                      (ERROR #6="~S is not a function or collection"
                             'GET-MODULE)))))))
    (IF (TRUTHY? (NIL? DEF))
        (ERROR (STR "Module " TOP-MODULE-NAME " not found"))
        (LET ((TOP-BINDINGS
               (REDUCE (LAMBDA (ACC P) (ASSOC ACC (FIND-KEYWORD P) P)) (DICT)
                       (IF (FBOUNDP 'MODULE-PORTS)
                           (MODULE-PORTS . #7=(DEF))
                           (LET ((#8=#:VAL333 MODULE-PORTS))
                             (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                                   ((TYPEP #8# . #3#) (GET #8# . #7#))
                                   ((TYPEP #8# . #4#) (NTH #8# . #7#))
                                   ((TYPEP #8# . #5#) (GET #8# . #7#))
                                   (T (ERROR #6# 'MODULE-PORTS))))))))
          (REDUCE
           (LAMBDA (ACC SPEC)
             (DECLARE (SPECIAL EXPAND-SPEC))
             (CONCAT ACC
                     (IF (FBOUNDP 'EXPAND-SPEC)
                         (EXPAND-SPEC . #9=(SPEC NIL TOP-BINDINGS))
                         (LET ((#10=#:VAL334 EXPAND-SPEC))
                           (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                                 (T (ERROR #6# 'EXPAND-SPEC)))))))
           (VECTOR)
           (IF (FBOUNDP 'MODULE-BODY)
               (MODULE-BODY . #11=(DEF))
               (LET ((#12=#:VAL335 MODULE-BODY))
                 (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                       ((TYPEP #12# . #3#) (GET #12# . #11#))
                       ((TYPEP #12# . #4#) (NTH #12# . #11#))
                       ((TYPEP #12# . #5#) (GET #12# . #11#))
                       (T (ERROR #6# 'MODULE-BODY))))))))))

(DEFUN REGISTER-CONNECTIVITY (COMP MAP)
  (DECLARE (SPECIAL COMPONENT-INPUTS))
  (REDUCE
   (LAMBDA (ACC PORT)
     (DECLARE (SPECIAL COMPONENT-CONNECTIONS))
     (LET ((NODE
            (GET
             (IF (FBOUNDP 'COMPONENT-CONNECTIONS)
                 (COMPONENT-CONNECTIONS . #1=(COMP))
                 (LET ((#2=#:VAL336 COMPONENT-CONNECTIONS))
                   (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                         ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                         ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                         ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                         (T
                          (ERROR #6="~S is not a function or collection"
                                 'COMPONENT-CONNECTIONS)))))
             PORT)))
       (UPDATE ACC NODE
               (LAMBDA (COMPS)
                 (CONJ
                  (IF (TRUTHY? COMPS)
                      COMPS
                      (VECTOR))
                  COMP)))))
   MAP
   (COLLECTION-SEQ
    (IF (FBOUNDP 'COMPONENT-INPUTS)
        (COMPONENT-INPUTS . #7=(COMP))
        (LET ((#8=#:VAL337 COMPONENT-INPUTS))
          (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                ((TYPEP #8# . #3#) (GET #8# . #7#))
                ((TYPEP #8# . #4#) (NTH #8# . #7#))
                ((TYPEP #8# . #5#) (GET #8# . #7#))
                (T (ERROR #6# 'COMPONENT-INPUTS))))))))

(DEFUN MERGE-EVENTS (QUEUE NEW-EVENTS)
  (SORT-BY :TIME (CONCAT QUEUE NEW-EVENTS)))

(DEFUN GET-INPUT-STATES (COMP NODE-VALUES)
  (DECLARE (SPECIAL COMPONENT-INPUTS))
  (REDUCE
   (LAMBDA (ACC PORT)
     (DECLARE (SPECIAL COMPONENT-CONNECTIONS))
     (LET ((NODE
            (GET
             (IF (FBOUNDP 'COMPONENT-CONNECTIONS)
                 (COMPONENT-CONNECTIONS . #1=(COMP))
                 (LET ((#2=#:VAL338 COMPONENT-CONNECTIONS))
                   (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                         ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                         ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                         ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                         (T
                          (ERROR #6="~S is not a function or collection"
                                 'COMPONENT-CONNECTIONS)))))
             PORT)))
       (ASSOC ACC PORT (GET NODE-VALUES NODE 0))))
   (DICT)
   (IF (FBOUNDP 'COMPONENT-INPUTS)
       (COMPONENT-INPUTS . #7=(COMP))
       (LET ((#8=#:VAL339 COMPONENT-INPUTS))
         (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
               ((TYPEP #8# . #3#) (GET #8# . #7#))
               ((TYPEP #8# . #4#) (NTH #8# . #7#))
               ((TYPEP #8# . #5#) (GET #8# . #7#))
               (T (ERROR #6# 'COMPONENT-INPUTS)))))))

(DEFUN GET-CHANGED-PORTS (COMP CHANGED-NODES)
  (DECLARE (SPECIAL COMPONENT-INPUTS))
  (FILTER
   (LAMBDA (PORT)
     (DECLARE (SPECIAL COMPONENT-CONNECTIONS))
     (LET ((NODE
            (GET
             (IF (FBOUNDP 'COMPONENT-CONNECTIONS)
                 (COMPONENT-CONNECTIONS . #1=(COMP))
                 (LET ((#2=#:VAL340 COMPONENT-CONNECTIONS))
                   (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                         ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                         ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                         ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                         (T
                          (ERROR #6="~S is not a function or collection"
                                 'COMPONENT-CONNECTIONS)))))
             PORT)))
       (CONTAINS? CHANGED-NODES NODE)))
   (IF (FBOUNDP 'COMPONENT-INPUTS)
       (COMPONENT-INPUTS . #7=(COMP))
       (LET ((#8=#:VAL341 COMPONENT-INPUTS))
         (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
               ((TYPEP #8# . #3#) (GET #8# . #7#))
               ((TYPEP #8# . #4#) (NTH #8# . #7#))
               ((TYPEP #8# . #5#) (GET #8# . #7#))
               (T (ERROR #6# 'COMPONENT-INPUTS)))))))

(DEFUN RUN-SIMULATION (NETLIST INITIAL-EVENTS MAX-TIME MONITORED-NODES)
  (DECLARE (SPECIAL MERGE-EVENTS PREDUCE))
  (LET ((CONNECTIVITY
         (REDUCE
          (LAMBDA (ACC C)
            (DECLARE (SPECIAL REGISTER-CONNECTIVITY))
            (IF (FBOUNDP 'REGISTER-CONNECTIVITY)
                (REGISTER-CONNECTIVITY . #1=(C ACC))
                (LET ((#2=#:VAL342 REGISTER-CONNECTIVITY))
                  (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                        ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                        ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                        ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                        (T
                         (ERROR #6="~S is not a function or collection"
                                'REGISTER-CONNECTIVITY))))))
          (DICT) NETLIST)))
    (BLOCK LOOP-BLOCK-4
      (LET ((QUEUE (SORT-BY :TIME INITIAL-EVENTS))
            (NODE-VALUES (DICT))
            (EVENT-HISTORY (DICT))
            (CURRENT-TIME 0))
        (TAGBODY
         LOOP-4
          (LET ((RESULT-4
                 (PROGN
                  (IF (TRUTHY? (OR (EMPTY? QUEUE) (> CURRENT-TIME MAX-TIME)))
                      EVENT-HISTORY
                      (LET ((EVENT-TIME (GET (FIRST QUEUE) :TIME)))
                        (LET ((BATCH
                               (TAKE-WHILE
                                (LAMBDA (X) (= (GET X :TIME) EVENT-TIME))
                                QUEUE)))
                          (LET ((REMAINING
                                 (DROP-WHILE
                                  (LAMBDA (X) (= (GET X :TIME) EVENT-TIME))
                                  QUEUE)))
                            (LET ((UPDATES
                                   (REDUCE
                                    (LAMBDA (ACC EVT)
                                      (ASSOC ACC (GET EVT :NODE)
                                             (GET EVT :VALUE)))
                                    (DICT) BATCH)))
                              (LET ((NEW-NODE-VALUES
                                     (MERGE NODE-VALUES UPDATES)))
                                (LET ((NEW-EVENT-HISTORY
                                       (REDUCE
                                        (LAMBDA (ACC EVT)
                                          (LET ((NODE (GET EVT :NODE)))
                                            (IF (TRUTHY?
                                                 (CONTAINS? MONITORED-NODES
                                                            NODE))
                                                (UPDATE ACC NODE
                                                        (LAMBDA (EVTS)
                                                          (CONJ
                                                           (IF (TRUTHY? EVTS)
                                                               EVTS
                                                               (VECTOR))
                                                           EVT)))
                                                ACC)))
                                        EVENT-HISTORY BATCH)))
                                  (LET ((CHANGED-NODES
                                         (REDUCE (LAMBDA (S K) (CONJ S K))
                                                 (SET) (KEYS UPDATES))))
                                    (LET ((AFFECTED-COMPS
                                           (REDUCE
                                            (LAMBDA (ACC NODE)
                                              (LET ((COMPS
                                                     (GET CONNECTIVITY NODE)))
                                                (REDUCE
                                                 (LAMBDA (A C) (CONJ A C)) ACC
                                                 COMPS)))
                                            (SET) CHANGED-NODES)))
                                      (LET ((NEW-EVENTS
                                             (IF (FBOUNDP 'PREDUCE)
                                                 (PREDUCE
                                                  . #7=((LAMBDA (&REST ARGS)
                                                          (DECLARE
                                                           (SPECIAL
                                                            COMPUTE-NEXT-STATE
                                                            GET-CHANGED-PORTS
                                                            GET-INPUT-STATES))
                                                          (COND
                                                           ((COMMON-LISP:=
                                                             (LENGTH ARGS) 0)
                                                            (LET ()
                                                              (VECTOR)))
                                                           ((COMMON-LISP:=
                                                             (LENGTH ARGS) 2)
                                                            (LET ((ACC
                                                                   (COMMON-LISP:NTH
                                                                    0 ARGS))
                                                                  (COMP
                                                                   (COMMON-LISP:NTH
                                                                    1 ARGS)))
                                                              (LET ((INPUT-STATES
                                                                     (IF (FBOUNDP
                                                                          'GET-INPUT-STATES)
                                                                         (GET-INPUT-STATES
                                                                          . #8=(COMP
                                                                                NEW-NODE-VALUES))
                                                                         (LET ((#9=#:VAL343
                                                                                GET-INPUT-STATES))
                                                                           (COND
                                                                            ((FUNCTIONP
                                                                              #9#)
                                                                             (FUNCALL
                                                                              #9#
                                                                              . #8#))
                                                                            ((TYPEP
                                                                              #9#
                                                                              . #3#)
                                                                             (GET
                                                                              #9#
                                                                              . #8#))
                                                                            ((TYPEP
                                                                              #9#
                                                                              . #4#)
                                                                             (NTH
                                                                              #9#
                                                                              . #8#))
                                                                            ((TYPEP
                                                                              #9#
                                                                              . #5#)
                                                                             (GET
                                                                              #9#
                                                                              . #8#))
                                                                            (T
                                                                             (ERROR
                                                                              #6#
                                                                              'GET-INPUT-STATES)))))))
                                                                (LET ((CHANGED-PORTS
                                                                       (IF (FBOUNDP
                                                                            'GET-CHANGED-PORTS)
                                                                           (GET-CHANGED-PORTS
                                                                            . #10=(COMP
                                                                                   CHANGED-NODES))
                                                                           (LET ((#11=#:VAL344
                                                                                  GET-CHANGED-PORTS))
                                                                             (COND
                                                                              ((FUNCTIONP
                                                                                #11#)
                                                                               (FUNCALL
                                                                                #11#
                                                                                . #10#))
                                                                              ((TYPEP
                                                                                #11#
                                                                                . #3#)
                                                                               (GET
                                                                                #11#
                                                                                . #10#))
                                                                              ((TYPEP
                                                                                #11#
                                                                                . #4#)
                                                                               (NTH
                                                                                #11#
                                                                                . #10#))
                                                                              ((TYPEP
                                                                                #11#
                                                                                . #5#)
                                                                               (GET
                                                                                #11#
                                                                                . #10#))
                                                                              (T
                                                                               (ERROR
                                                                                #6#
                                                                                'GET-CHANGED-PORTS)))))))
                                                                  (LET ((RESULTS
                                                                         (IF (FBOUNDP
                                                                              'COMPUTE-NEXT-STATE)
                                                                             (COMPUTE-NEXT-STATE
                                                                              . #12=(COMP
                                                                                     INPUT-STATES
                                                                                     CHANGED-PORTS))
                                                                             (LET ((#13=#:VAL345
                                                                                    COMPUTE-NEXT-STATE))
                                                                               (COND
                                                                                ((FUNCTIONP
                                                                                  #13#)
                                                                                 (FUNCALL
                                                                                  #13#
                                                                                  . #12#))
                                                                                (T
                                                                                 (ERROR
                                                                                  #6#
                                                                                  'COMPUTE-NEXT-STATE)))))))
                                                                    (REDUCE
                                                                     (LAMBDA
                                                                         (A
                                                                          RES)
                                                                       (DECLARE
                                                                        (SPECIAL
                                                                         COMPONENT-CONNECTIONS))
                                                                       (LET ((OUT-NODE
                                                                              (GET
                                                                               (IF (FBOUNDP
                                                                                    'COMPONENT-CONNECTIONS)
                                                                                   (COMPONENT-CONNECTIONS
                                                                                    . #14=(COMP))
                                                                                   (LET ((#15=#:VAL346
                                                                                          COMPONENT-CONNECTIONS))
                                                                                     (COND
                                                                                      ((FUNCTIONP
                                                                                        #15#)
                                                                                       (FUNCALL
                                                                                        #15#
                                                                                        . #14#))
                                                                                      ((TYPEP
                                                                                        #15#
                                                                                        . #3#)
                                                                                       (GET
                                                                                        #15#
                                                                                        . #14#))
                                                                                      ((TYPEP
                                                                                        #15#
                                                                                        . #4#)
                                                                                       (NTH
                                                                                        #15#
                                                                                        . #14#))
                                                                                      ((TYPEP
                                                                                        #15#
                                                                                        . #5#)
                                                                                       (GET
                                                                                        #15#
                                                                                        . #14#))
                                                                                      (T
                                                                                       (ERROR
                                                                                        #6#
                                                                                        'COMPONENT-CONNECTIONS)))))
                                                                               (GET
                                                                                RES
                                                                                :PORT))))
                                                                         (LET ((CURRENT-VAL
                                                                                (GET
                                                                                 NEW-NODE-VALUES
                                                                                 OUT-NODE
                                                                                 -1)))
                                                                           (IF (TRUTHY?
                                                                                (/=
                                                                                 (GET
                                                                                  RES
                                                                                  :VALUE)
                                                                                 CURRENT-VAL))
                                                                               (CONJ
                                                                                A
                                                                                (DICT
                                                                                 :NODE
                                                                                 OUT-NODE
                                                                                 :VALUE
                                                                                 (GET
                                                                                  RES
                                                                                  :VALUE)
                                                                                 :TIME
                                                                                 (+
                                                                                  EVENT-TIME
                                                                                  (GET
                                                                                   RES
                                                                                   :DELAY))))
                                                                               A))))
                                                                     ACC
                                                                     RESULTS))))))
                                                           (T
                                                            (ERROR
                                                             "No matching fn clause for ~D arguments: ~S"
                                                             (LENGTH ARGS)
                                                             ARGS))))
                                                        (VECTOR) AFFECTED-COMPS
                                                        10000))
                                                 (LET ((#16=#:VAL347 PREDUCE))
                                                   (COND
                                                    ((FUNCTIONP #16#)
                                                     (FUNCALL #16# . #7#))
                                                    (T
                                                     (ERROR #6# 'PREDUCE)))))))
                                        (PROGN
                                         (PSETQ QUEUE
                                                  (IF (FBOUNDP 'MERGE-EVENTS)
                                                      (MERGE-EVENTS
                                                       . #17=(REMAINING
                                                              NEW-EVENTS))
                                                      (LET ((#18=#:VAL348
                                                             MERGE-EVENTS))
                                                        (COND
                                                         ((FUNCTIONP #18#)
                                                          (FUNCALL #18#
                                                                   . #17#))
                                                         ((TYPEP #18# . #3#)
                                                          (GET #18# . #17#))
                                                         ((TYPEP #18# . #4#)
                                                          (NTH #18# . #17#))
                                                         ((TYPEP #18# . #5#)
                                                          (GET #18# . #17#))
                                                         (T
                                                          (ERROR #6#
                                                                 'MERGE-EVENTS)))))
                                                NODE-VALUES NEW-NODE-VALUES
                                                EVENT-HISTORY NEW-EVENT-HISTORY
                                                CURRENT-TIME EVENT-TIME)
                                         (GO LOOP-4)))))))))))))))
            (RETURN-FROM LOOP-BLOCK-4 RESULT-4)))))))

(DEFVAR *SIM-MONITORED* (ATOM (SET)))

(DEFVAR *SIM-EVENTS* (ATOM (VECTOR)))

(DEFVAR *SIM-HISTORY* (ATOM (DICT)))

(DEFUN MONITOR (&REST NODES)
  (DECLARE (SPECIAL *SIM-MONITORED*))
  (SWAP! *SIM-MONITORED*
         (LAMBDA (S) (REDUCE (LAMBDA (ACC N) (CONJ ACC N)) S NODES))))

(DEFUN ADDEVENTS (&REST EVENTS)
  (DECLARE (SPECIAL *SIM-EVENTS*))
  (SWAP! *SIM-EVENTS*
         (LAMBDA (E)
           (DECLARE (SPECIAL MERGE-EVENTS))
           (IF (FBOUNDP 'MERGE-EVENTS)
               (MERGE-EVENTS . #1=(E EVENTS))
               (LET ((#2=#:VAL349 MERGE-EVENTS))
                 (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                       ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                       ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                       ((TYPEP #2# '<SET>) (GET #2# . #1#))
                       (T
                        (ERROR "~S is not a function or collection"
                               'MERGE-EVENTS))))))))

(DEFUN RUNLSIM (MODULE-NAME TIME)
  (DECLARE
   (SPECIAL RUN-SIMULATION *SIM-MONITORED* *SIM-EVENTS* *SIM-HISTORY*
    EXPAND-NETLIST))
  (LET ((NETLIST
         (IF (FBOUNDP 'EXPAND-NETLIST)
             (EXPAND-NETLIST . #1=(MODULE-NAME))
             (LET ((#2=#:VAL350 EXPAND-NETLIST))
               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                     ((TYPEP #2# '<DICT>) (GET #2# . #1#))
                     ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
                     ((TYPEP #2# '<SET>) (GET #2# . #1#))
                     (T
                      (ERROR #3="~S is not a function or collection"
                             'EXPAND-NETLIST)))))))
    (PROGN
     (RESET! *SIM-HISTORY*
             (IF (FBOUNDP 'RUN-SIMULATION)
                 (RUN-SIMULATION
                  . #4=(NETLIST (DEREF *SIM-EVENTS*) TIME
                        (DEREF *SIM-MONITORED*)))
                 (LET ((#5=#:VAL351 RUN-SIMULATION))
                   (COND ((FUNCTIONP #5#) (FUNCALL #5# . #4#))
                         (T (ERROR #3# 'RUN-SIMULATION))))))
     :SIMULATION-COMPLETE)))

(DEFUN DISPLAYLSIM () (DECLARE (SPECIAL *SIM-HISTORY*)) (DEREF *SIM-HISTORY*))
