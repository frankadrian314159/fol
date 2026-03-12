;;; Transpiled from lsim-pq.fol
(in-package :fol.core)

(DEFPACKAGE "LSIM"
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
           DISPLAYLSIM
           *GATE-EVALS*
           *LAST-NETLIST-MS*
           *LAST-SIM-MS*))

(IN-PACKAGE "LSIM")

(DEFVAR *CIRCUIT-MODULES* (ATOM (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT)))

(DEFVAR *GATE-EVALS* (ATOM 0))

(DEFVAR *LAST-NETLIST-MS* (ATOM 0))

(DEFVAR *LAST-SIM-MS* (ATOM 0))

(DEFUN REGISTER-MODULE (NAME DEF)
  (DECLARE (SPECIAL *CIRCUIT-MODULES*))
  (FOL.COMPILER.MUTABLE:SWAP! *CIRCUIT-MODULES*
                              (LAMBDA (M) (ASSOC M NAME DEF))))

(DEFUN GET-MODULE (NAME)
  (DECLARE (SPECIAL *CIRCUIT-MODULES*))
  (GET (FOL.COMPILER.MUTABLE:DEREF *CIRCUIT-MODULES*) NAME))

(DEFCLASS <COMPONENT> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME) (TYPE :INITARG :TYPE)
           (CONNECTIONS :INITARG :CONNECTIONS))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<COMPONENT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'MAKE-INSTANCE '<COMPONENT> . #1#))

'<COMPONENT>

(DEFUN COMPONENT-NAME (OBJ) (GET OBJ :NAME))

(DEFUN COMPONENT-TYPE (OBJ) (GET OBJ :TYPE))

(DEFUN COMPONENT-CONNECTIONS (OBJ) (GET OBJ :CONNECTIONS))

(DEFCLASS <MODULE-DEF> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME) (PORTS :INITARG :PORTS) (BODY :INITARG :BODY))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<MODULE-DEF> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'MAKE-INSTANCE '<MODULE-DEF> . #1#))

'<MODULE-DEF>

(DEFUN MODULE-NAME (OBJ) (GET OBJ :NAME))

(DEFUN MODULE-PORTS (OBJ) (GET OBJ :PORTS))

(DEFUN MODULE-BODY (OBJ) (GET OBJ :BODY))

(DEFCLASS <LOGIC-COMPONENT>
          (<COMPONENT> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((INPUTS :INITARG :INPUTS) (OUTPUTS :INITARG :OUTPUTS)
           (DELAYS :INITARG :DELAYS) (LOGIC-FN :INITARG :LOGIC-FN))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN FOL.CORE::MAKE-<LOGIC-COMPONENT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'MAKE-INSTANCE '<LOGIC-COMPONENT> . #1#))

'<LOGIC-COMPONENT>

(DEFUN COMPONENT-INPUTS (OBJ) (GET OBJ :INPUTS))

(DEFUN COMPONENT-OUTPUTS (OBJ) (GET OBJ :OUTPUTS))

(DEFUN COMPONENT-DELAYS (OBJ) (GET OBJ :DELAYS))

(DEFUN COMPONENT-LOGIC-FN (OBJ) (GET OBJ :LOGIC-FN))

(DEFUN COMPUTE-NEXT-STATE (COMP INPUT-STATES CHANGED-INPUTS)
  (LET ((LOGIC-FN (COMPONENT-LOGIC-FN COMP)))
    (LET ((DELAYS (COMPONENT-DELAYS COMP)))
      (LET ((NEW-STATES
             (LET ((#1=#:OP241 LOGIC-FN))
               (COND ((FUNCTIONP #1#) (FUNCALL #1# . #2=(INPUT-STATES)))
                     ((TYPEP #1# 'FOL.COMPILER.COLLECTIONS:<DICT>)
                      (FOL.COMPILER.COLLECTIONS:GET #1# . #2#))
                     ((TYPEP #1# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #1# . #2#))
                     ((TYPEP #1# 'FOL.COMPILER.COLLECTIONS:<SET>)
                      (FOL.COMPILER.COLLECTIONS:GET #1# . #2#))
                     (T
                      (ERROR "Value ~S is not callable or a collection"
                             #1#))))))
        (MAP
         (LAMBDA (OUT-PORT)
           (LET ((DELAY
                  (REDUCE
                   (LAMBDA (MAX-D IN-PORT)
                     (LET ((D (GET (GET DELAYS IN-PORT) OUT-PORT)))
                       (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? D)
                           (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (> D MAX-D))
                               D
                               MAX-D)
                           MAX-D)))
                   0 CHANGED-INPUTS)))
             (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :PORT OUT-PORT :DELAY
                                                     DELAY :VALUE
                                                     (GET NEW-STATES
                                                          OUT-PORT))))
         (COMPONENT-OUTPUTS COMP))))))

(DEFVAR *PRIMITIVES* (ATOM (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT)))

(DEFUN REGISTER-PRIMITIVE (NAME FACTORY)
  (DECLARE (SPECIAL *PRIMITIVES*))
  (FOL.COMPILER.MUTABLE:SWAP! *PRIMITIVES* (LAMBDA (P) (ASSOC P NAME FACTORY))))

(DEFUN GET-PRIMITIVE (TYPE)
  (DECLARE (SPECIAL *PRIMITIVES*))
  (GET (FOL.COMPILER.MUTABLE:DEREF *PRIMITIVES*) TYPE))

(REGISTER-PRIMITIVE 'NOT
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'NOT :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN) :OUTPUTS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 1))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITXOR))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITXOR)
                                                            (BITXOR
                                                             . #2=((GET S :IN)
                                                                   1))
                                                            (LET ((#3=#:VAL242
                                                                   BITXOR))
                                                              (COND
                                                               ((FUNCTIONP #3#)
                                                                (FUNCALL #3#
                                                                         . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<DICT>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<SET>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               (T
                                                                (ERROR
                                                                 #4="~S is not a function or collection"
                                                                 'BITXOR)))))))))
       (LET ((#5=#:VAL243 MAKE))
         (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#)) (T (ERROR #4# 'MAKE)))))))

(REGISTER-PRIMITIVE 'NAND
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'NAND :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN1 :IN2)
              :OUTPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN1
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 2)
                                                      :IN2
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 2))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITXOR BITAND))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITXOR)
                                                            (BITXOR
                                                             . #2=((IF (FBOUNDP
                                                                        'BITAND)
                                                                       (BITAND
                                                                        . #3=((GET
                                                                               S
                                                                               :IN1)
                                                                              (GET
                                                                               S
                                                                               :IN2)))
                                                                       (LET ((#4=#:VAL244
                                                                              BITAND))
                                                                         (COND
                                                                          ((FUNCTIONP
                                                                            #4#)
                                                                           (FUNCALL
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #5=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                                           (FOL.COMPILER.COLLECTIONS:GET
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #6=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #7=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                                           (FOL.COMPILER.COLLECTIONS:GET
                                                                            #4#
                                                                            . #3#))
                                                                          (T
                                                                           (ERROR
                                                                            #8="~S is not a function or collection"
                                                                            'BITAND)))))
                                                                   1))
                                                            (LET ((#9=#:VAL245
                                                                   BITXOR))
                                                              (COND
                                                               ((FUNCTIONP #9#)
                                                                (FUNCALL #9#
                                                                         . #2#))
                                                               ((TYPEP #9#
                                                                       . #5#)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #9# . #2#))
                                                               ((TYPEP #9#
                                                                       . #6#)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #9# . #2#))
                                                               ((TYPEP #9#
                                                                       . #7#)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #9# . #2#))
                                                               (T
                                                                (ERROR #8#
                                                                       'BITXOR)))))))))
       (LET ((#10=#:VAL246 MAKE))
         (COND ((FUNCTIONP #10#) (FUNCALL #10# . #1#))
               (T (ERROR #8# 'MAKE)))))))

(REGISTER-PRIMITIVE 'NOR
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'NOR :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN1 :IN2)
              :OUTPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN1
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 2)
                                                      :IN2
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 2))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITXOR BITOR))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITXOR)
                                                            (BITXOR
                                                             . #2=((IF (FBOUNDP
                                                                        'BITOR)
                                                                       (BITOR
                                                                        . #3=((GET
                                                                               S
                                                                               :IN1)
                                                                              (GET
                                                                               S
                                                                               :IN2)))
                                                                       (LET ((#4=#:VAL247
                                                                              BITOR))
                                                                         (COND
                                                                          ((FUNCTIONP
                                                                            #4#)
                                                                           (FUNCALL
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #5=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                                           (FOL.COMPILER.COLLECTIONS:GET
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #6=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #7=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                                           (FOL.COMPILER.COLLECTIONS:GET
                                                                            #4#
                                                                            . #3#))
                                                                          (T
                                                                           (ERROR
                                                                            #8="~S is not a function or collection"
                                                                            'BITOR)))))
                                                                   1))
                                                            (LET ((#9=#:VAL248
                                                                   BITXOR))
                                                              (COND
                                                               ((FUNCTIONP #9#)
                                                                (FUNCALL #9#
                                                                         . #2#))
                                                               ((TYPEP #9#
                                                                       . #5#)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #9# . #2#))
                                                               ((TYPEP #9#
                                                                       . #6#)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #9# . #2#))
                                                               ((TYPEP #9#
                                                                       . #7#)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #9# . #2#))
                                                               (T
                                                                (ERROR #8#
                                                                       'BITXOR)))))))))
       (LET ((#10=#:VAL249 MAKE))
         (COND ((FUNCTIONP #10#) (FUNCALL #10# . #1#))
               (T (ERROR #8# 'MAKE)))))))

(REGISTER-PRIMITIVE 'AND
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'AND :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN1 :IN2)
              :OUTPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN1
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 3)
                                                      :IN2
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 3))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITAND))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITAND)
                                                            (BITAND
                                                             . #2=((GET S :IN1)
                                                                   (GET S
                                                                        :IN2)))
                                                            (LET ((#3=#:VAL250
                                                                   BITAND))
                                                              (COND
                                                               ((FUNCTIONP #3#)
                                                                (FUNCALL #3#
                                                                         . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<DICT>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<SET>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               (T
                                                                (ERROR
                                                                 #4="~S is not a function or collection"
                                                                 'BITAND)))))))))
       (LET ((#5=#:VAL251 MAKE))
         (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#)) (T (ERROR #4# 'MAKE)))))))

(REGISTER-PRIMITIVE 'OR
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'OR :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN1 :IN2)
              :OUTPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN1
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 3)
                                                      :IN2
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 3))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITOR))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITOR)
                                                            (BITOR
                                                             . #2=((GET S :IN1)
                                                                   (GET S
                                                                        :IN2)))
                                                            (LET ((#3=#:VAL252
                                                                   BITOR))
                                                              (COND
                                                               ((FUNCTIONP #3#)
                                                                (FUNCALL #3#
                                                                         . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<DICT>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<SET>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               (T
                                                                (ERROR
                                                                 #4="~S is not a function or collection"
                                                                 'BITOR)))))))))
       (LET ((#5=#:VAL253 MAKE))
         (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#)) (T (ERROR #4# 'MAKE)))))))

(REGISTER-PRIMITIVE 'XOR
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'XOR :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN1 :IN2)
              :OUTPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN1
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 3)
                                                      :IN2
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 3))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITXOR))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITXOR)
                                                            (BITXOR
                                                             . #2=((GET S :IN1)
                                                                   (GET S
                                                                        :IN2)))
                                                            (LET ((#3=#:VAL254
                                                                   BITXOR))
                                                              (COND
                                                               ((FUNCTIONP #3#)
                                                                (FUNCALL #3#
                                                                         . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<DICT>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #3# . #2#))
                                                               ((TYPEP #3#
                                                                       'FOL.COMPILER.COLLECTIONS:<SET>)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #3# . #2#))
                                                               (T
                                                                (ERROR
                                                                 #4="~S is not a function or collection"
                                                                 'BITXOR)))))))))
       (LET ((#5=#:VAL255 MAKE))
         (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#)) (T (ERROR #4# 'MAKE)))))))

(REGISTER-PRIMITIVE 'XNOR
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (IF (FBOUNDP 'MAKE)
       (MAKE
        . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'XNOR :CONNECTIONS CONNS
              :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN1 :IN2)
              :OUTPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
              (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN1
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 4)
                                                      :IN2
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                       :OUT 4))
              :LOGIC-FN
              (LAMBDA (S)
                (DECLARE (SPECIAL BITXOR))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT
                                                        (IF (FBOUNDP 'BITXOR)
                                                            (BITXOR
                                                             . #2=((IF (FBOUNDP
                                                                        'BITXOR)
                                                                       (BITXOR
                                                                        . #3=((GET
                                                                               S
                                                                               :IN1)
                                                                              (GET
                                                                               S
                                                                               :IN2)))
                                                                       (LET ((#4=#:VAL256
                                                                              BITXOR))
                                                                         (COND
                                                                          ((FUNCTIONP
                                                                            #4#)
                                                                           (FUNCALL
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #5=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                                           (FOL.COMPILER.COLLECTIONS:GET
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #6=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                            #4#
                                                                            . #3#))
                                                                          ((TYPEP
                                                                            #4#
                                                                            . #7=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                                           (FOL.COMPILER.COLLECTIONS:GET
                                                                            #4#
                                                                            . #3#))
                                                                          (T
                                                                           (ERROR
                                                                            #8="~S is not a function or collection"
                                                                            'BITXOR)))))
                                                                   1))
                                                            (LET ((#9=#:VAL257
                                                                   BITXOR))
                                                              (COND
                                                               ((FUNCTIONP #9#)
                                                                (FUNCALL #9#
                                                                         . #2#))
                                                               ((TYPEP #9#
                                                                       . #5#)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #9# . #2#))
                                                               ((TYPEP #9#
                                                                       . #6#)
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #9# . #2#))
                                                               ((TYPEP #9#
                                                                       . #7#)
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #9# . #2#))
                                                               (T
                                                                (ERROR #8#
                                                                       'BITXOR)))))))))
       (LET ((#10=#:VAL258 MAKE))
         (COND ((FUNCTIONP #10#) (FUNCALL #10# . #1#))
               (T (ERROR #8# 'MAKE)))))))

(REGISTER-PRIMITIVE 'DELAY
 (LAMBDA (NAME PARAM CONNS)
   (DECLARE (SPECIAL MAKE))
   (LET ((D
          (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? PARAM)
              PARAM
              0)))
     (IF (FBOUNDP 'MAKE)
         (MAKE
          . #1=('<LOGIC-COMPONENT> :NAME NAME :TYPE 'DELAY :CONNECTIONS CONNS
                :INPUTS (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :IN) :OUTPUTS
                (FOL.COMPILER.COLLECTION-FUNCTIONS:SET :OUT) :DELAYS
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :IN
                                                        (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                         :OUT D))
                :LOGIC-FN
                (LAMBDA (S)
                  (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :OUT (GET S :IN)))))
         (LET ((#2=#:VAL259 MAKE))
           (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                 (T (ERROR "~S is not a function or collection" 'MAKE))))))))

(DEFUN QUALIFY-NAME (PREFIX NAME)
  (DECLARE (SPECIAL STR NIL?))
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
       (IF (FBOUNDP 'NIL?)
           (NIL? . #1=(PREFIX))
           (LET ((#2=#:VAL260 NIL?))
             (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                   ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<DICT>)
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                   ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<SET>)
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   (T
                    (ERROR #3="~S is not a function or collection" 'NIL?))))))
      NAME
      (SYMBOL
       (IF (FBOUNDP 'STR)
           (STR . #4=(PREFIX "/" NAME))
           (LET ((#5=#:VAL261 STR))
             (COND ((FUNCTIONP #5#) (FUNCALL #5# . #4#))
                   (T (ERROR #3# 'STR))))))))

(DEFUN RESOLVE-NODE (NODE-SYM PREFIX BINDINGS)
  (DECLARE (SPECIAL CONTAINS? FIND-KEYWORD))
  (LET ((KW
         (IF (FBOUNDP 'FIND-KEYWORD)
             (FIND-KEYWORD . #1=(NODE-SYM))
             (LET ((#2=#:VAL262 FIND-KEYWORD))
               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                     ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                      (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                     ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                     ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                      (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                     (T
                      (ERROR #6="~S is not a function or collection"
                             'FIND-KEYWORD)))))))
    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
         (IF (FBOUNDP 'CONTAINS?)
             (CONTAINS? . #7=(BINDINGS KW))
             (LET ((#8=#:VAL263 CONTAINS?))
               (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                     ((TYPEP #8# . #3#)
                      (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                     ((TYPEP #8# . #4#)
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
                     ((TYPEP #8# . #5#)
                      (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                     (T (ERROR #6# 'CONTAINS?))))))
        (GET BINDINGS KW)
        (QUALIFY-NAME PREFIX NODE-SYM))))

(DEFUN PARSE-CONNECTIONS (ARGS PREFIX BINDINGS)
  (DECLARE (SPECIAL EMPTY?))
  (BLOCK LOOP-BLOCK-1
    (LET ((REM ARGS) (ACC (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT)))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (PROGN
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                     (IF (FBOUNDP 'EMPTY?)
                         (EMPTY? . #1=(REM))
                         (LET ((#2=#:VAL264 EMPTY?))
                           (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                 ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<DICT>)
                                  (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                                 ((TYPEP #2#
                                         'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                  (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2#
                                                                         . #1#))
                                 ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<SET>)
                                  (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                                 (T
                                  (ERROR "~S is not a function or collection"
                                         'EMPTY?))))))
                    ACC
                    (LET ((PORT (FIRST REM)))
                      (LET ((NODE-SYM (SECOND REM)))
                        (LET ((RESOLVED
                               (RESOLVE-NODE NODE-SYM PREFIX BINDINGS)))
                          (PROGN
                           (PSETQ REM (REST (REST REM))
                                  ACC (ASSOC ACC PORT RESOLVED))
                           (GO LOOP-1)))))))))
          (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))

(DEFUN EXPAND-SPEC (SPEC PREFIX BINDINGS)
  (DECLARE (SPECIAL MAKE <KEYWORD>? EMPTY?))
  (LET ((TYPE (FIRST SPEC)))
    (LET ((NAME (SECOND SPEC)))
      (LET ((RAW-ARGS (REST (REST SPEC))))
        (LET ((HAS-PARAM?
               (AND
                (NOT
                 (IF (FBOUNDP 'EMPTY?)
                     (EMPTY? . #1=(RAW-ARGS))
                     (LET ((#2=#:VAL265 EMPTY?))
                       (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                             ((TYPEP #2#
                                     . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                              (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                             ((TYPEP #2#
                                     . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                              (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2#
                                                                     . #1#))
                             ((TYPEP #2#
                                     . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                              (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                             (T
                              (ERROR #6="~S is not a function or collection"
                                     'EMPTY?))))))
                (NOT
                 (IF (FBOUNDP '<KEYWORD>?)
                     (<KEYWORD>? . #7=((FIRST RAW-ARGS)))
                     (LET ((#8=#:VAL266 <KEYWORD>?))
                       (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                             ((TYPEP #8# . #3#)
                              (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                             ((TYPEP #8# . #4#)
                              (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8#
                                                                     . #7#))
                             ((TYPEP #8# . #5#)
                              (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                             (T (ERROR #6# '<KEYWORD>?)))))))))
          (LET ((PARAM
                 (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? HAS-PARAM?)
                     (FIRST RAW-ARGS)
                     NIL)))
            (LET ((ARGS
                   (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? HAS-PARAM?)
                       (REST RAW-ARGS)
                       RAW-ARGS)))
              (LET ((FULL-NAME (QUALIFY-NAME PREFIX NAME)))
                (LET ((RESOLVED-CONNS (PARSE-CONNECTIONS ARGS PREFIX BINDINGS)))
                  (LET ((MODULE-DEF (GET-MODULE TYPE)))
                    (LET ((PRIMITIVE-FACTORY (GET-PRIMITIVE TYPE)))
                      (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? MODULE-DEF)
                          (LET ((BODY (MODULE-BODY MODULE-DEF)))
                            (REDUCE
                             (LAMBDA (ACC CHILD-SPEC)
                               (DECLARE (SPECIAL CONCAT EXPAND-SPEC))
                               (IF (FBOUNDP 'CONCAT)
                                   (CONCAT
                                    . #9=(ACC
                                          (IF (FBOUNDP 'EXPAND-SPEC)
                                              (EXPAND-SPEC
                                               . #10=(CHILD-SPEC FULL-NAME
                                                      RESOLVED-CONNS))
                                              (LET ((#11=#:VAL267 EXPAND-SPEC))
                                                (COND
                                                 ((FUNCTIONP #11#)
                                                  (FUNCALL #11# . #10#))
                                                 (T
                                                  (ERROR #6#
                                                         'EXPAND-SPEC)))))))
                                   (LET ((#12=#:VAL268 CONCAT))
                                     (COND
                                      ((FUNCTIONP #12#) (FUNCALL #12# . #9#))
                                      ((TYPEP #12# . #3#)
                                       (FOL.COMPILER.COLLECTIONS:GET #12#
                                                                     . #9#))
                                      ((TYPEP #12# . #4#)
                                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                        #12# . #9#))
                                      ((TYPEP #12# . #5#)
                                       (FOL.COMPILER.COLLECTIONS:GET #12#
                                                                     . #9#))
                                      (T (ERROR #6# 'CONCAT))))))
                             (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR) BODY))
                          (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                               PRIMITIVE-FACTORY)
                              (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                               (LET ((#13=#:OP269 PRIMITIVE-FACTORY))
                                 (COND
                                  ((FUNCTIONP #13#)
                                   (FUNCALL #13# FULL-NAME PARAM
                                            RESOLVED-CONNS))
                                  (T
                                   (ERROR
                                    "Value ~S is not callable or a collection"
                                    #13#)))))
                              (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? :ELSE)
                                  (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                                   (IF (FBOUNDP 'MAKE)
                                       (MAKE
                                        . #14=('<COMPONENT> :NAME FULL-NAME
                                               :TYPE TYPE :CONNECTIONS
                                               RESOLVED-CONNS))
                                       (LET ((#15=#:VAL270 MAKE))
                                         (COND
                                          ((FUNCTIONP #15#)
                                           (FUNCALL #15# . #14#))
                                          (T (ERROR #6# 'MAKE))))))
                                  NIL))))))))))))))

(DEFUN EXPAND-NETLIST (TOP-MODULE-NAME)
  (DECLARE (SPECIAL STR NIL?))
  (LET ((DEF (GET-MODULE TOP-MODULE-NAME)))
    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
         (IF (FBOUNDP 'NIL?)
             (NIL? . #1=(DEF))
             (LET ((#2=#:VAL271 NIL?))
               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                     ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                      (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                     ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                     ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                      (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                     (T
                      (ERROR #6="~S is not a function or collection"
                             'NIL?))))))
        (ERROR
         (IF (FBOUNDP 'STR)
             (STR . #7=("Module " TOP-MODULE-NAME " not found"))
             (LET ((#8=#:VAL272 STR))
               (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                     (T (ERROR #6# 'STR))))))
        (LET ((TOP-BINDINGS
               (REDUCE
                (LAMBDA (ACC P)
                  (DECLARE (SPECIAL FIND-KEYWORD))
                  (ASSOC ACC
                         (IF (FBOUNDP 'FIND-KEYWORD)
                             (FIND-KEYWORD . #9=(P))
                             (LET ((#10=#:VAL273 FIND-KEYWORD))
                               (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                                     ((TYPEP #10# . #3#)
                                      (FOL.COMPILER.COLLECTIONS:GET #10#
                                                                    . #9#))
                                     ((TYPEP #10# . #4#)
                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                       #10# . #9#))
                                     ((TYPEP #10# . #5#)
                                      (FOL.COMPILER.COLLECTIONS:GET #10#
                                                                    . #9#))
                                     (T (ERROR #6# 'FIND-KEYWORD)))))
                         P))
                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT) (MODULE-PORTS DEF))))
          (REDUCE
           (LAMBDA (ACC SPEC)
             (DECLARE (SPECIAL CONCAT))
             (IF (FBOUNDP 'CONCAT)
                 (CONCAT . #11=(ACC (EXPAND-SPEC SPEC NIL TOP-BINDINGS)))
                 (LET ((#12=#:VAL274 CONCAT))
                   (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                         ((TYPEP #12# . #3#)
                          (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                         ((TYPEP #12# . #4#)
                          (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #12# . #11#))
                         ((TYPEP #12# . #5#)
                          (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                         (T (ERROR #6# 'CONCAT))))))
           (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR) (MODULE-BODY DEF))))))

(DEFUN REGISTER-CONNECTIVITY (COMP MAP)
  (DECLARE (SPECIAL COLLECTION-SEQ))
  (REDUCE
   (LAMBDA (ACC PORT)
     (DECLARE (SPECIAL UPDATE))
     (LET ((NODE (GET (COMPONENT-CONNECTIONS COMP) PORT)))
       (IF (FBOUNDP 'UPDATE)
           (UPDATE
            . #1=(ACC NODE
                  (LAMBDA (COMPS)
                    (DECLARE (SPECIAL CONJ))
                    (IF (FBOUNDP 'CONJ)
                        (CONJ
                         . #2=((IF (FOL.COMPILER.PRIMITIVES:TRUTHY? COMPS)
                                   COMPS
                                   (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR))
                               COMP))
                        (LET ((#3=#:VAL275 CONJ))
                          (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                                ((TYPEP #3#
                                        . #4=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                 (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
                                ((TYPEP #3#
                                        . #5=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #3#
                                                                        . #2#))
                                ((TYPEP #3#
                                        . #6=('FOL.COMPILER.COLLECTIONS:<SET>))
                                 (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
                                (T
                                 (ERROR #7="~S is not a function or collection"
                                        'CONJ))))))))
           (LET ((#8=#:VAL276 UPDATE))
             (COND ((FUNCTIONP #8#) (FUNCALL #8# . #1#))
                   (T (ERROR #7# 'UPDATE)))))))
   MAP
   (IF (FBOUNDP 'COLLECTION-SEQ)
       (COLLECTION-SEQ . #9=((COMPONENT-INPUTS COMP)))
       (LET ((#10=#:VAL277 COLLECTION-SEQ))
         (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
               ((TYPEP #10# . #4#) (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
               ((TYPEP #10# . #5#)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #10# . #9#))
               ((TYPEP #10# . #6#) (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
               (T (ERROR #7# 'COLLECTION-SEQ)))))))

(DEFUN LH-RANK (H)
  (DECLARE (SPECIAL NIL?))
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
       (IF (FBOUNDP 'NIL?)
           (NIL? . #1=(H))
           (LET ((#2=#:VAL278 NIL?))
             (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                   ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<DICT>)
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                   ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<SET>)
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   (T (ERROR "~S is not a function or collection" 'NIL?))))))
      0
      (GET H :RANK)))

(DEFUN LH-MAKE-NODE (E LEFT RIGHT)
  (DECLARE (SPECIAL INC))
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (>= (LH-RANK LEFT) (LH-RANK RIGHT)))
      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :ELEM E :RIGHT RIGHT :LEFT LEFT
                                              :RANK
                                              (IF (FBOUNDP 'INC)
                                                  (INC . #1=((LH-RANK RIGHT)))
                                                  (LET ((#2=#:VAL279 INC))
                                                    (COND
                                                     ((FUNCTIONP #2#)
                                                      (FUNCALL #2# . #1#))
                                                     ((TYPEP #2#
                                                             . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                      (FOL.COMPILER.COLLECTIONS:GET
                                                       #2# . #1#))
                                                     ((TYPEP #2#
                                                             . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                       #2# . #1#))
                                                     ((TYPEP #2#
                                                             . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                      (FOL.COMPILER.COLLECTIONS:GET
                                                       #2# . #1#))
                                                     (T
                                                      (ERROR
                                                       #6="~S is not a function or collection"
                                                       'INC))))))
      (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :ELEM E :RIGHT LEFT :LEFT RIGHT
                                              :RANK
                                              (IF (FBOUNDP 'INC)
                                                  (INC . #7=((LH-RANK LEFT)))
                                                  (LET ((#8=#:VAL280 INC))
                                                    (COND
                                                     ((FUNCTIONP #8#)
                                                      (FUNCALL #8# . #7#))
                                                     ((TYPEP #8# . #3#)
                                                      (FOL.COMPILER.COLLECTIONS:GET
                                                       #8# . #7#))
                                                     ((TYPEP #8# . #4#)
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                       #8# . #7#))
                                                     ((TYPEP #8# . #5#)
                                                      (FOL.COMPILER.COLLECTIONS:GET
                                                       #8# . #7#))
                                                     (T (ERROR #6# 'INC))))))))

(DEFUN LH-MERGE (H1 H2)
  (DECLARE (SPECIAL LH-MERGE NIL?))
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
       (IF (FBOUNDP 'NIL?)
           (NIL? . #1=(H1))
           (LET ((#2=#:VAL281 NIL?))
             (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                   ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                   ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   (T
                    (ERROR #6="~S is not a function or collection" 'NIL?))))))
      H2
      (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
           (IF (FBOUNDP 'NIL?)
               (NIL? . #7=(H2))
               (LET ((#8=#:VAL282 NIL?))
                 (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                       ((TYPEP #8# . #3#)
                        (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                       ((TYPEP #8# . #4#)
                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
                       ((TYPEP #8# . #5#)
                        (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                       (T (ERROR #6# 'NIL?))))))
          H1
          (LET ((E1 (GET H1 :ELEM)))
            (LET ((E2 (GET H2 :ELEM)))
              (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                   (<= (GET E1 :TIME) (GET E2 :TIME)))
                  (LH-MAKE-NODE E1 (GET H1 :LEFT)
                   (IF (FBOUNDP 'LH-MERGE)
                       (LH-MERGE . #9=((GET H1 :RIGHT) H2))
                       (LET ((#10=#:VAL283 LH-MERGE))
                         (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                               ((TYPEP #10# . #3#)
                                (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                               ((TYPEP #10# . #4#)
                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #10#
                                                                       . #9#))
                               ((TYPEP #10# . #5#)
                                (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                               (T (ERROR #6# 'LH-MERGE))))))
                  (LH-MAKE-NODE E2 (GET H2 :LEFT)
                   (IF (FBOUNDP 'LH-MERGE)
                       (LH-MERGE . #11=(H1 (GET H2 :RIGHT)))
                       (LET ((#12=#:VAL284 LH-MERGE))
                         (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                               ((TYPEP #12# . #3#)
                                (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                               ((TYPEP #12# . #4#)
                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #12#
                                                                       . #11#))
                               ((TYPEP #12# . #5#)
                                (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                               (T (ERROR #6# 'LH-MERGE))))))))))))

(DEFUN LH-INSERT (H EVENT)
  (LH-MERGE
   (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :ELEM EVENT :RIGHT NIL :LEFT NIL
                                           :RANK 1)
   H))

(DEFUN LH-PEEK (H) (GET H :ELEM))

(DEFUN LH-POP (H) (LH-MERGE (GET H :LEFT) (GET H :RIGHT)))

(DEFUN LH-POP-BATCH (H)
  (DECLARE (SPECIAL CONJ NIL?))
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
       (IF (FBOUNDP 'NIL?)
           (NIL? . #1=(H))
           (LET ((#2=#:VAL285 NIL?))
             (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                   ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                   ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                    (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                   (T
                    (ERROR #6="~S is not a function or collection" 'NIL?))))))
      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR) NIL)
      (LET ((T0 (GET (LH-PEEK H) :TIME)))
        (BLOCK LOOP-BLOCK-2
          (LET ((Q H) (ACC (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR)))
            (TAGBODY
             LOOP-2
              (LET ((RESULT-2
                     (PROGN
                      (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                           (IF (FBOUNDP 'NIL?)
                               (NIL? . #7=(Q))
                               (LET ((#8=#:VAL286 NIL?))
                                 (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                                       ((TYPEP #8# . #3#)
                                        (FOL.COMPILER.COLLECTIONS:GET #8#
                                                                      . #7#))
                                       ((TYPEP #8# . #4#)
                                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                         #8# . #7#))
                                       ((TYPEP #8# . #5#)
                                        (FOL.COMPILER.COLLECTIONS:GET #8#
                                                                      . #7#))
                                       (T (ERROR #6# 'NIL?))))))
                          (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR ACC Q)
                          (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                               (/= (GET (LH-PEEK Q) :TIME) T0))
                              (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR ACC Q)
                              (PROGN
                               (PSETQ Q (LH-POP Q)
                                      ACC
                                        (IF (FBOUNDP 'CONJ)
                                            (CONJ . #9=(ACC (LH-PEEK Q)))
                                            (LET ((#10=#:VAL287 CONJ))
                                              (COND
                                               ((FUNCTIONP #10#)
                                                (FUNCALL #10# . #9#))
                                               ((TYPEP #10# . #3#)
                                                (FOL.COMPILER.COLLECTIONS:GET
                                                 #10# . #9#))
                                               ((TYPEP #10# . #4#)
                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                 #10# . #9#))
                                               ((TYPEP #10# . #5#)
                                                (FOL.COMPILER.COLLECTIONS:GET
                                                 #10# . #9#))
                                               (T (ERROR #6# 'CONJ))))))
                               (GO LOOP-2)))))))
                (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))))

(DEFUN GET-INPUT-STATES (COMP NODE-VALUES)
  (REDUCE
   (LAMBDA (ACC PORT)
     (LET ((NODE (GET (COMPONENT-CONNECTIONS COMP) PORT)))
       (ASSOC ACC PORT (GET NODE-VALUES NODE 0))))
   (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT) (COMPONENT-INPUTS COMP)))

(DEFUN GET-CHANGED-PORTS (COMP CHANGED-NODES)
  (DECLARE (SPECIAL FILTER))
  (IF (FBOUNDP 'FILTER)
      (FILTER
       . #1=((LAMBDA (PORT)
               (DECLARE (SPECIAL CONTAINS?))
               (LET ((NODE (GET (COMPONENT-CONNECTIONS COMP) PORT)))
                 (IF (FBOUNDP 'CONTAINS?)
                     (CONTAINS? . #2=(CHANGED-NODES NODE))
                     (LET ((#3=#:VAL288 CONTAINS?))
                       (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                             ((TYPEP #3#
                                     . #4=('FOL.COMPILER.COLLECTIONS:<DICT>))
                              (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
                             ((TYPEP #3#
                                     . #5=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                              (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #3#
                                                                     . #2#))
                             ((TYPEP #3#
                                     . #6=('FOL.COMPILER.COLLECTIONS:<SET>))
                              (FOL.COMPILER.COLLECTIONS:GET #3# . #2#))
                             (T
                              (ERROR #7="~S is not a function or collection"
                                     'CONTAINS?)))))))
             (COMPONENT-INPUTS COMP)))
      (LET ((#8=#:VAL289 FILTER))
        (COND ((FUNCTIONP #8#) (FUNCALL #8# . #1#))
              ((TYPEP #8# . #4#) (FOL.COMPILER.COLLECTIONS:GET #8# . #1#))
              ((TYPEP #8# . #5#)
               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #1#))
              ((TYPEP #8# . #6#) (FOL.COMPILER.COLLECTIONS:GET #8# . #1#))
              (T (ERROR #7# 'FILTER))))))

(DEFUN RUN-SIMULATION (NETLIST INITIAL-EVENTS MAX-TIME MONITORED-NODES)
  (DECLARE (SPECIAL KEYS NIL?))
  (LET ((CONNECTIVITY
         (REDUCE (LAMBDA (ACC C) (REGISTER-CONNECTIVITY C ACC))
                 (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT) NETLIST)))
    (BLOCK LOOP-BLOCK-3
      (LET ((QUEUE (REDUCE #'LH-INSERT NIL INITIAL-EVENTS))
            (NODE-VALUES (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT))
            (EVENT-HISTORY (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT))
            (CURRENT-TIME 0))
        (TAGBODY
         LOOP-3
          (LET ((RESULT-3
                 (PROGN
                  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                       (OR
                        (IF (FBOUNDP 'NIL?)
                            (NIL? . #1=(QUEUE))
                            (LET ((#2=#:VAL290 NIL?))
                              (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                    ((TYPEP #2#
                                            . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                     (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                                    ((TYPEP #2#
                                            . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                     (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2#
                                                                            . #1#))
                                    ((TYPEP #2#
                                            . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                                     (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                                    (T
                                     (ERROR
                                      #6="~S is not a function or collection"
                                      'NIL?)))))
                        (> CURRENT-TIME MAX-TIME)))
                      EVENT-HISTORY
                      (LET* ((#7=#:MV291
                              (MULTIPLE-VALUE-LIST (LH-POP-BATCH QUEUE)))
                             (#8=#:VAL292
                              (IF (> (LENGTH #7#) 1)
                                  #7#
                                  (CAR #7#)))
                             (#9=#:DESTR293 #8#)
                             (BATCH (ELT #9# 0))
                             (REMAINING (ELT #9# 1)))
                        (LET ((EVENT-TIME (GET (FIRST BATCH) :TIME)))
                          (LET ((UPDATES
                                 (REDUCE
                                  (LAMBDA (ACC EVT)
                                    (ASSOC ACC (GET EVT :NODE)
                                           (GET EVT :VALUE)))
                                  (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT)
                                  BATCH)))
                            (LET ((NEW-NODE-VALUES (MERGE NODE-VALUES UPDATES)))
                              (LET ((NEW-EVENT-HISTORY
                                     (REDUCE
                                      (LAMBDA (ACC EVT)
                                        (DECLARE (SPECIAL UPDATE CONTAINS?))
                                        (LET ((NODE (GET EVT :NODE)))
                                          (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                               (IF (FBOUNDP 'CONTAINS?)
                                                   (CONTAINS?
                                                    . #10=(MONITORED-NODES
                                                           NODE))
                                                   (LET ((#11=#:VAL294
                                                          CONTAINS?))
                                                     (COND
                                                      ((FUNCTIONP #11#)
                                                       (FUNCALL #11# . #10#))
                                                      ((TYPEP #11# . #3#)
                                                       (FOL.COMPILER.COLLECTIONS:GET
                                                        #11# . #10#))
                                                      ((TYPEP #11# . #4#)
                                                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                        #11# . #10#))
                                                      ((TYPEP #11# . #5#)
                                                       (FOL.COMPILER.COLLECTIONS:GET
                                                        #11# . #10#))
                                                      (T
                                                       (ERROR #6#
                                                              'CONTAINS?))))))
                                              (IF (FBOUNDP 'UPDATE)
                                                  (UPDATE
                                                   . #12=(ACC NODE
                                                          (LAMBDA (EVTS)
                                                            (DECLARE
                                                             (SPECIAL CONJ))
                                                            (IF (FBOUNDP 'CONJ)
                                                                (CONJ
                                                                 . #13=((IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                             EVTS)
                                                                            EVTS
                                                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR))
                                                                        EVT))
                                                                (LET ((#14=#:VAL295
                                                                       CONJ))
                                                                  (COND
                                                                   ((FUNCTIONP
                                                                     #14#)
                                                                    (FUNCALL
                                                                     #14#
                                                                     . #13#))
                                                                   ((TYPEP #14#
                                                                           . #3#)
                                                                    (FOL.COMPILER.COLLECTIONS:GET
                                                                     #14#
                                                                     . #13#))
                                                                   ((TYPEP #14#
                                                                           . #4#)
                                                                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                     #14#
                                                                     . #13#))
                                                                   ((TYPEP #14#
                                                                           . #5#)
                                                                    (FOL.COMPILER.COLLECTIONS:GET
                                                                     #14#
                                                                     . #13#))
                                                                   (T
                                                                    (ERROR #6#
                                                                           'CONJ))))))))
                                                  (LET ((#15=#:VAL296 UPDATE))
                                                    (COND
                                                     ((FUNCTIONP #15#)
                                                      (FUNCALL #15# . #12#))
                                                     (T (ERROR #6# 'UPDATE)))))
                                              ACC)))
                                      EVENT-HISTORY BATCH)))
                                (LET ((CHANGED-NODES
                                       (REDUCE
                                        (LAMBDA (S K)
                                          (DECLARE (SPECIAL CONJ))
                                          (IF (FBOUNDP 'CONJ)
                                              (CONJ . #16=(S K))
                                              (LET ((#17=#:VAL297 CONJ))
                                                (COND
                                                 ((FUNCTIONP #17#)
                                                  (FUNCALL #17# . #16#))
                                                 ((TYPEP #17# . #3#)
                                                  (FOL.COMPILER.COLLECTIONS:GET
                                                   #17# . #16#))
                                                 ((TYPEP #17# . #4#)
                                                  (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                   #17# . #16#))
                                                 ((TYPEP #17# . #5#)
                                                  (FOL.COMPILER.COLLECTIONS:GET
                                                   #17# . #16#))
                                                 (T (ERROR #6# 'CONJ))))))
                                        (FOL.COMPILER.COLLECTION-FUNCTIONS:SET)
                                        (IF (FBOUNDP 'KEYS)
                                            (KEYS . #18=(UPDATES))
                                            (LET ((#19=#:VAL298 KEYS))
                                              (COND
                                               ((FUNCTIONP #19#)
                                                (FUNCALL #19# . #18#))
                                               ((TYPEP #19# . #3#)
                                                (FOL.COMPILER.COLLECTIONS:GET
                                                 #19# . #18#))
                                               ((TYPEP #19# . #4#)
                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                 #19# . #18#))
                                               ((TYPEP #19# . #5#)
                                                (FOL.COMPILER.COLLECTIONS:GET
                                                 #19# . #18#))
                                               (T (ERROR #6# 'KEYS))))))))
                                  (LET ((AFFECTED-COMPS
                                         (REDUCE
                                          (LAMBDA (ACC NODE)
                                            (LET ((COMPS
                                                   (GET CONNECTIVITY NODE)))
                                              (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                   COMPS)
                                                  (REDUCE
                                                   (LAMBDA (A C)
                                                     (DECLARE (SPECIAL CONJ))
                                                     (IF (FBOUNDP 'CONJ)
                                                         (CONJ . #20=(A C))
                                                         (LET ((#21=#:VAL299
                                                                CONJ))
                                                           (COND
                                                            ((FUNCTIONP #21#)
                                                             (FUNCALL #21#
                                                                      . #20#))
                                                            ((TYPEP #21# . #3#)
                                                             (FOL.COMPILER.COLLECTIONS:GET
                                                              #21# . #20#))
                                                            ((TYPEP #21# . #4#)
                                                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                              #21# . #20#))
                                                            ((TYPEP #21# . #5#)
                                                             (FOL.COMPILER.COLLECTIONS:GET
                                                              #21# . #20#))
                                                            (T
                                                             (ERROR #6#
                                                                    'CONJ))))))
                                                   ACC COMPS)
                                                  ACC)))
                                          (FOL.COMPILER.COLLECTION-FUNCTIONS:SET)
                                          CHANGED-NODES)))
                                    (LET ((NEW-EVENTS
                                           (REDUCE
                                            (LAMBDA (ACC COMP)
                                              (DECLARE (SPECIAL *GATE-EVALS*))
                                              (PROGN
                                               (FOL.COMPILER.MUTABLE:SWAP!
                                                *GATE-EVALS*
                                                (LAMBDA (N) (+ N 1)))
                                               (LET ((INPUT-STATES
                                                      (GET-INPUT-STATES COMP
                                                       NEW-NODE-VALUES)))
                                                 (LET ((CHANGED-PORTS
                                                        (GET-CHANGED-PORTS COMP
                                                         CHANGED-NODES)))
                                                   (LET ((RESULTS
                                                          (COMPUTE-NEXT-STATE
                                                           COMP INPUT-STATES
                                                           CHANGED-PORTS)))
                                                     (REDUCE
                                                      (LAMBDA (A RES)
                                                        (DECLARE
                                                         (SPECIAL CONJ))
                                                        (LET ((OUT-NODE
                                                               (GET
                                                                (COMPONENT-CONNECTIONS
                                                                 COMP)
                                                                (GET RES
                                                                     :PORT))))
                                                          (LET ((CURRENT-VAL
                                                                 (GET
                                                                  NEW-NODE-VALUES
                                                                  OUT-NODE -1)))
                                                            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                 (/=
                                                                  (GET RES
                                                                       :VALUE)
                                                                  CURRENT-VAL))
                                                                (IF (FBOUNDP
                                                                     'CONJ)
                                                                    (CONJ
                                                                     . #22=(A
                                                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT
                                                                             :TIME
                                                                             (+
                                                                              EVENT-TIME
                                                                              (GET
                                                                               RES
                                                                               :DELAY))
                                                                             :VALUE
                                                                             (GET
                                                                              RES
                                                                              :VALUE)
                                                                             :NODE
                                                                             OUT-NODE)))
                                                                    (LET ((#23=#:VAL300
                                                                           CONJ))
                                                                      (COND
                                                                       ((FUNCTIONP
                                                                         #23#)
                                                                        (FUNCALL
                                                                         #23#
                                                                         . #22#))
                                                                       ((TYPEP
                                                                         #23#
                                                                         . #3#)
                                                                        (FOL.COMPILER.COLLECTIONS:GET
                                                                         #23#
                                                                         . #22#))
                                                                       ((TYPEP
                                                                         #23#
                                                                         . #4#)
                                                                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                         #23#
                                                                         . #22#))
                                                                       ((TYPEP
                                                                         #23#
                                                                         . #5#)
                                                                        (FOL.COMPILER.COLLECTIONS:GET
                                                                         #23#
                                                                         . #22#))
                                                                       (T
                                                                        (ERROR
                                                                         #6#
                                                                         'CONJ)))))
                                                                A))))
                                                      ACC RESULTS))))))
                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR)
                                            AFFECTED-COMPS)))
                                      (PROGN
                                       (PSETQ QUEUE
                                                (REDUCE #'LH-INSERT REMAINING
                                                        NEW-EVENTS)
                                              NODE-VALUES NEW-NODE-VALUES
                                              EVENT-HISTORY NEW-EVENT-HISTORY
                                              CURRENT-TIME EVENT-TIME)
                                       (GO LOOP-3))))))))))))))
            (RETURN-FROM LOOP-BLOCK-3 RESULT-3)))))))

(DEFVAR *SIM-MONITORED* (ATOM (FOL.COMPILER.COLLECTION-FUNCTIONS:SET)))

(DEFVAR *SIM-EVENTS* (ATOM (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR)))

(DEFVAR *SIM-HISTORY* (ATOM (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT)))

(DEFUN MONITOR (&REST NODES)
  (DECLARE (SPECIAL *SIM-MONITORED*))
  (FOL.COMPILER.MUTABLE:SWAP! *SIM-MONITORED*
                              (LAMBDA (S)
                                (REDUCE
                                 (LAMBDA (ACC N)
                                   (DECLARE (SPECIAL CONJ))
                                   (IF (FBOUNDP 'CONJ)
                                       (CONJ . #1=(ACC N))
                                       (LET ((#2=#:VAL301 CONJ))
                                         (COND
                                          ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                          ((TYPEP #2#
                                                  'FOL.COMPILER.COLLECTIONS:<DICT>)
                                           (FOL.COMPILER.COLLECTIONS:GET #2#
                                                                         . #1#))
                                          ((TYPEP #2#
                                                  'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                            #2# . #1#))
                                          ((TYPEP #2#
                                                  'FOL.COMPILER.COLLECTIONS:<SET>)
                                           (FOL.COMPILER.COLLECTIONS:GET #2#
                                                                         . #1#))
                                          (T
                                           (ERROR
                                            "~S is not a function or collection"
                                            'CONJ))))))
                                 S NODES))))

(DEFUN ADDEVENTS (&REST EVENTS)
  (DECLARE (SPECIAL *SIM-EVENTS*))
  (FOL.COMPILER.MUTABLE:SWAP! *SIM-EVENTS*
                              (LAMBDA (E)
                                (DECLARE (SPECIAL CONCAT))
                                (IF (FBOUNDP 'CONCAT)
                                    (CONCAT . #1=(E EVENTS))
                                    (LET ((#2=#:VAL302 CONCAT))
                                      (COND
                                       ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                       ((TYPEP #2#
                                               'FOL.COMPILER.COLLECTIONS:<DICT>)
                                        (FOL.COMPILER.COLLECTIONS:GET #2#
                                                                      . #1#))
                                       ((TYPEP #2#
                                               'FOL.COMPILER.COLLECTIONS:<VECTOR>)
                                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                         #2# . #1#))
                                       ((TYPEP #2#
                                               'FOL.COMPILER.COLLECTIONS:<SET>)
                                        (FOL.COMPILER.COLLECTIONS:GET #2#
                                                                      . #1#))
                                       (T
                                        (ERROR
                                         "~S is not a function or collection"
                                         'CONCAT))))))))

(DEFUN %NOW-MS ()
  (* 1000.0
     (/ (GET-INTERNAL-REAL-TIME) (FLOAT INTERNAL-TIME-UNITS-PER-SECOND))))

(DEFUN RUNLSIM (MODULE-NAME TIME)
  (DECLARE
   (SPECIAL *SIM-HISTORY* *LAST-SIM-MS* *SIM-MONITORED* *SIM-EVENTS*
    *LAST-NETLIST-MS* RESET! *GATE-EVALS*))
  (IF (FBOUNDP 'RESET!)
      (RESET! . #1=(*GATE-EVALS* 0))
      (LET ((#2=#:VAL303 RESET!))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
               (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
              ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
              ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
               (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
              (T (ERROR #6="~S is not a function or collection" 'RESET!)))))
  (LET ((T0 (%NOW-MS)))
    (LET ((NETLIST (EXPAND-NETLIST MODULE-NAME)))
      (LET ((T1 (%NOW-MS)))
        (LET ((_
               (IF (FBOUNDP 'RESET!)
                   (RESET! . #7=(*LAST-NETLIST-MS* (- T1 T0)))
                   (LET ((#8=#:VAL304 RESET!))
                     (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                           ((TYPEP #8# . #3#)
                            (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                           ((TYPEP #8# . #4#)
                            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
                           ((TYPEP #8# . #5#)
                            (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                           (T (ERROR #6# 'RESET!)))))))
          (LET ((T2 (%NOW-MS)))
            (LET ((RESULT
                   (RUN-SIMULATION NETLIST
                    (FOL.COMPILER.MUTABLE:DEREF *SIM-EVENTS*) TIME
                    (FOL.COMPILER.MUTABLE:DEREF *SIM-MONITORED*))))
              (LET ((T3 (%NOW-MS)))
                (LET ((_
                       (IF (FBOUNDP 'RESET!)
                           (RESET! . #9=(*LAST-SIM-MS* (- T3 T2)))
                           (LET ((#10=#:VAL305 RESET!))
                             (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                                   ((TYPEP #10# . #3#)
                                    (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                                   ((TYPEP #10# . #4#)
                                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #10#
                                                                           . #9#))
                                   ((TYPEP #10# . #5#)
                                    (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                                   (T (ERROR #6# 'RESET!)))))))
                  (PROGN
                   (IF (FBOUNDP 'RESET!)
                       (RESET! . #11=(*SIM-HISTORY* RESULT))
                       (LET ((#12=#:VAL306 RESET!))
                         (COND ((FUNCTIONP #12#) (FUNCALL #12# . #11#))
                               ((TYPEP #12# . #3#)
                                (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                               ((TYPEP #12# . #4#)
                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #12#
                                                                       . #11#))
                               ((TYPEP #12# . #5#)
                                (FOL.COMPILER.COLLECTIONS:GET #12# . #11#))
                               (T (ERROR #6# 'RESET!)))))
                   :SIMULATION-COMPLETE))))))))))

(DEFUN DISPLAYLSIM ()
  (DECLARE (SPECIAL *SIM-HISTORY*))
  (FOL.COMPILER.MUTABLE:DEREF *SIM-HISTORY*))
