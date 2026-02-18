(in-package :fol.user)

(DEFVAR *CIRCUIT-MODULES* (ATOM (DICT))) 
(DEFUN REGISTER-MODULE (NAME DEF) (SWAP! *CIRCUIT-MODULES* #'ASSOC NAME DEF)) 
(DEFUN GET-MODULE (NAME) (GET (DEREF *CIRCUIT-MODULES*) NAME)) 
(PROGN
 (DEFCLASS <COMPONENT> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
           ((NAME :INITARG :NAME) (TYPE :INITARG :TYPE)
            (CONNECTIONS :INITARG :CONNECTIONS))
           (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))
 (DEFUN COMPONENT-NAME (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT) :NAME))
 (DEFUN COMPONENT-TYPE (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT) :TYPE))
 (DEFUN COMPONENT-CONNECTIONS (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
    :CONNECTIONS))
 (DEFUN MAKE-<COMPONENT> (&KEY NAME TYPE CONNECTIONS)
   (MAKE-INSTANCE '<COMPONENT> :NAME NAME :TYPE TYPE :CONNECTIONS CONNECTIONS))
 '<COMPONENT>) 
(PROGN
 (DEFCLASS <MODULE-DEF> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
           ((NAME :INITARG :NAME) (PORTS :INITARG :PORTS)
            (BODY :INITARG :BODY))
           (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))
 (DEFUN MODULE-NAME (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT) :NAME))
 (DEFUN MODULE-PORTS (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
    :PORTS))
 (DEFUN MODULE-BODY (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT) :BODY))
 (DEFUN MAKE-<MODULE-DEF> (&KEY NAME PORTS BODY)
   (MAKE-INSTANCE '<MODULE-DEF> :NAME NAME :PORTS PORTS :BODY BODY))
 '<MODULE-DEF>) 
(PROGN
 (DEFCLASS <LOGIC-COMPONENT>
           (<COMPONENT> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
           ((INPUTS :INITARG :INPUTS) (OUTPUTS :INITARG :OUTPUTS)
            (DELAYS :INITARG :DELAYS) (LOGIC-FN :INITARG :LOGIC-FN))
           (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))
 (DEFUN COMPONENT-INPUTS (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
    :INPUTS))
 (DEFUN COMPONENT-OUTPUTS (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
    :OUTPUTS))
 (DEFUN COMPONENT-DELAYS (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
    :DELAYS))
 (DEFUN COMPONENT-LOGIC-FN (FOL.COMPILER::OBJECT)
   (SYCAMORE:HASH-MAP-FIND
    (FOL.COMPILER.PERSISTENT::%PERSISTENT-STORAGE FOL.COMPILER::OBJECT)
    :LOGIC-FN))
 (DEFUN MAKE-<LOGIC-COMPONENT> (&KEY INPUTS OUTPUTS DELAYS LOGIC-FN)
   (MAKE-INSTANCE '<LOGIC-COMPONENT> :INPUTS INPUTS :OUTPUTS OUTPUTS :DELAYS
                  DELAYS :LOGIC-FN LOGIC-FN))
 '<LOGIC-COMPONENT>) 
(DEFGENERIC COMPUTE-NEXT-STATE
    (COMP INPUT-STATES CHANGED-INPUTS)) 
(DEFUN COMPUTE-NEXT-STATE (COMP INPUT-STATES CHANGED-INPUTS)
  (COND
   ((TYPEP COMP '<LOGIC-COMPONENT>)
    (LET ((LOGIC-FN
           (IF (FBOUNDP 'COMPONENT-LOGIC-FN)
               (COMPONENT-LOGIC-FN COMP)
               (LET ((#:VAL295 COMPONENT-LOGIC-FN))
                 (COND ((TYPEP #:VAL295 '<DICT>) (GET #:VAL295 COMP))
                       ((TYPEP #:VAL295 '<VECTOR>)
                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL295 COMP))
                       ((TYPEP #:VAL295 '<SET>) (GET #:VAL295 COMP))
                       (T
                        (ERROR "~S is not a function or collection"
                               'COMPONENT-LOGIC-FN)))))))
      (LET ((DELAYS
             (IF (FBOUNDP 'COMPONENT-DELAYS)
                 (COMPONENT-DELAYS COMP)
                 (LET ((#:VAL296 COMPONENT-DELAYS))
                   (COND ((TYPEP #:VAL296 '<DICT>) (GET #:VAL296 COMP))
                         ((TYPEP #:VAL296 '<VECTOR>)
                          (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL296
                                                                 COMP))
                         ((TYPEP #:VAL296 '<SET>) (GET #:VAL296 COMP))
                         (T
                          (ERROR "~S is not a function or collection"
                                 'COMPONENT-DELAYS)))))))
        (LET ((NEW-STATES
               (LET ((#:OP297 LOGIC-FN))
                 (COND ((FUNCTIONP #:OP297) (FUNCALL #:OP297 INPUT-STATES))
                       ((TYPEP #:OP297 '<DICT>) (GET #:OP297 INPUT-STATES))
                       ((TYPEP #:OP297 '<VECTOR>)
                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:OP297
                                                               INPUT-STATES))
                       ((TYPEP #:OP297 '<SET>) (GET #:OP297 INPUT-STATES))
                       (T
                        (ERROR "Value ~S is not callable or a collection"
                               #:OP297))))))
          (MAP
           (LAMBDA (OUT-PORT)
             (LET ((DELAY
                    (REDUCE
                     (LAMBDA (MAX-D IN-PORT)
                       (LET ((D (GET (GET DELAYS IN-PORT) OUT-PORT)))
                         (IF (TRUTHY? (AND D (> D MAX-D)))
                             D
                             MAX-D)))
                     0 CHANGED-INPUTS)))
               (DICT :VALUE (GET NEW-STATES OUT-PORT) :DELAY DELAY :PORT
                     OUT-PORT)))
           (IF (FBOUNDP 'COMPONENT-OUTPUTS)
               (COMPONENT-OUTPUTS COMP)
               (LET ((#:VAL298 COMPONENT-OUTPUTS))
                 (COND ((TYPEP #:VAL298 '<DICT>) (GET #:VAL298 COMP))
                       ((TYPEP #:VAL298 '<VECTOR>)
                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL298 COMP))
                       ((TYPEP #:VAL298 '<SET>) (GET #:VAL298 COMP))
                       (T
                        (ERROR "~S is not a function or collection"
                               'COMPONENT-OUTPUTS))))))))))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S"
           'COMPUTE-NEXT-STATE
           (COMMON-LISP:LIST COMP INPUT-STATES CHANGED-INPUTS))))) 
(DEFVAR *PRIMITIVES* (ATOM (DICT))) 
(DEFUN REGISTER-PRIMITIVE (NAME FACTORY)
  (SWAP! *PRIMITIVES* #'ASSOC NAME FACTORY)) 
(DEFUN GET-PRIMITIVE (NAME) (GET (DEREF *PRIMITIVES*) NAME)) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'NOT
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOT :CONNECTIONS CONNS :INPUTS
             (SET :IN) :OUTPUTS (SET :OUT) :DELAYS (DICT :IN (DICT :OUT 1))
             :LOGIC-FN (LAMBDA (S) (DICT :OUT (NOT (GET S :IN)))))))
    (LET ((#:VAL299 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL299 '<DICT>)
        (GET #:VAL299 'NOT
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOT :CONNECTIONS CONNS
                     :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN (DICT :OUT 1)) :LOGIC-FN
                     (LAMBDA (S) (DICT :OUT (NOT (GET S :IN))))))))
       ((TYPEP #:VAL299 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL299 'NOT
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'NOT
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN (DICT :OUT 1))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (DICT :OUT
                                                               (NOT
                                                                (GET S
                                                                     :IN))))))))
       ((TYPEP #:VAL299 '<SET>)
        (GET #:VAL299 'NOT
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOT :CONNECTIONS CONNS
                     :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN (DICT :OUT 1)) :LOGIC-FN
                     (LAMBDA (S) (DICT :OUT (NOT (GET S :IN))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'NAND
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NAND :CONNECTIONS CONNS
             :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
             (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
             (LAMBDA (S) (DICT :OUT (NOT (AND (GET S :IN1) (GET S :IN2))))))))
    (LET ((#:VAL300 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL300 '<DICT>)
        (GET #:VAL300 'NAND
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NAND :CONNECTIONS
                     CONNS :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (NOT (AND (GET S :IN1) (GET S :IN2)))))))))
       ((TYPEP #:VAL300 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL300 'NAND
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'NAND
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN2 :IN1)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN2 (DICT :OUT 2)
                                                             :IN1
                                                             (DICT :OUT 2))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (DICT :OUT
                                                               (NOT
                                                                (AND
                                                                 (GET S :IN1)
                                                                 (GET S
                                                                      :IN2)))))))))
       ((TYPEP #:VAL300 '<SET>)
        (GET #:VAL300 'NAND
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NAND :CONNECTIONS
                     CONNS :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (NOT (AND (GET S :IN1) (GET S :IN2)))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'NOR
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOR :CONNECTIONS CONNS :INPUTS
             (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
             (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
             (LAMBDA (S) (DICT :OUT (NOT (OR (GET S :IN1) (GET S :IN2))))))))
    (LET ((#:VAL301 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL301 '<DICT>)
        (GET #:VAL301 'NOR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOR :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (NOT (OR (GET S :IN1) (GET S :IN2)))))))))
       ((TYPEP #:VAL301 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL301 'NOR
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'NOR
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN2 :IN1)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN2 (DICT :OUT 2)
                                                             :IN1
                                                             (DICT :OUT 2))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (DICT :OUT
                                                               (NOT
                                                                (OR
                                                                 (GET S :IN1)
                                                                 (GET S
                                                                      :IN2)))))))))
       ((TYPEP #:VAL301 '<SET>)
        (GET #:VAL301 'NOR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOR :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 2) :IN1 (DICT :OUT 2)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (NOT (OR (GET S :IN1) (GET S :IN2)))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'AND
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'AND :CONNECTIONS CONNS :INPUTS
             (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
             (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
             (LAMBDA (S) (DICT :OUT (AND (GET S :IN1) (GET S :IN2)))))))
    (LET ((#:VAL302 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL302 '<DICT>)
        (GET #:VAL302 'AND
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'AND :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (AND (GET S :IN1) (GET S :IN2))))))))
       ((TYPEP #:VAL302 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL302 'AND
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'AND
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN2 :IN1)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN2 (DICT :OUT 3)
                                                             :IN1
                                                             (DICT :OUT 3))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (DICT :OUT
                                                               (AND
                                                                (GET S :IN1)
                                                                (GET S
                                                                     :IN2))))))))
       ((TYPEP #:VAL302 '<SET>)
        (GET #:VAL302 'AND
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'AND :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (AND (GET S :IN1) (GET S :IN2))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'OR
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'OR :CONNECTIONS CONNS :INPUTS
             (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
             (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
             (LAMBDA (S) (DICT :OUT (OR (GET S :IN1) (GET S :IN2)))))))
    (LET ((#:VAL303 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL303 '<DICT>)
        (GET #:VAL303 'OR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'OR :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (OR (GET S :IN1) (GET S :IN2))))))))
       ((TYPEP #:VAL303 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL303 'OR
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'OR
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN2 :IN1)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN2 (DICT :OUT 3)
                                                             :IN1
                                                             (DICT :OUT 3))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (DICT :OUT
                                                               (OR (GET S :IN1)
                                                                   (GET S
                                                                        :IN2))))))))
       ((TYPEP #:VAL303 '<SET>)
        (GET #:VAL303 'OR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'OR :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                     (LAMBDA (S)
                       (DICT :OUT (OR (GET S :IN1) (GET S :IN2))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'XOR
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XOR :CONNECTIONS CONNS :INPUTS
             (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
             (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
             (LAMBDA (S)
               (LET ((A (GET S :IN1)))
                 (LET ((B (GET S :IN2)))
                   (DICT :OUT (OR (AND A (NOT B)) (AND (NOT A) B)))))))))
    (LET ((#:VAL304 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL304 '<DICT>)
        (GET #:VAL304 'XOR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XOR :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                     (LAMBDA (S)
                       (LET ((A (GET S :IN1)))
                         (LET ((B (GET S :IN2)))
                           (DICT :OUT
                                 (OR (AND A (NOT B)) (AND (NOT A) B))))))))))
       ((TYPEP #:VAL304 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL304 'XOR
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'XOR
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN2 :IN1)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN2 (DICT :OUT 3)
                                                             :IN1
                                                             (DICT :OUT 3))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (LET ((A (GET S :IN1)))
                                                           (LET ((B
                                                                  (GET S :IN2)))
                                                             (DICT :OUT
                                                                   (OR
                                                                    (AND A
                                                                         (NOT
                                                                          B))
                                                                    (AND
                                                                     (NOT A)
                                                                     B))))))))))
       ((TYPEP #:VAL304 '<SET>)
        (GET #:VAL304 'XOR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XOR :CONNECTIONS CONNS
                     :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 3) :IN1 (DICT :OUT 3)) :LOGIC-FN
                     (LAMBDA (S)
                       (LET ((A (GET S :IN1)))
                         (LET ((B (GET S :IN2)))
                           (DICT :OUT
                                 (OR (AND A (NOT B)) (AND (NOT A) B))))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'XNOR
     (LAMBDA (NAME PARAM CONNS)
       (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XNOR :CONNECTIONS CONNS
             :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
             (DICT :IN2 (DICT :OUT 4) :IN1 (DICT :OUT 4)) :LOGIC-FN
             (LAMBDA (S)
               (LET ((A (GET S :IN1)))
                 (LET ((B (GET S :IN2)))
                   (DICT :OUT (NOT (OR (AND A (NOT B)) (AND (NOT A) B))))))))))
    (LET ((#:VAL305 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL305 '<DICT>)
        (GET #:VAL305 'XNOR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XNOR :CONNECTIONS
                     CONNS :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 4) :IN1 (DICT :OUT 4)) :LOGIC-FN
                     (LAMBDA (S)
                       (LET ((A (GET S :IN1)))
                         (LET ((B (GET S :IN2)))
                           (DICT :OUT
                                 (NOT
                                  (OR (AND A (NOT B)) (AND (NOT A) B)))))))))))
       ((TYPEP #:VAL305 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL305 'XNOR
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (MAKE <LOGIC-COMPONENT> :NAME
                                                       NAME :TYPE 'XNOR
                                                       :CONNECTIONS CONNS
                                                       :INPUTS (SET :IN2 :IN1)
                                                       :OUTPUTS (SET :OUT)
                                                       :DELAYS
                                                       (DICT :IN2 (DICT :OUT 4)
                                                             :IN1
                                                             (DICT :OUT 4))
                                                       :LOGIC-FN
                                                       (LAMBDA (S)
                                                         (LET ((A (GET S :IN1)))
                                                           (LET ((B
                                                                  (GET S :IN2)))
                                                             (DICT :OUT
                                                                   (NOT
                                                                    (OR
                                                                     (AND A
                                                                          (NOT
                                                                           B))
                                                                     (AND
                                                                      (NOT A)
                                                                      B)))))))))))
       ((TYPEP #:VAL305 '<SET>)
        (GET #:VAL305 'XNOR
             (LAMBDA (NAME PARAM CONNS)
               (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XNOR :CONNECTIONS
                     CONNS :INPUTS (SET :IN2 :IN1) :OUTPUTS (SET :OUT) :DELAYS
                     (DICT :IN2 (DICT :OUT 4) :IN1 (DICT :OUT 4)) :LOGIC-FN
                     (LAMBDA (S)
                       (LET ((A (GET S :IN1)))
                         (LET ((B (GET S :IN2)))
                           (DICT :OUT
                                 (NOT
                                  (OR (AND A (NOT B)) (AND (NOT A) B)))))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(IF (FBOUNDP 'REGISTER-PRIMITIVE)
    (REGISTER-PRIMITIVE 'DELAY
     (LAMBDA (NAME PARAM CONNS)
       (LET ((D (OR PARAM 0)))
         (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'DELAY :CONNECTIONS CONNS
               :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
               (DICT :IN (DICT :OUT D)) :LOGIC-FN
               (LAMBDA (S) (DICT :OUT (GET S :IN)))))))
    (LET ((#:VAL306 REGISTER-PRIMITIVE))
      (COND
       ((TYPEP #:VAL306 '<DICT>)
        (GET #:VAL306 'DELAY
             (LAMBDA (NAME PARAM CONNS)
               (LET ((D (OR PARAM 0)))
                 (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'DELAY :CONNECTIONS
                       CONNS :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
                       (DICT :IN (DICT :OUT D)) :LOGIC-FN
                       (LAMBDA (S) (DICT :OUT (GET S :IN))))))))
       ((TYPEP #:VAL306 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL306 'DELAY
                                               (LAMBDA (NAME PARAM CONNS)
                                                 (LET ((D (OR PARAM 0)))
                                                   (MAKE <LOGIC-COMPONENT>
                                                         :NAME NAME :TYPE
                                                         'DELAY :CONNECTIONS
                                                         CONNS :INPUTS
                                                         (SET :IN) :OUTPUTS
                                                         (SET :OUT) :DELAYS
                                                         (DICT :IN
                                                               (DICT :OUT D))
                                                         :LOGIC-FN
                                                         (LAMBDA (S)
                                                           (DICT :OUT
                                                                 (GET S
                                                                      :IN))))))))
       ((TYPEP #:VAL306 '<SET>)
        (GET #:VAL306 'DELAY
             (LAMBDA (NAME PARAM CONNS)
               (LET ((D (OR PARAM 0)))
                 (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'DELAY :CONNECTIONS
                       CONNS :INPUTS (SET :IN) :OUTPUTS (SET :OUT) :DELAYS
                       (DICT :IN (DICT :OUT D)) :LOGIC-FN
                       (LAMBDA (S) (DICT :OUT (GET S :IN))))))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-PRIMITIVE))))) 
(DEFMACRO DEFPART (NAME PORTS &BODY BODY)
  '(REGISTER-MODULE 'NAME
    (MAKE <MODULE-DEF> :NAME 'NAME :PORTS 'PORTS :BODY 'BODY))) 
(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE 'SR-LATCH
     (MAKE '<MODULE-DEF> :NAME 'SR-LATCH :PORTS '(R S Q QBAR) :BODY
           '((NAND NAND1 :IN1 R :IN2 QBAR :OUT Q)
             (NAND NAND2 :IN1 S :IN2 Q :OUT QBAR))))
    (LET ((#:VAL307 REGISTER-MODULE))
      (COND
       ((TYPEP #:VAL307 '<DICT>)
        (GET #:VAL307 'SR-LATCH
             (MAKE '<MODULE-DEF> :NAME 'SR-LATCH :PORTS '(R S Q QBAR) :BODY
                   '((NAND NAND1 :IN1 R :IN2 QBAR :OUT Q)
                     (NAND NAND2 :IN1 S :IN2 Q :OUT QBAR)))))
       ((TYPEP #:VAL307 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL307 'SR-LATCH
                                               (MAKE '<MODULE-DEF> :NAME
                                                     'SR-LATCH :PORTS
                                                     '(R S Q QBAR) :BODY
                                                     '((NAND NAND1 :IN1 R :IN2
                                                        QBAR :OUT Q)
                                                       (NAND NAND2 :IN1 S :IN2
                                                        Q :OUT QBAR)))))
       ((TYPEP #:VAL307 '<SET>)
        (GET #:VAL307 'SR-LATCH
             (MAKE '<MODULE-DEF> :NAME 'SR-LATCH :PORTS '(R S Q QBAR) :BODY
                   '((NAND NAND1 :IN1 R :IN2 QBAR :OUT Q)
                     (NAND NAND2 :IN1 S :IN2 Q :OUT QBAR)))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE))))) 
(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE 'D-LATCH
     (MAKE '<MODULE-DEF> :NAME 'D-LATCH :PORTS '(CLK D Q QBAR) :BODY
           '((NAND NAND1 :IN1 D :IN2 CLK :OUT S)
             (NAND NAND2 :IN1 S :IN2 CLK :OUT R)
             (SR-LATCH LATCH :R R :S S :Q Q :QBAR QBAR))))
    (LET ((#:VAL308 REGISTER-MODULE))
      (COND
       ((TYPEP #:VAL308 '<DICT>)
        (GET #:VAL308 'D-LATCH
             (MAKE '<MODULE-DEF> :NAME 'D-LATCH :PORTS '(CLK D Q QBAR) :BODY
                   '((NAND NAND1 :IN1 D :IN2 CLK :OUT S)
                     (NAND NAND2 :IN1 S :IN2 CLK :OUT R)
                     (SR-LATCH LATCH :R R :S S :Q Q :QBAR QBAR)))))
       ((TYPEP #:VAL308 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL308 'D-LATCH
                                               (MAKE '<MODULE-DEF> :NAME
                                                     'D-LATCH :PORTS
                                                     '(CLK D Q QBAR) :BODY
                                                     '((NAND NAND1 :IN1 D :IN2
                                                        CLK :OUT S)
                                                       (NAND NAND2 :IN1 S :IN2
                                                        CLK :OUT R)
                                                       (SR-LATCH LATCH :R R :S
                                                        S :Q Q :QBAR QBAR)))))
       ((TYPEP #:VAL308 '<SET>)
        (GET #:VAL308 'D-LATCH
             (MAKE '<MODULE-DEF> :NAME 'D-LATCH :PORTS '(CLK D Q QBAR) :BODY
                   '((NAND NAND1 :IN1 D :IN2 CLK :OUT S)
                     (NAND NAND2 :IN1 S :IN2 CLK :OUT R)
                     (SR-LATCH LATCH :R R :S S :Q Q :QBAR QBAR)))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE))))) 
(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE 'REGISTER-32BIT
     (MAKE '<MODULE-DEF> :NAME 'REGISTER-32BIT :PORTS
           '(CLK D0 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12 D13 D14 D15 D16 D17
             D18 D19 D20 D21 D22 D23 D24 D25 D26 D27 D28 D29 D30 D31 Q0 Q1 Q2
             Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10 Q11 Q12 Q13 Q14 Q15 Q16 Q17 Q18 Q19 Q20
             Q21 Q22 Q23 Q24 Q25 Q26 Q27 Q28 Q29 Q30 Q31)
           :BODY
           '((D-LATCH BIT0 :CLK CLK :D D0 :Q Q0 :QBAR QBAR0)
             (D-LATCH BIT1 :CLK CLK :D D1 :Q Q1 :QBAR QBAR1)
             (D-LATCH BIT2 :CLK CLK :D D2 :Q Q2 :QBAR QBAR2)
             (D-LATCH BIT3 :CLK CLK :D D3 :Q Q3 :QBAR QBAR3)
             (D-LATCH BIT4 :CLK CLK :D D4 :Q Q4 :QBAR QBAR4)
             (D-LATCH BIT5 :CLK CLK :D D5 :Q Q5 :QBAR QBAR5)
             (D-LATCH BIT6 :CLK CLK :D D6 :Q Q6 :QBAR QBAR6)
             (D-LATCH BIT7 :CLK CLK :D D7 :Q Q7 :QBAR QBAR7)
             (D-LATCH BIT8 :CLK CLK :D D8 :Q Q8 :QBAR QBAR8)
             (D-LATCH BIT9 :CLK CLK :D D9 :Q Q9 :QBAR QBAR9)
             (D-LATCH BIT10 :CLK CLK :D D10 :Q Q10 :QBAR QBAR10)
             (D-LATCH BIT11 :CLK CLK :D D11 :Q Q11 :QBAR QBAR11)
             (D-LATCH BIT12 :CLK CLK :D D12 :Q Q12 :QBAR QBAR12)
             (D-LATCH BIT13 :CLK CLK :D D13 :Q Q13 :QBAR QBAR13)
             (D-LATCH BIT14 :CLK CLK :D D14 :Q Q14 :QBAR QBAR14)
             (D-LATCH BIT15 :CLK CLK :D D15 :Q Q15 :QBAR QBAR15)
             (D-LATCH BIT16 :CLK CLK :D D16 :Q Q16 :QBAR QBAR16)
             (D-LATCH BIT17 :CLK CLK :D D17 :Q Q17 :QBAR QBAR17)
             (D-LATCH BIT18 :CLK CLK :D D18 :Q Q18 :QBAR QBAR18)
             (D-LATCH BIT19 :CLK CLK :D D19 :Q Q19 :QBAR QBAR19)
             (D-LATCH BIT20 :CLK CLK :D D20 :Q Q20 :QBAR QBAR20)
             (D-LATCH BIT21 :CLK CLK :D D21 :Q Q21 :QBAR QBAR21)
             (D-LATCH BIT22 :CLK CLK :D D22 :Q Q22 :QBAR QBAR22)
             (D-LATCH BIT23 :CLK CLK :D D23 :Q Q23 :QBAR QBAR23)
             (D-LATCH BIT24 :CLK CLK :D D24 :Q Q24 :QBAR QBAR24)
             (D-LATCH BIT25 :CLK CLK :D D25 :Q Q25 :QBAR QBAR25)
             (D-LATCH BIT26 :CLK CLK :D D26 :Q Q26 :QBAR QBAR26)
             (D-LATCH BIT27 :CLK CLK :D D27 :Q Q27 :QBAR QBAR27)
             (D-LATCH BIT28 :CLK CLK :D D28 :Q Q28 :QBAR QBAR28)
             (D-LATCH BIT29 :CLK CLK :D D29 :Q Q29 :QBAR QBAR29)
             (D-LATCH BIT30 :CLK CLK :D D30 :Q Q30 :QBAR QBAR30)
             (D-LATCH BIT31 :CLK CLK :D D31 :Q Q31 :QBAR QBAR31))))
    (LET ((#:VAL309 REGISTER-MODULE))
      (COND
       ((TYPEP #:VAL309 '<DICT>)
        (GET #:VAL309 'REGISTER-32BIT
             (MAKE '<MODULE-DEF> :NAME 'REGISTER-32BIT :PORTS
                   '(CLK D0 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12 D13 D14 D15
                     D16 D17 D18 D19 D20 D21 D22 D23 D24 D25 D26 D27 D28 D29
                     D30 D31 Q0 Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10 Q11 Q12 Q13 Q14
                     Q15 Q16 Q17 Q18 Q19 Q20 Q21 Q22 Q23 Q24 Q25 Q26 Q27 Q28
                     Q29 Q30 Q31)
                   :BODY
                   '((D-LATCH BIT0 :CLK CLK :D D0 :Q Q0 :QBAR QBAR0)
                     (D-LATCH BIT1 :CLK CLK :D D1 :Q Q1 :QBAR QBAR1)
                     (D-LATCH BIT2 :CLK CLK :D D2 :Q Q2 :QBAR QBAR2)
                     (D-LATCH BIT3 :CLK CLK :D D3 :Q Q3 :QBAR QBAR3)
                     (D-LATCH BIT4 :CLK CLK :D D4 :Q Q4 :QBAR QBAR4)
                     (D-LATCH BIT5 :CLK CLK :D D5 :Q Q5 :QBAR QBAR5)
                     (D-LATCH BIT6 :CLK CLK :D D6 :Q Q6 :QBAR QBAR6)
                     (D-LATCH BIT7 :CLK CLK :D D7 :Q Q7 :QBAR QBAR7)
                     (D-LATCH BIT8 :CLK CLK :D D8 :Q Q8 :QBAR QBAR8)
                     (D-LATCH BIT9 :CLK CLK :D D9 :Q Q9 :QBAR QBAR9)
                     (D-LATCH BIT10 :CLK CLK :D D10 :Q Q10 :QBAR QBAR10)
                     (D-LATCH BIT11 :CLK CLK :D D11 :Q Q11 :QBAR QBAR11)
                     (D-LATCH BIT12 :CLK CLK :D D12 :Q Q12 :QBAR QBAR12)
                     (D-LATCH BIT13 :CLK CLK :D D13 :Q Q13 :QBAR QBAR13)
                     (D-LATCH BIT14 :CLK CLK :D D14 :Q Q14 :QBAR QBAR14)
                     (D-LATCH BIT15 :CLK CLK :D D15 :Q Q15 :QBAR QBAR15)
                     (D-LATCH BIT16 :CLK CLK :D D16 :Q Q16 :QBAR QBAR16)
                     (D-LATCH BIT17 :CLK CLK :D D17 :Q Q17 :QBAR QBAR17)
                     (D-LATCH BIT18 :CLK CLK :D D18 :Q Q18 :QBAR QBAR18)
                     (D-LATCH BIT19 :CLK CLK :D D19 :Q Q19 :QBAR QBAR19)
                     (D-LATCH BIT20 :CLK CLK :D D20 :Q Q20 :QBAR QBAR20)
                     (D-LATCH BIT21 :CLK CLK :D D21 :Q Q21 :QBAR QBAR21)
                     (D-LATCH BIT22 :CLK CLK :D D22 :Q Q22 :QBAR QBAR22)
                     (D-LATCH BIT23 :CLK CLK :D D23 :Q Q23 :QBAR QBAR23)
                     (D-LATCH BIT24 :CLK CLK :D D24 :Q Q24 :QBAR QBAR24)
                     (D-LATCH BIT25 :CLK CLK :D D25 :Q Q25 :QBAR QBAR25)
                     (D-LATCH BIT26 :CLK CLK :D D26 :Q Q26 :QBAR QBAR26)
                     (D-LATCH BIT27 :CLK CLK :D D27 :Q Q27 :QBAR QBAR27)
                     (D-LATCH BIT28 :CLK CLK :D D28 :Q Q28 :QBAR QBAR28)
                     (D-LATCH BIT29 :CLK CLK :D D29 :Q Q29 :QBAR QBAR29)
                     (D-LATCH BIT30 :CLK CLK :D D30 :Q Q30 :QBAR QBAR30)
                     (D-LATCH BIT31 :CLK CLK :D D31 :Q Q31 :QBAR QBAR31)))))
       ((TYPEP #:VAL309 '<VECTOR>)
        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL309 'REGISTER-32BIT
                                               (MAKE '<MODULE-DEF> :NAME
                                                     'REGISTER-32BIT :PORTS
                                                     '(CLK D0 D1 D2 D3 D4 D5 D6
                                                       D7 D8 D9 D10 D11 D12 D13
                                                       D14 D15 D16 D17 D18 D19
                                                       D20 D21 D22 D23 D24 D25
                                                       D26 D27 D28 D29 D30 D31
                                                       Q0 Q1 Q2 Q3 Q4 Q5 Q6 Q7
                                                       Q8 Q9 Q10 Q11 Q12 Q13
                                                       Q14 Q15 Q16 Q17 Q18 Q19
                                                       Q20 Q21 Q22 Q23 Q24 Q25
                                                       Q26 Q27 Q28 Q29 Q30 Q31)
                                                     :BODY
                                                     '((D-LATCH BIT0 :CLK CLK
                                                        :D D0 :Q Q0 :QBAR
                                                        QBAR0)
                                                       (D-LATCH BIT1 :CLK CLK
                                                        :D D1 :Q Q1 :QBAR
                                                        QBAR1)
                                                       (D-LATCH BIT2 :CLK CLK
                                                        :D D2 :Q Q2 :QBAR
                                                        QBAR2)
                                                       (D-LATCH BIT3 :CLK CLK
                                                        :D D3 :Q Q3 :QBAR
                                                        QBAR3)
                                                       (D-LATCH BIT4 :CLK CLK
                                                        :D D4 :Q Q4 :QBAR
                                                        QBAR4)
                                                       (D-LATCH BIT5 :CLK CLK
                                                        :D D5 :Q Q5 :QBAR
                                                        QBAR5)
                                                       (D-LATCH BIT6 :CLK CLK
                                                        :D D6 :Q Q6 :QBAR
                                                        QBAR6)
                                                       (D-LATCH BIT7 :CLK CLK
                                                        :D D7 :Q Q7 :QBAR
                                                        QBAR7)
                                                       (D-LATCH BIT8 :CLK CLK
                                                        :D D8 :Q Q8 :QBAR
                                                        QBAR8)
                                                       (D-LATCH BIT9 :CLK CLK
                                                        :D D9 :Q Q9 :QBAR
                                                        QBAR9)
                                                       (D-LATCH BIT10 :CLK CLK
                                                        :D D10 :Q Q10 :QBAR
                                                        QBAR10)
                                                       (D-LATCH BIT11 :CLK CLK
                                                        :D D11 :Q Q11 :QBAR
                                                        QBAR11)
                                                       (D-LATCH BIT12 :CLK CLK
                                                        :D D12 :Q Q12 :QBAR
                                                        QBAR12)
                                                       (D-LATCH BIT13 :CLK CLK
                                                        :D D13 :Q Q13 :QBAR
                                                        QBAR13)
                                                       (D-LATCH BIT14 :CLK CLK
                                                        :D D14 :Q Q14 :QBAR
                                                        QBAR14)
                                                       (D-LATCH BIT15 :CLK CLK
                                                        :D D15 :Q Q15 :QBAR
                                                        QBAR15)
                                                       (D-LATCH BIT16 :CLK CLK
                                                        :D D16 :Q Q16 :QBAR
                                                        QBAR16)
                                                       (D-LATCH BIT17 :CLK CLK
                                                        :D D17 :Q Q17 :QBAR
                                                        QBAR17)
                                                       (D-LATCH BIT18 :CLK CLK
                                                        :D D18 :Q Q18 :QBAR
                                                        QBAR18)
                                                       (D-LATCH BIT19 :CLK CLK
                                                        :D D19 :Q Q19 :QBAR
                                                        QBAR19)
                                                       (D-LATCH BIT20 :CLK CLK
                                                        :D D20 :Q Q20 :QBAR
                                                        QBAR20)
                                                       (D-LATCH BIT21 :CLK CLK
                                                        :D D21 :Q Q21 :QBAR
                                                        QBAR21)
                                                       (D-LATCH BIT22 :CLK CLK
                                                        :D D22 :Q Q22 :QBAR
                                                        QBAR22)
                                                       (D-LATCH BIT23 :CLK CLK
                                                        :D D23 :Q Q23 :QBAR
                                                        QBAR23)
                                                       (D-LATCH BIT24 :CLK CLK
                                                        :D D24 :Q Q24 :QBAR
                                                        QBAR24)
                                                       (D-LATCH BIT25 :CLK CLK
                                                        :D D25 :Q Q25 :QBAR
                                                        QBAR25)
                                                       (D-LATCH BIT26 :CLK CLK
                                                        :D D26 :Q Q26 :QBAR
                                                        QBAR26)
                                                       (D-LATCH BIT27 :CLK CLK
                                                        :D D27 :Q Q27 :QBAR
                                                        QBAR27)
                                                       (D-LATCH BIT28 :CLK CLK
                                                        :D D28 :Q Q28 :QBAR
                                                        QBAR28)
                                                       (D-LATCH BIT29 :CLK CLK
                                                        :D D29 :Q Q29 :QBAR
                                                        QBAR29)
                                                       (D-LATCH BIT30 :CLK CLK
                                                        :D D30 :Q Q30 :QBAR
                                                        QBAR30)
                                                       (D-LATCH BIT31 :CLK CLK
                                                        :D D31 :Q Q31 :QBAR
                                                        QBAR31)))))
       ((TYPEP #:VAL309 '<SET>)
        (GET #:VAL309 'REGISTER-32BIT
             (MAKE '<MODULE-DEF> :NAME 'REGISTER-32BIT :PORTS
                   '(CLK D0 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12 D13 D14 D15
                     D16 D17 D18 D19 D20 D21 D22 D23 D24 D25 D26 D27 D28 D29
                     D30 D31 Q0 Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10 Q11 Q12 Q13 Q14
                     Q15 Q16 Q17 Q18 Q19 Q20 Q21 Q22 Q23 Q24 Q25 Q26 Q27 Q28
                     Q29 Q30 Q31)
                   :BODY
                   '((D-LATCH BIT0 :CLK CLK :D D0 :Q Q0 :QBAR QBAR0)
                     (D-LATCH BIT1 :CLK CLK :D D1 :Q Q1 :QBAR QBAR1)
                     (D-LATCH BIT2 :CLK CLK :D D2 :Q Q2 :QBAR QBAR2)
                     (D-LATCH BIT3 :CLK CLK :D D3 :Q Q3 :QBAR QBAR3)
                     (D-LATCH BIT4 :CLK CLK :D D4 :Q Q4 :QBAR QBAR4)
                     (D-LATCH BIT5 :CLK CLK :D D5 :Q Q5 :QBAR QBAR5)
                     (D-LATCH BIT6 :CLK CLK :D D6 :Q Q6 :QBAR QBAR6)
                     (D-LATCH BIT7 :CLK CLK :D D7 :Q Q7 :QBAR QBAR7)
                     (D-LATCH BIT8 :CLK CLK :D D8 :Q Q8 :QBAR QBAR8)
                     (D-LATCH BIT9 :CLK CLK :D D9 :Q Q9 :QBAR QBAR9)
                     (D-LATCH BIT10 :CLK CLK :D D10 :Q Q10 :QBAR QBAR10)
                     (D-LATCH BIT11 :CLK CLK :D D11 :Q Q11 :QBAR QBAR11)
                     (D-LATCH BIT12 :CLK CLK :D D12 :Q Q12 :QBAR QBAR12)
                     (D-LATCH BIT13 :CLK CLK :D D13 :Q Q13 :QBAR QBAR13)
                     (D-LATCH BIT14 :CLK CLK :D D14 :Q Q14 :QBAR QBAR14)
                     (D-LATCH BIT15 :CLK CLK :D D15 :Q Q15 :QBAR QBAR15)
                     (D-LATCH BIT16 :CLK CLK :D D16 :Q Q16 :QBAR QBAR16)
                     (D-LATCH BIT17 :CLK CLK :D D17 :Q Q17 :QBAR QBAR17)
                     (D-LATCH BIT18 :CLK CLK :D D18 :Q Q18 :QBAR QBAR18)
                     (D-LATCH BIT19 :CLK CLK :D D19 :Q Q19 :QBAR QBAR19)
                     (D-LATCH BIT20 :CLK CLK :D D20 :Q Q20 :QBAR QBAR20)
                     (D-LATCH BIT21 :CLK CLK :D D21 :Q Q21 :QBAR QBAR21)
                     (D-LATCH BIT22 :CLK CLK :D D22 :Q Q22 :QBAR QBAR22)
                     (D-LATCH BIT23 :CLK CLK :D D23 :Q Q23 :QBAR QBAR23)
                     (D-LATCH BIT24 :CLK CLK :D D24 :Q Q24 :QBAR QBAR24)
                     (D-LATCH BIT25 :CLK CLK :D D25 :Q Q25 :QBAR QBAR25)
                     (D-LATCH BIT26 :CLK CLK :D D26 :Q Q26 :QBAR QBAR26)
                     (D-LATCH BIT27 :CLK CLK :D D27 :Q Q27 :QBAR QBAR27)
                     (D-LATCH BIT28 :CLK CLK :D D28 :Q Q28 :QBAR QBAR28)
                     (D-LATCH BIT29 :CLK CLK :D D29 :Q Q29 :QBAR QBAR29)
                     (D-LATCH BIT30 :CLK CLK :D D30 :Q Q30 :QBAR QBAR30)
                     (D-LATCH BIT31 :CLK CLK :D D31 :Q Q31 :QBAR QBAR31)))))
       (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE))))) 
(DEFUN QUALIFY-NAME (PREFIX NAME)
  (IF (TRUTHY?
       (IF (FBOUNDP 'NIL?)
           (NIL? PREFIX)
           (LET ((#:VAL310 NIL?))
             (COND ((TYPEP #:VAL310 '<DICT>) (GET #:VAL310 PREFIX))
                   ((TYPEP #:VAL310 '<VECTOR>)
                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL310 PREFIX))
                   ((TYPEP #:VAL310 '<SET>) (GET #:VAL310 PREFIX))
                   (T (ERROR "~S is not a function or collection" 'NIL?))))))
      NAME
      (SYMBOL (STR PREFIX "/" NAME)))) 
(DEFUN RESOLVE-NODE (NODE-SYM PREFIX BINDINGS)
  (IF (TRUTHY? (CONTAINS? BINDINGS NODE-SYM))
      (GET BINDINGS NODE-SYM)
      (IF (FBOUNDP 'QUALIFY-NAME)
          (QUALIFY-NAME PREFIX NODE-SYM)
          (LET ((#:VAL311 QUALIFY-NAME))
            (COND ((TYPEP #:VAL311 '<DICT>) (GET #:VAL311 PREFIX NODE-SYM))
                  ((TYPEP #:VAL311 '<VECTOR>)
                   (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL311 PREFIX
                                                          NODE-SYM))
                  ((TYPEP #:VAL311 '<SET>) (GET #:VAL311 PREFIX NODE-SYM))
                  (T
                   (ERROR "~S is not a function or collection"
                          'QUALIFY-NAME))))))) 
(DEFUN PARSE-CONNECTIONS (ARGS PREFIX BINDINGS)
  (BLOCK LOOP-BLOCK-1
    (LET ((REM ARGS) (ACC (DICT)))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (PROGN
                (IF (TRUTHY? (EMPTY? REM))
                    ACC
                    (LET ((PORT (FIRST REM)))
                      (LET ((NODE-SYM (SECOND REM)))
                        (LET ((RESOLVED
                               (IF (FBOUNDP 'RESOLVE-NODE)
                                   (RESOLVE-NODE NODE-SYM PREFIX BINDINGS)
                                   (LET ((#:VAL312 RESOLVE-NODE))
                                     (COND
                                      ((TYPEP #:VAL312 '<DICT>)
                                       (GET #:VAL312 NODE-SYM PREFIX BINDINGS))
                                      ((TYPEP #:VAL312 '<VECTOR>)
                                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                        #:VAL312 NODE-SYM PREFIX BINDINGS))
                                      ((TYPEP #:VAL312 '<SET>)
                                       (GET #:VAL312 NODE-SYM PREFIX BINDINGS))
                                      (T
                                       (ERROR
                                        "~S is not a function or collection"
                                        'RESOLVE-NODE)))))))
                          (PROGN
                           (PSETQ REM (REST (REST REM))
                                  ACC (ASSOC ACC PORT RESOLVED))
                           (GO LOOP-1)))))))))
          (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))) 
(DEFUN EXPAND-SPEC (SPEC PREFIX BINDINGS)
  (LET ((TYPE (FIRST SPEC)))
    (LET ((NAME (SECOND SPEC)))
      (LET ((RAW-ARGS (REST (REST SPEC))))
        (LET ((HAS-PARAM?
               (AND (NOT (EMPTY? RAW-ARGS))
                    (NOT
                     (IF (FBOUNDP 'KEYWORD?)
                         (KEYWORD? (FIRST RAW-ARGS))
                         (LET ((#:VAL313 KEYWORD?))
                           (COND
                            ((TYPEP #:VAL313 '<DICT>)
                             (GET #:VAL313 (FIRST RAW-ARGS)))
                            ((TYPEP #:VAL313 '<VECTOR>)
                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL313
                                                                    (FIRST
                                                                     RAW-ARGS)))
                            ((TYPEP #:VAL313 '<SET>)
                             (GET #:VAL313 (FIRST RAW-ARGS)))
                            (T
                             (ERROR "~S is not a function or collection"
                                    'KEYWORD?)))))))))
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
                         (QUALIFY-NAME PREFIX NAME)
                         (LET ((#:VAL314 QUALIFY-NAME))
                           (COND
                            ((TYPEP #:VAL314 '<DICT>)
                             (GET #:VAL314 PREFIX NAME))
                            ((TYPEP #:VAL314 '<VECTOR>)
                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL314
                                                                    PREFIX
                                                                    NAME))
                            ((TYPEP #:VAL314 '<SET>)
                             (GET #:VAL314 PREFIX NAME))
                            (T
                             (ERROR "~S is not a function or collection"
                                    'QUALIFY-NAME)))))))
                (LET ((RESOLVED-CONNS
                       (IF (FBOUNDP 'PARSE-CONNECTIONS)
                           (PARSE-CONNECTIONS ARGS PREFIX BINDINGS)
                           (LET ((#:VAL315 PARSE-CONNECTIONS))
                             (COND
                              ((TYPEP #:VAL315 '<DICT>)
                               (GET #:VAL315 ARGS PREFIX BINDINGS))
                              ((TYPEP #:VAL315 '<VECTOR>)
                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL315
                                                                      ARGS
                                                                      PREFIX
                                                                      BINDINGS))
                              ((TYPEP #:VAL315 '<SET>)
                               (GET #:VAL315 ARGS PREFIX BINDINGS))
                              (T
                               (ERROR "~S is not a function or collection"
                                      'PARSE-CONNECTIONS)))))))
                  (LET ((MODULE-DEF
                         (IF (FBOUNDP 'GET-MODULE)
                             (GET-MODULE TYPE)
                             (LET ((#:VAL316 GET-MODULE))
                               (COND
                                ((TYPEP #:VAL316 '<DICT>) (GET #:VAL316 TYPE))
                                ((TYPEP #:VAL316 '<VECTOR>)
                                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                  #:VAL316 TYPE))
                                ((TYPEP #:VAL316 '<SET>) (GET #:VAL316 TYPE))
                                (T
                                 (ERROR "~S is not a function or collection"
                                        'GET-MODULE)))))))
                    (LET ((PRIMITIVE-FACTORY
                           (IF (FBOUNDP 'GET-PRIMITIVE)
                               (GET-PRIMITIVE TYPE)
                               (LET ((#:VAL317 GET-PRIMITIVE))
                                 (COND
                                  ((TYPEP #:VAL317 '<DICT>)
                                   (GET #:VAL317 TYPE))
                                  ((TYPEP #:VAL317 '<VECTOR>)
                                   (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                    #:VAL317 TYPE))
                                  ((TYPEP #:VAL317 '<SET>) (GET #:VAL317 TYPE))
                                  (T
                                   (ERROR "~S is not a function or collection"
                                          'GET-PRIMITIVE)))))))
                      (IF (TRUTHY? MODULE-DEF)
                          (REDUCE
                           (LAMBDA (ACC CHILD-SPEC)
                             (CONCAT ACC
                                     (IF (FBOUNDP 'EXPAND-SPEC)
                                         (EXPAND-SPEC CHILD-SPEC FULL-NAME
                                          RESOLVED-CONNS)
                                         (LET ((#:VAL318 EXPAND-SPEC))
                                           (COND
                                            ((TYPEP #:VAL318 '<DICT>)
                                             (GET #:VAL318 CHILD-SPEC FULL-NAME
                                                  RESOLVED-CONNS))
                                            ((TYPEP #:VAL318 '<VECTOR>)
                                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                              #:VAL318 CHILD-SPEC FULL-NAME
                                              RESOLVED-CONNS))
                                            ((TYPEP #:VAL318 '<SET>)
                                             (GET #:VAL318 CHILD-SPEC FULL-NAME
                                                  RESOLVED-CONNS))
                                            (T
                                             (ERROR
                                              "~S is not a function or collection"
                                              'EXPAND-SPEC)))))))
                           (VECTOR)
                           (IF (FBOUNDP 'MODULE-BODY)
                               (MODULE-BODY MODULE-DEF)
                               (LET ((#:VAL319 MODULE-BODY))
                                 (COND
                                  ((TYPEP #:VAL319 '<DICT>)
                                   (GET #:VAL319 MODULE-DEF))
                                  ((TYPEP #:VAL319 '<VECTOR>)
                                   (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                    #:VAL319 MODULE-DEF))
                                  ((TYPEP #:VAL319 '<SET>)
                                   (GET #:VAL319 MODULE-DEF))
                                  (T
                                   (ERROR "~S is not a function or collection"
                                          'MODULE-BODY))))))
                          (IF (TRUTHY? PRIMITIVE-FACTORY)
                              (VECTOR
                               (LET ((#:OP320 PRIMITIVE-FACTORY))
                                 (COND
                                  ((FUNCTIONP #:OP320)
                                   (FUNCALL #:OP320 FULL-NAME PARAM
                                            RESOLVED-CONNS))
                                  ((TYPEP #:OP320 '<DICT>)
                                   (GET #:OP320 FULL-NAME PARAM
                                        RESOLVED-CONNS))
                                  ((TYPEP #:OP320 '<VECTOR>)
                                   (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                    #:OP320 FULL-NAME PARAM RESOLVED-CONNS))
                                  ((TYPEP #:OP320 '<SET>)
                                   (GET #:OP320 FULL-NAME PARAM
                                        RESOLVED-CONNS))
                                  (T
                                   (ERROR
                                    "Value ~S is not callable or a collection"
                                    #:OP320)))))
                              (IF (TRUTHY? :ELSE)
                                  (VECTOR
                                   (MAKE <COMPONENT> :NAME FULL-NAME :TYPE TYPE
                                         :CONNECTIONS RESOLVED-CONNS))
                                  NIL)))))))))))))) 
(DEFUN EXPAND-NETLIST (TOP-MODULE-NAME)
  (LET ((DEF
         (IF (FBOUNDP 'GET-MODULE)
             (GET-MODULE TOP-MODULE-NAME)
             (LET ((#:VAL321 GET-MODULE))
               (COND ((TYPEP #:VAL321 '<DICT>) (GET #:VAL321 TOP-MODULE-NAME))
                     ((TYPEP #:VAL321 '<VECTOR>)
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL321
                                                             TOP-MODULE-NAME))
                     ((TYPEP #:VAL321 '<SET>) (GET #:VAL321 TOP-MODULE-NAME))
                     (T
                      (ERROR "~S is not a function or collection"
                             'GET-MODULE)))))))
    (IF (TRUTHY?
         (IF (FBOUNDP 'NIL?)
             (NIL? DEF)
             (LET ((#:VAL322 NIL?))
               (COND ((TYPEP #:VAL322 '<DICT>) (GET #:VAL322 DEF))
                     ((TYPEP #:VAL322 '<VECTOR>)
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL322 DEF))
                     ((TYPEP #:VAL322 '<SET>) (GET #:VAL322 DEF))
                     (T (ERROR "~S is not a function or collection" 'NIL?))))))
        (ERROR (STR "Module " TOP-MODULE-NAME " not found"))
        (LET ((TOP-BINDINGS
               (REDUCE (LAMBDA (ACC P) (ASSOC ACC P P)) (DICT)
                       (IF (FBOUNDP 'MODULE-PORTS)
                           (MODULE-PORTS DEF)
                           (LET ((#:VAL323 MODULE-PORTS))
                             (COND
                              ((TYPEP #:VAL323 '<DICT>) (GET #:VAL323 DEF))
                              ((TYPEP #:VAL323 '<VECTOR>)
                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL323
                                                                      DEF))
                              ((TYPEP #:VAL323 '<SET>) (GET #:VAL323 DEF))
                              (T
                               (ERROR "~S is not a function or collection"
                                      'MODULE-PORTS))))))))
          (REDUCE
           (LAMBDA (ACC SPEC)
             (CONCAT ACC
                     (IF (FBOUNDP 'EXPAND-SPEC)
                         (EXPAND-SPEC SPEC NIL TOP-BINDINGS)
                         (LET ((#:VAL324 EXPAND-SPEC))
                           (COND
                            ((TYPEP #:VAL324 '<DICT>)
                             (GET #:VAL324 SPEC NIL TOP-BINDINGS))
                            ((TYPEP #:VAL324 '<VECTOR>)
                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL324
                                                                    SPEC NIL
                                                                    TOP-BINDINGS))
                            ((TYPEP #:VAL324 '<SET>)
                             (GET #:VAL324 SPEC NIL TOP-BINDINGS))
                            (T
                             (ERROR "~S is not a function or collection"
                                    'EXPAND-SPEC)))))))
           (VECTOR)
           (IF (FBOUNDP 'MODULE-BODY)
               (MODULE-BODY DEF)
               (LET ((#:VAL325 MODULE-BODY))
                 (COND ((TYPEP #:VAL325 '<DICT>) (GET #:VAL325 DEF))
                       ((TYPEP #:VAL325 '<VECTOR>)
                        (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL325 DEF))
                       ((TYPEP #:VAL325 '<SET>) (GET #:VAL325 DEF))
                       (T
                        (ERROR "~S is not a function or collection"
                               'MODULE-BODY)))))))))) 
(DEFGENERIC REGISTER-CONNECTIVITY
    (COMP MAP)) 
(DEFMETHOD REGISTER-CONNECTIVITY (COMP MAP) MAP) 
(DEFUN REGISTER-CONNECTIVITY (COMP MAP)
  (COND
   ((TYPEP COMP '<LOGIC-COMPONENT>)
    (REDUCE
     (LAMBDA (ACC PORT)
       (LET ((NODE
              (GET
               (IF (FBOUNDP 'COMPONENT-CONNECTIONS)
                   (COMPONENT-CONNECTIONS COMP)
                   (LET ((#:VAL326 COMPONENT-CONNECTIONS))
                     (COND ((TYPEP #:VAL326 '<DICT>) (GET #:VAL326 COMP))
                           ((TYPEP #:VAL326 '<VECTOR>)
                            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL326
                                                                   COMP))
                           ((TYPEP #:VAL326 '<SET>) (GET #:VAL326 COMP))
                           (T
                            (ERROR "~S is not a function or collection"
                                   'COMPONENT-CONNECTIONS)))))
               PORT)))
         (IF (FBOUNDP 'UPDATE)
             (UPDATE ACC NODE (LAMBDA (COMPS) (CONJ (OR COMPS (VECTOR)) COMP)))
             (LET ((#:VAL327 UPDATE))
               (COND
                ((TYPEP #:VAL327 '<DICT>)
                 (GET #:VAL327 ACC NODE
                      (LAMBDA (COMPS) (CONJ (OR COMPS (VECTOR)) COMP))))
                ((TYPEP #:VAL327 '<VECTOR>)
                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL327 ACC NODE
                                                        (LAMBDA (COMPS)
                                                          (CONJ
                                                           (OR COMPS (VECTOR))
                                                           COMP))))
                ((TYPEP #:VAL327 '<SET>)
                 (GET #:VAL327 ACC NODE
                      (LAMBDA (COMPS) (CONJ (OR COMPS (VECTOR)) COMP))))
                (T (ERROR "~S is not a function or collection" 'UPDATE)))))))
     MAP
     (IF (FBOUNDP 'COMPONENT-INPUTS)
         (COMPONENT-INPUTS COMP)
         (LET ((#:VAL328 COMPONENT-INPUTS))
           (COND ((TYPEP #:VAL328 '<DICT>) (GET #:VAL328 COMP))
                 ((TYPEP #:VAL328 '<VECTOR>)
                  (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL328 COMP))
                 ((TYPEP #:VAL328 '<SET>) (GET #:VAL328 COMP))
                 (T
                  (ERROR "~S is not a function or collection"
                         'COMPONENT-INPUTS)))))))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S"
           'REGISTER-CONNECTIVITY (COMMON-LISP:LIST COMP MAP))))) 
(DEFUN INSERT-EVENT (QUEUE EVENT)
  (IF (TRUTHY? (EMPTY? QUEUE))
      (VECTOR EVENT)
      (LET ((HEAD (FIRST QUEUE)))
        (IF (TRUTHY?
             (<
              (LET ((#:START-329 (GET-INTERNAL-REAL-TIME)))
                (LET ((#:RESULT-330 (PROGN EVENT)))
                  (LET ((#:END-331 (GET-INTERNAL-REAL-TIME)))
                    (PROGN
                     (FORMAT T "Elapsed time: ~,3f ms~%"
                             (*
                              (/ (- #:END-331 #:START-329)
                                 INTERNAL-TIME-UNITS-PER-SECOND)
                              1000.0))
                     #:RESULT-330))))
              (LET ((#:START-332 (GET-INTERNAL-REAL-TIME)))
                (LET ((#:RESULT-333 (PROGN HEAD)))
                  (LET ((#:END-334 (GET-INTERNAL-REAL-TIME)))
                    (PROGN
                     (FORMAT T "Elapsed time: ~,3f ms~%"
                             (*
                              (/ (- #:END-334 #:START-332)
                                 INTERNAL-TIME-UNITS-PER-SECOND)
                              1000.0))
                     #:RESULT-333))))))
            (CONS EVENT QUEUE)
            (CONS HEAD
                  (IF (FBOUNDP 'INSERT-EVENT)
                      (INSERT-EVENT (REST QUEUE) EVENT)
                      (LET ((#:VAL335 INSERT-EVENT))
                        (COND
                         ((TYPEP #:VAL335 '<DICT>)
                          (GET #:VAL335 (REST QUEUE) EVENT))
                         ((TYPEP #:VAL335 '<VECTOR>)
                          (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL335
                                                                 (REST QUEUE)
                                                                 EVENT))
                         ((TYPEP #:VAL335 '<SET>)
                          (GET #:VAL335 (REST QUEUE) EVENT))
                         (T
                          (ERROR "~S is not a function or collection"
                                 'INSERT-EVENT)))))))))) 
(DEFUN MERGE-EVENTS (QUEUE NEW-EVENTS) (REDUCE INSERT-EVENT QUEUE NEW-EVENTS)) 
(DEFUN GET-INPUT-STATES (COMP NODE-VALUES)
  (REDUCE
   (LAMBDA (ACC PORT)
     (LET ((NODE
            (GET
             (IF (FBOUNDP 'COMPONENT-CONNECTIONS)
                 (COMPONENT-CONNECTIONS COMP)
                 (LET ((#:VAL336 COMPONENT-CONNECTIONS))
                   (COND ((TYPEP #:VAL336 '<DICT>) (GET #:VAL336 COMP))
                         ((TYPEP #:VAL336 '<VECTOR>)
                          (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL336
                                                                 COMP))
                         ((TYPEP #:VAL336 '<SET>) (GET #:VAL336 COMP))
                         (T
                          (ERROR "~S is not a function or collection"
                                 'COMPONENT-CONNECTIONS)))))
             PORT)))
       (ASSOC ACC PORT (GET NODE-VALUES NODE))))
   (DICT)
   (IF (FBOUNDP 'COMPONENT-INPUTS)
       (COMPONENT-INPUTS COMP)
       (LET ((#:VAL337 COMPONENT-INPUTS))
         (COND ((TYPEP #:VAL337 '<DICT>) (GET #:VAL337 COMP))
               ((TYPEP #:VAL337 '<VECTOR>)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL337 COMP))
               ((TYPEP #:VAL337 '<SET>) (GET #:VAL337 COMP))
               (T
                (ERROR "~S is not a function or collection"
                       'COMPONENT-INPUTS))))))) 
(DEFUN GET-CHANGED-PORTS (COMP CHANGED-NODES)
  (FILTER
   (LAMBDA (PORT)
     (LET ((NODE
            (GET
             (IF (FBOUNDP 'COMPONENT-CONNECTIONS)
                 (COMPONENT-CONNECTIONS COMP)
                 (LET ((#:VAL338 COMPONENT-CONNECTIONS))
                   (COND ((TYPEP #:VAL338 '<DICT>) (GET #:VAL338 COMP))
                         ((TYPEP #:VAL338 '<VECTOR>)
                          (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL338
                                                                 COMP))
                         ((TYPEP #:VAL338 '<SET>) (GET #:VAL338 COMP))
                         (T
                          (ERROR "~S is not a function or collection"
                                 'COMPONENT-CONNECTIONS)))))
             PORT)))
       (CONTAINS? CHANGED-NODES NODE)))
   (IF (FBOUNDP 'COMPONENT-INPUTS)
       (COMPONENT-INPUTS COMP)
       (LET ((#:VAL339 COMPONENT-INPUTS))
         (COND ((TYPEP #:VAL339 '<DICT>) (GET #:VAL339 COMP))
               ((TYPEP #:VAL339 '<VECTOR>)
                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL339 COMP))
               ((TYPEP #:VAL339 '<SET>) (GET #:VAL339 COMP))
               (T
                (ERROR "~S is not a function or collection"
                       'COMPONENT-INPUTS))))))) 
(DEFUN RUN-SIMULATION (NETLIST INITIAL-EVENTS MAX-TIME MONITORED-NODES)
  (LET ((CONNECTIVITY
         (REDUCE
          (LAMBDA (ACC C)
            (IF (FBOUNDP 'REGISTER-CONNECTIVITY)
                (REGISTER-CONNECTIVITY C ACC)
                (LET ((#:VAL349 REGISTER-CONNECTIVITY))
                  (COND ((TYPEP #:VAL349 '<DICT>) (GET #:VAL349 C ACC))
                        ((TYPEP #:VAL349 '<VECTOR>)
                         (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL349 C
                                                                ACC))
                        ((TYPEP #:VAL349 '<SET>) (GET #:VAL349 C ACC))
                        (T
                         (ERROR "~S is not a function or collection"
                                'REGISTER-CONNECTIVITY))))))
          (DICT) NETLIST)))
    (BLOCK LOOP-BLOCK-2
      (LET ((QUEUE
             (IF (FBOUNDP 'SORT-BY)
                 (SORT-BY :TIME INITIAL-EVENTS)
                 (LET ((#:VAL350 SORT-BY))
                   (COND
                    ((TYPEP #:VAL350 '<DICT>)
                     (GET #:VAL350 :TIME INITIAL-EVENTS))
                    ((TYPEP #:VAL350 '<VECTOR>)
                     (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL350 :TIME
                                                            INITIAL-EVENTS))
                    ((TYPEP #:VAL350 '<SET>)
                     (GET #:VAL350 :TIME INITIAL-EVENTS))
                    (T
                     (ERROR "~S is not a function or collection" 'SORT-BY))))))
            (NODE-VALUES (DICT))
            (EVENT-HISTORY (DICT))
            (CURRENT-TIME 0))
        (TAGBODY
         LOOP-2
          (LET ((RESULT-2
                 (PROGN
                  (IF (TRUTHY? (OR (EMPTY? QUEUE) (> CURRENT-TIME MAX-TIME)))
                      EVENT-HISTORY
                      (LET ((EVENT-TIME
                             (LET ((#:START-340 (GET-INTERNAL-REAL-TIME)))
                               (LET ((#:RESULT-341 (PROGN (FIRST QUEUE))))
                                 (LET ((#:END-342 (GET-INTERNAL-REAL-TIME)))
                                   (PROGN
                                    (FORMAT T "Elapsed time: ~,3f ms~%"
                                            (*
                                             (/ (- #:END-342 #:START-340)
                                                INTERNAL-TIME-UNITS-PER-SECOND)
                                             1000.0))
                                    #:RESULT-341))))))
                        (LET ((BATCH
                               (TAKE-WHILE
                                (LAMBDA (X)
                                  (=
                                   (LET ((#:START-343 (GET-INTERNAL-REAL-TIME)))
                                     (LET ((#:RESULT-344 (PROGN X)))
                                       (LET ((#:END-345
                                              (GET-INTERNAL-REAL-TIME)))
                                         (PROGN
                                          (FORMAT T "Elapsed time: ~,3f ms~%"
                                                  (*
                                                   (/ (- #:END-345 #:START-343)
                                                      INTERNAL-TIME-UNITS-PER-SECOND)
                                                   1000.0))
                                          #:RESULT-344))))
                                   EVENT-TIME))
                                QUEUE)))
                          (LET ((REMAINING
                                 (DROP-WHILE
                                  (LAMBDA (X)
                                    (=
                                     (LET ((#:START-346
                                            (GET-INTERNAL-REAL-TIME)))
                                       (LET ((#:RESULT-347 (PROGN X)))
                                         (LET ((#:END-348
                                                (GET-INTERNAL-REAL-TIME)))
                                           (PROGN
                                            (FORMAT T "Elapsed time: ~,3f ms~%"
                                                    (*
                                                     (/
                                                      (- #:END-348 #:START-346)
                                                      INTERNAL-TIME-UNITS-PER-SECOND)
                                                     1000.0))
                                            #:RESULT-347))))
                                     EVENT-TIME))
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
                                          (IF (TRUTHY?
                                               (CONTAINS? MONITORED-NODES
                                                          (GET EVT :NODE)))
                                              (IF (FBOUNDP 'UPDATE)
                                                  (UPDATE ACC (GET EVT :NODE)
                                                   (LAMBDA (EVTS)
                                                     (CONJ (OR EVTS (VECTOR))
                                                           EVT)))
                                                  (LET ((#:VAL351 UPDATE))
                                                    (COND
                                                     ((TYPEP #:VAL351 '<DICT>)
                                                      (GET #:VAL351 ACC
                                                           (GET EVT :NODE)
                                                           (LAMBDA (EVTS)
                                                             (CONJ
                                                              (OR EVTS
                                                                  (VECTOR))
                                                              EVT))))
                                                     ((TYPEP #:VAL351
                                                             '<VECTOR>)
                                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                       #:VAL351 ACC
                                                       (GET EVT :NODE)
                                                       (LAMBDA (EVTS)
                                                         (CONJ
                                                          (OR EVTS (VECTOR))
                                                          EVT))))
                                                     ((TYPEP #:VAL351 '<SET>)
                                                      (GET #:VAL351 ACC
                                                           (GET EVT :NODE)
                                                           (LAMBDA (EVTS)
                                                             (CONJ
                                                              (OR EVTS
                                                                  (VECTOR))
                                                              EVT))))
                                                     (T
                                                      (ERROR
                                                       "~S is not a function or collection"
                                                       'UPDATE)))))
                                              ACC))
                                        EVENT-HISTORY BATCH)))
                                  (LET ((CHANGED-NODES (KEYS UPDATES)))
                                    (LET ((AFFECTED-COMPS
                                           (REDUCE
                                            (LAMBDA (ACC NODE)
                                              (REDUCE CONJ ACC
                                                      (GET CONNECTIVITY NODE)))
                                            (SET) CHANGED-NODES)))
                                      (LET ((NEW-EVENTS
                                             (IF (FBOUNDP 'PMAPCAT)
                                                 (PMAPCAT
                                                  (LAMBDA (COMP)
                                                    (LET ((INPUT-STATES
                                                           (IF (FBOUNDP
                                                                'GET-INPUT-STATES)
                                                               (GET-INPUT-STATES
                                                                COMP
                                                                NEW-NODE-VALUES)
                                                               (LET ((#:VAL352
                                                                      GET-INPUT-STATES))
                                                                 (COND
                                                                  ((TYPEP
                                                                    #:VAL352
                                                                    '<DICT>)
                                                                   (GET
                                                                    #:VAL352
                                                                    COMP
                                                                    NEW-NODE-VALUES))
                                                                  ((TYPEP
                                                                    #:VAL352
                                                                    '<VECTOR>)
                                                                   (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                    #:VAL352
                                                                    COMP
                                                                    NEW-NODE-VALUES))
                                                                  ((TYPEP
                                                                    #:VAL352
                                                                    '<SET>)
                                                                   (GET
                                                                    #:VAL352
                                                                    COMP
                                                                    NEW-NODE-VALUES))
                                                                  (T
                                                                   (ERROR
                                                                    "~S is not a function or collection"
                                                                    'GET-INPUT-STATES)))))))
                                                      (LET ((CHANGED-PORTS
                                                             (IF (FBOUNDP
                                                                  'GET-CHANGED-PORTS)
                                                                 (GET-CHANGED-PORTS
                                                                  COMP
                                                                  (SET
                                                                   CHANGED-NODES))
                                                                 (LET ((#:VAL353
                                                                        GET-CHANGED-PORTS))
                                                                   (COND
                                                                    ((TYPEP
                                                                      #:VAL353
                                                                      '<DICT>)
                                                                     (GET
                                                                      #:VAL353
                                                                      COMP
                                                                      (SET
                                                                       CHANGED-NODES)))
                                                                    ((TYPEP
                                                                      #:VAL353
                                                                      '<VECTOR>)
                                                                     (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                      #:VAL353
                                                                      COMP
                                                                      (SET
                                                                       CHANGED-NODES)))
                                                                    ((TYPEP
                                                                      #:VAL353
                                                                      '<SET>)
                                                                     (GET
                                                                      #:VAL353
                                                                      COMP
                                                                      (SET
                                                                       CHANGED-NODES)))
                                                                    (T
                                                                     (ERROR
                                                                      "~S is not a function or collection"
                                                                      'GET-CHANGED-PORTS)))))))
                                                        (LET ((RESULTS
                                                               (IF (FBOUNDP
                                                                    'COMPUTE-NEXT-STATE)
                                                                   (COMPUTE-NEXT-STATE
                                                                    COMP
                                                                    INPUT-STATES
                                                                    CHANGED-PORTS)
                                                                   (LET ((#:VAL354
                                                                          COMPUTE-NEXT-STATE))
                                                                     (COND
                                                                      ((TYPEP
                                                                        #:VAL354
                                                                        '<DICT>)
                                                                       (GET
                                                                        #:VAL354
                                                                        COMP
                                                                        INPUT-STATES
                                                                        CHANGED-PORTS))
                                                                      ((TYPEP
                                                                        #:VAL354
                                                                        '<VECTOR>)
                                                                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                        #:VAL354
                                                                        COMP
                                                                        INPUT-STATES
                                                                        CHANGED-PORTS))
                                                                      ((TYPEP
                                                                        #:VAL354
                                                                        '<SET>)
                                                                       (GET
                                                                        #:VAL354
                                                                        COMP
                                                                        INPUT-STATES
                                                                        CHANGED-PORTS))
                                                                      (T
                                                                       (ERROR
                                                                        "~S is not a function or collection"
                                                                        'COMPUTE-NEXT-STATE)))))))
                                                          (MAP
                                                           (LAMBDA (RES)
                                                             (DICT :NODE
                                                                   (GET
                                                                    (IF (FBOUNDP
                                                                         'COMPONENT-CONNECTIONS)
                                                                        (COMPONENT-CONNECTIONS
                                                                         COMP)
                                                                        (LET ((#:VAL355
                                                                               COMPONENT-CONNECTIONS))
                                                                          (COND
                                                                           ((TYPEP
                                                                             #:VAL355
                                                                             '<DICT>)
                                                                            (GET
                                                                             #:VAL355
                                                                             COMP))
                                                                           ((TYPEP
                                                                             #:VAL355
                                                                             '<VECTOR>)
                                                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                             #:VAL355
                                                                             COMP))
                                                                           ((TYPEP
                                                                             #:VAL355
                                                                             '<SET>)
                                                                            (GET
                                                                             #:VAL355
                                                                             COMP))
                                                                           (T
                                                                            (ERROR
                                                                             "~S is not a function or collection"
                                                                             'COMPONENT-CONNECTIONS)))))
                                                                    (GET RES
                                                                         :PORT))
                                                                   :VALUE
                                                                   (GET RES
                                                                        :VALUE)
                                                                   :TIME
                                                                   (+
                                                                    EVENT-TIME
                                                                    (IF (FBOUNDP
                                                                         'FOL.MACROS::<DELAY>)
                                                                        (FOL.MACROS::<DELAY>
                                                                         (LAMBDA
                                                                             ()
                                                                           RES))
                                                                        (LET ((#:VAL356
                                                                               FOL.MACROS::<DELAY>))
                                                                          (COND
                                                                           ((TYPEP
                                                                             #:VAL356
                                                                             '<DICT>)
                                                                            (GET
                                                                             #:VAL356
                                                                             (LAMBDA
                                                                                 ()
                                                                               RES)))
                                                                           ((TYPEP
                                                                             #:VAL356
                                                                             '<VECTOR>)
                                                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                             #:VAL356
                                                                             (LAMBDA
                                                                                 ()
                                                                               RES)))
                                                                           ((TYPEP
                                                                             #:VAL356
                                                                             '<SET>)
                                                                            (GET
                                                                             #:VAL356
                                                                             (LAMBDA
                                                                                 ()
                                                                               RES)))
                                                                           (T
                                                                            (ERROR
                                                                             "~S is not a function or collection"
                                                                             'FOL.MACROS::<DELAY>))))))))
                                                           RESULTS)))))
                                                  AFFECTED-COMPS)
                                                 (LET ((#:VAL357 PMAPCAT))
                                                   (COND
                                                    ((TYPEP #:VAL357 '<DICT>)
                                                     (GET #:VAL357
                                                          (LAMBDA (COMP)
                                                            (LET ((INPUT-STATES
                                                                   (IF (FBOUNDP
                                                                        'GET-INPUT-STATES)
                                                                       (GET-INPUT-STATES
                                                                        COMP
                                                                        NEW-NODE-VALUES)
                                                                       (LET ((#:VAL352
                                                                              GET-INPUT-STATES))
                                                                         (COND
                                                                          ((TYPEP
                                                                            #:VAL352
                                                                            '<DICT>)
                                                                           (GET
                                                                            #:VAL352
                                                                            COMP
                                                                            NEW-NODE-VALUES))
                                                                          ((TYPEP
                                                                            #:VAL352
                                                                            '<VECTOR>)
                                                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                            #:VAL352
                                                                            COMP
                                                                            NEW-NODE-VALUES))
                                                                          ((TYPEP
                                                                            #:VAL352
                                                                            '<SET>)
                                                                           (GET
                                                                            #:VAL352
                                                                            COMP
                                                                            NEW-NODE-VALUES))
                                                                          (T
                                                                           (ERROR
                                                                            "~S is not a function or collection"
                                                                            'GET-INPUT-STATES)))))))
                                                              (LET ((CHANGED-PORTS
                                                                     (IF (FBOUNDP
                                                                          'GET-CHANGED-PORTS)
                                                                         (GET-CHANGED-PORTS
                                                                          COMP
                                                                          (SET
                                                                           CHANGED-NODES))
                                                                         (LET ((#:VAL353
                                                                                GET-CHANGED-PORTS))
                                                                           (COND
                                                                            ((TYPEP
                                                                              #:VAL353
                                                                              '<DICT>)
                                                                             (GET
                                                                              #:VAL353
                                                                              COMP
                                                                              (SET
                                                                               CHANGED-NODES)))
                                                                            ((TYPEP
                                                                              #:VAL353
                                                                              '<VECTOR>)
                                                                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                              #:VAL353
                                                                              COMP
                                                                              (SET
                                                                               CHANGED-NODES)))
                                                                            ((TYPEP
                                                                              #:VAL353
                                                                              '<SET>)
                                                                             (GET
                                                                              #:VAL353
                                                                              COMP
                                                                              (SET
                                                                               CHANGED-NODES)))
                                                                            (T
                                                                             (ERROR
                                                                              "~S is not a function or collection"
                                                                              'GET-CHANGED-PORTS)))))))
                                                                (LET ((RESULTS
                                                                       (IF (FBOUNDP
                                                                            'COMPUTE-NEXT-STATE)
                                                                           (COMPUTE-NEXT-STATE
                                                                            COMP
                                                                            INPUT-STATES
                                                                            CHANGED-PORTS)
                                                                           (LET ((#:VAL354
                                                                                  COMPUTE-NEXT-STATE))
                                                                             (COND
                                                                              ((TYPEP
                                                                                #:VAL354
                                                                                '<DICT>)
                                                                               (GET
                                                                                #:VAL354
                                                                                COMP
                                                                                INPUT-STATES
                                                                                CHANGED-PORTS))
                                                                              ((TYPEP
                                                                                #:VAL354
                                                                                '<VECTOR>)
                                                                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                #:VAL354
                                                                                COMP
                                                                                INPUT-STATES
                                                                                CHANGED-PORTS))
                                                                              ((TYPEP
                                                                                #:VAL354
                                                                                '<SET>)
                                                                               (GET
                                                                                #:VAL354
                                                                                COMP
                                                                                INPUT-STATES
                                                                                CHANGED-PORTS))
                                                                              (T
                                                                               (ERROR
                                                                                "~S is not a function or collection"
                                                                                'COMPUTE-NEXT-STATE)))))))
                                                                  (MAP
                                                                   (LAMBDA
                                                                       (RES)
                                                                     (DICT
                                                                      :NODE
                                                                      (GET
                                                                       (IF (FBOUNDP
                                                                            'COMPONENT-CONNECTIONS)
                                                                           (COMPONENT-CONNECTIONS
                                                                            COMP)
                                                                           (LET ((#:VAL355
                                                                                  COMPONENT-CONNECTIONS))
                                                                             (COND
                                                                              ((TYPEP
                                                                                #:VAL355
                                                                                '<DICT>)
                                                                               (GET
                                                                                #:VAL355
                                                                                COMP))
                                                                              ((TYPEP
                                                                                #:VAL355
                                                                                '<VECTOR>)
                                                                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                #:VAL355
                                                                                COMP))
                                                                              ((TYPEP
                                                                                #:VAL355
                                                                                '<SET>)
                                                                               (GET
                                                                                #:VAL355
                                                                                COMP))
                                                                              (T
                                                                               (ERROR
                                                                                "~S is not a function or collection"
                                                                                'COMPONENT-CONNECTIONS)))))
                                                                       (GET RES
                                                                            :PORT))
                                                                      :VALUE
                                                                      (GET RES
                                                                           :VALUE)
                                                                      :TIME
                                                                      (+
                                                                       EVENT-TIME
                                                                       (IF (FBOUNDP
                                                                            'FOL.MACROS::<DELAY>)
                                                                           (FOL.MACROS::<DELAY>
                                                                            (LAMBDA
                                                                                ()
                                                                              RES))
                                                                           (LET ((#:VAL356
                                                                                  FOL.MACROS::<DELAY>))
                                                                             (COND
                                                                              ((TYPEP
                                                                                #:VAL356
                                                                                '<DICT>)
                                                                               (GET
                                                                                #:VAL356
                                                                                (LAMBDA
                                                                                    ()
                                                                                  RES)))
                                                                              ((TYPEP
                                                                                #:VAL356
                                                                                '<VECTOR>)
                                                                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                #:VAL356
                                                                                (LAMBDA
                                                                                    ()
                                                                                  RES)))
                                                                              ((TYPEP
                                                                                #:VAL356
                                                                                '<SET>)
                                                                               (GET
                                                                                #:VAL356
                                                                                (LAMBDA
                                                                                    ()
                                                                                  RES)))
                                                                              (T
                                                                               (ERROR
                                                                                "~S is not a function or collection"
                                                                                'FOL.MACROS::<DELAY>))))))))
                                                                   RESULTS)))))
                                                          AFFECTED-COMPS))
                                                    ((TYPEP #:VAL357 '<VECTOR>)
                                                     (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                      #:VAL357
                                                      (LAMBDA (COMP)
                                                        (LET ((INPUT-STATES
                                                               (IF (FBOUNDP
                                                                    'GET-INPUT-STATES)
                                                                   (GET-INPUT-STATES
                                                                    COMP
                                                                    NEW-NODE-VALUES)
                                                                   (LET ((#:VAL352
                                                                          GET-INPUT-STATES))
                                                                     (COND
                                                                      ((TYPEP
                                                                        #:VAL352
                                                                        '<DICT>)
                                                                       (GET
                                                                        #:VAL352
                                                                        COMP
                                                                        NEW-NODE-VALUES))
                                                                      ((TYPEP
                                                                        #:VAL352
                                                                        '<VECTOR>)
                                                                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                        #:VAL352
                                                                        COMP
                                                                        NEW-NODE-VALUES))
                                                                      ((TYPEP
                                                                        #:VAL352
                                                                        '<SET>)
                                                                       (GET
                                                                        #:VAL352
                                                                        COMP
                                                                        NEW-NODE-VALUES))
                                                                      (T
                                                                       (ERROR
                                                                        "~S is not a function or collection"
                                                                        'GET-INPUT-STATES)))))))
                                                          (LET ((CHANGED-PORTS
                                                                 (IF (FBOUNDP
                                                                      'GET-CHANGED-PORTS)
                                                                     (GET-CHANGED-PORTS
                                                                      COMP
                                                                      (SET
                                                                       CHANGED-NODES))
                                                                     (LET ((#:VAL353
                                                                            GET-CHANGED-PORTS))
                                                                       (COND
                                                                        ((TYPEP
                                                                          #:VAL353
                                                                          '<DICT>)
                                                                         (GET
                                                                          #:VAL353
                                                                          COMP
                                                                          (SET
                                                                           CHANGED-NODES)))
                                                                        ((TYPEP
                                                                          #:VAL353
                                                                          '<VECTOR>)
                                                                         (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                          #:VAL353
                                                                          COMP
                                                                          (SET
                                                                           CHANGED-NODES)))
                                                                        ((TYPEP
                                                                          #:VAL353
                                                                          '<SET>)
                                                                         (GET
                                                                          #:VAL353
                                                                          COMP
                                                                          (SET
                                                                           CHANGED-NODES)))
                                                                        (T
                                                                         (ERROR
                                                                          "~S is not a function or collection"
                                                                          'GET-CHANGED-PORTS)))))))
                                                            (LET ((RESULTS
                                                                   (IF (FBOUNDP
                                                                        'COMPUTE-NEXT-STATE)
                                                                       (COMPUTE-NEXT-STATE
                                                                        COMP
                                                                        INPUT-STATES
                                                                        CHANGED-PORTS)
                                                                       (LET ((#:VAL354
                                                                              COMPUTE-NEXT-STATE))
                                                                         (COND
                                                                          ((TYPEP
                                                                            #:VAL354
                                                                            '<DICT>)
                                                                           (GET
                                                                            #:VAL354
                                                                            COMP
                                                                            INPUT-STATES
                                                                            CHANGED-PORTS))
                                                                          ((TYPEP
                                                                            #:VAL354
                                                                            '<VECTOR>)
                                                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                            #:VAL354
                                                                            COMP
                                                                            INPUT-STATES
                                                                            CHANGED-PORTS))
                                                                          ((TYPEP
                                                                            #:VAL354
                                                                            '<SET>)
                                                                           (GET
                                                                            #:VAL354
                                                                            COMP
                                                                            INPUT-STATES
                                                                            CHANGED-PORTS))
                                                                          (T
                                                                           (ERROR
                                                                            "~S is not a function or collection"
                                                                            'COMPUTE-NEXT-STATE)))))))
                                                              (MAP
                                                               (LAMBDA (RES)
                                                                 (DICT :NODE
                                                                       (GET
                                                                        (IF (FBOUNDP
                                                                             'COMPONENT-CONNECTIONS)
                                                                            (COMPONENT-CONNECTIONS
                                                                             COMP)
                                                                            (LET ((#:VAL355
                                                                                   COMPONENT-CONNECTIONS))
                                                                              (COND
                                                                               ((TYPEP
                                                                                 #:VAL355
                                                                                 '<DICT>)
                                                                                (GET
                                                                                 #:VAL355
                                                                                 COMP))
                                                                               ((TYPEP
                                                                                 #:VAL355
                                                                                 '<VECTOR>)
                                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                 #:VAL355
                                                                                 COMP))
                                                                               ((TYPEP
                                                                                 #:VAL355
                                                                                 '<SET>)
                                                                                (GET
                                                                                 #:VAL355
                                                                                 COMP))
                                                                               (T
                                                                                (ERROR
                                                                                 "~S is not a function or collection"
                                                                                 'COMPONENT-CONNECTIONS)))))
                                                                        (GET
                                                                         RES
                                                                         :PORT))
                                                                       :VALUE
                                                                       (GET RES
                                                                            :VALUE)
                                                                       :TIME
                                                                       (+
                                                                        EVENT-TIME
                                                                        (IF (FBOUNDP
                                                                             'FOL.MACROS::<DELAY>)
                                                                            (FOL.MACROS::<DELAY>
                                                                             (LAMBDA
                                                                                 ()
                                                                               RES))
                                                                            (LET ((#:VAL356
                                                                                   FOL.MACROS::<DELAY>))
                                                                              (COND
                                                                               ((TYPEP
                                                                                 #:VAL356
                                                                                 '<DICT>)
                                                                                (GET
                                                                                 #:VAL356
                                                                                 (LAMBDA
                                                                                     ()
                                                                                   RES)))
                                                                               ((TYPEP
                                                                                 #:VAL356
                                                                                 '<VECTOR>)
                                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                 #:VAL356
                                                                                 (LAMBDA
                                                                                     ()
                                                                                   RES)))
                                                                               ((TYPEP
                                                                                 #:VAL356
                                                                                 '<SET>)
                                                                                (GET
                                                                                 #:VAL356
                                                                                 (LAMBDA
                                                                                     ()
                                                                                   RES)))
                                                                               (T
                                                                                (ERROR
                                                                                 "~S is not a function or collection"
                                                                                 'FOL.MACROS::<DELAY>))))))))
                                                               RESULTS)))))
                                                      AFFECTED-COMPS))
                                                    ((TYPEP #:VAL357 '<SET>)
                                                     (GET #:VAL357
                                                          (LAMBDA (COMP)
                                                            (LET ((INPUT-STATES
                                                                   (IF (FBOUNDP
                                                                        'GET-INPUT-STATES)
                                                                       (GET-INPUT-STATES
                                                                        COMP
                                                                        NEW-NODE-VALUES)
                                                                       (LET ((#:VAL352
                                                                              GET-INPUT-STATES))
                                                                         (COND
                                                                          ((TYPEP
                                                                            #:VAL352
                                                                            '<DICT>)
                                                                           (GET
                                                                            #:VAL352
                                                                            COMP
                                                                            NEW-NODE-VALUES))
                                                                          ((TYPEP
                                                                            #:VAL352
                                                                            '<VECTOR>)
                                                                           (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                            #:VAL352
                                                                            COMP
                                                                            NEW-NODE-VALUES))
                                                                          ((TYPEP
                                                                            #:VAL352
                                                                            '<SET>)
                                                                           (GET
                                                                            #:VAL352
                                                                            COMP
                                                                            NEW-NODE-VALUES))
                                                                          (T
                                                                           (ERROR
                                                                            "~S is not a function or collection"
                                                                            'GET-INPUT-STATES)))))))
                                                              (LET ((CHANGED-PORTS
                                                                     (IF (FBOUNDP
                                                                          'GET-CHANGED-PORTS)
                                                                         (GET-CHANGED-PORTS
                                                                          COMP
                                                                          (SET
                                                                           CHANGED-NODES))
                                                                         (LET ((#:VAL353
                                                                                GET-CHANGED-PORTS))
                                                                           (COND
                                                                            ((TYPEP
                                                                              #:VAL353
                                                                              '<DICT>)
                                                                             (GET
                                                                              #:VAL353
                                                                              COMP
                                                                              (SET
                                                                               CHANGED-NODES)))
                                                                            ((TYPEP
                                                                              #:VAL353
                                                                              '<VECTOR>)
                                                                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                              #:VAL353
                                                                              COMP
                                                                              (SET
                                                                               CHANGED-NODES)))
                                                                            ((TYPEP
                                                                              #:VAL353
                                                                              '<SET>)
                                                                             (GET
                                                                              #:VAL353
                                                                              COMP
                                                                              (SET
                                                                               CHANGED-NODES)))
                                                                            (T
                                                                             (ERROR
                                                                              "~S is not a function or collection"
                                                                              'GET-CHANGED-PORTS)))))))
                                                                (LET ((RESULTS
                                                                       (IF (FBOUNDP
                                                                            'COMPUTE-NEXT-STATE)
                                                                           (COMPUTE-NEXT-STATE
                                                                            COMP
                                                                            INPUT-STATES
                                                                            CHANGED-PORTS)
                                                                           (LET ((#:VAL354
                                                                                  COMPUTE-NEXT-STATE))
                                                                             (COND
                                                                              ((TYPEP
                                                                                #:VAL354
                                                                                '<DICT>)
                                                                               (GET
                                                                                #:VAL354
                                                                                COMP
                                                                                INPUT-STATES
                                                                                CHANGED-PORTS))
                                                                              ((TYPEP
                                                                                #:VAL354
                                                                                '<VECTOR>)
                                                                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                #:VAL354
                                                                                COMP
                                                                                INPUT-STATES
                                                                                CHANGED-PORTS))
                                                                              ((TYPEP
                                                                                #:VAL354
                                                                                '<SET>)
                                                                               (GET
                                                                                #:VAL354
                                                                                COMP
                                                                                INPUT-STATES
                                                                                CHANGED-PORTS))
                                                                              (T
                                                                               (ERROR
                                                                                "~S is not a function or collection"
                                                                                'COMPUTE-NEXT-STATE)))))))
                                                                  (MAP
                                                                   (LAMBDA
                                                                       (RES)
                                                                     (DICT
                                                                      :NODE
                                                                      (GET
                                                                       (IF (FBOUNDP
                                                                            'COMPONENT-CONNECTIONS)
                                                                           (COMPONENT-CONNECTIONS
                                                                            COMP)
                                                                           (LET ((#:VAL355
                                                                                  COMPONENT-CONNECTIONS))
                                                                             (COND
                                                                              ((TYPEP
                                                                                #:VAL355
                                                                                '<DICT>)
                                                                               (GET
                                                                                #:VAL355
                                                                                COMP))
                                                                              ((TYPEP
                                                                                #:VAL355
                                                                                '<VECTOR>)
                                                                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                #:VAL355
                                                                                COMP))
                                                                              ((TYPEP
                                                                                #:VAL355
                                                                                '<SET>)
                                                                               (GET
                                                                                #:VAL355
                                                                                COMP))
                                                                              (T
                                                                               (ERROR
                                                                                "~S is not a function or collection"
                                                                                'COMPONENT-CONNECTIONS)))))
                                                                       (GET RES
                                                                            :PORT))
                                                                      :VALUE
                                                                      (GET RES
                                                                           :VALUE)
                                                                      :TIME
                                                                      (+
                                                                       EVENT-TIME
                                                                       (IF (FBOUNDP
                                                                            'FOL.MACROS::<DELAY>)
                                                                           (FOL.MACROS::<DELAY>
                                                                            (LAMBDA
                                                                                ()
                                                                              RES))
                                                                           (LET ((#:VAL356
                                                                                  FOL.MACROS::<DELAY>))
                                                                             (COND
                                                                              ((TYPEP
                                                                                #:VAL356
                                                                                '<DICT>)
                                                                               (GET
                                                                                #:VAL356
                                                                                (LAMBDA
                                                                                    ()
                                                                                  RES)))
                                                                              ((TYPEP
                                                                                #:VAL356
                                                                                '<VECTOR>)
                                                                               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                                #:VAL356
                                                                                (LAMBDA
                                                                                    ()
                                                                                  RES)))
                                                                              ((TYPEP
                                                                                #:VAL356
                                                                                '<SET>)
                                                                               (GET
                                                                                #:VAL356
                                                                                (LAMBDA
                                                                                    ()
                                                                                  RES)))
                                                                              (T
                                                                               (ERROR
                                                                                "~S is not a function or collection"
                                                                                'FOL.MACROS::<DELAY>))))))))
                                                                   RESULTS)))))
                                                          AFFECTED-COMPS))
                                                    (T
                                                     (ERROR
                                                      "~S is not a function or collection"
                                                      'PMAPCAT)))))))
                                        (PROGN
                                         (PSETQ QUEUE
                                                  (IF (FBOUNDP 'MERGE-EVENTS)
                                                      (MERGE-EVENTS REMAINING
                                                       NEW-EVENTS)
                                                      (LET ((#:VAL358
                                                             MERGE-EVENTS))
                                                        (COND
                                                         ((TYPEP #:VAL358
                                                                 '<DICT>)
                                                          (GET #:VAL358
                                                               REMAINING
                                                               NEW-EVENTS))
                                                         ((TYPEP #:VAL358
                                                                 '<VECTOR>)
                                                          (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                           #:VAL358 REMAINING
                                                           NEW-EVENTS))
                                                         ((TYPEP #:VAL358
                                                                 '<SET>)
                                                          (GET #:VAL358
                                                               REMAINING
                                                               NEW-EVENTS))
                                                         (T
                                                          (ERROR
                                                           "~S is not a function or collection"
                                                           'MERGE-EVENTS)))))
                                                NODE-VALUES NEW-NODE-VALUES
                                                EVENT-HISTORY NEW-EVENT-HISTORY
                                                CURRENT-TIME EVENT-TIME)
                                         (GO LOOP-2)))))))))))))))
            (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))) 
(DEFVAR *SIM-CONTEXT*
  (ATOM (DICT :EVENTS (VECTOR) :MONITORED (SET) :HISTORY (DICT)))) 
(DEFUN MONITOR (&REST NODES)
  (SWAP! *SIM-CONTEXT* #'UPDATE :MONITORED
         (LAMBDA (S) (INTO (OR S (SET)) NODES)))) 
(DEFUN EVENTS (&REST EVENTS)
  (SWAP! *SIM-CONTEXT* #'UPDATE :EVENTS (LAMBDA (Q) (CONCAT Q EVENTS)))) 
(DEFUN RUN (MODULE-NAME TIME)
  (LET ((NETLIST
         (IF (FBOUNDP 'EXPAND-NETLIST)
             (EXPAND-NETLIST MODULE-NAME)
             (LET ((#:VAL359 EXPAND-NETLIST))
               (COND ((TYPEP #:VAL359 '<DICT>) (GET #:VAL359 MODULE-NAME))
                     ((TYPEP #:VAL359 '<VECTOR>)
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL359
                                                             MODULE-NAME))
                     ((TYPEP #:VAL359 '<SET>) (GET #:VAL359 MODULE-NAME))
                     (T
                      (ERROR "~S is not a function or collection"
                             'EXPAND-NETLIST)))))))
    (LET ((INITIAL-EVENTS (GET (DEREF *SIM-CONTEXT*) :EVENTS)))
      (LET ((MONITORED (GET (DEREF *SIM-CONTEXT*) :MONITORED)))
        (LET ((HISTORY
               (IF (FBOUNDP 'RUN-SIMULATION)
                   (RUN-SIMULATION NETLIST INITIAL-EVENTS TIME MONITORED)
                   (LET ((#:VAL360 RUN-SIMULATION))
                     (COND
                      ((TYPEP #:VAL360 '<DICT>)
                       (GET #:VAL360 NETLIST INITIAL-EVENTS TIME MONITORED))
                      ((TYPEP #:VAL360 '<VECTOR>)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #:VAL360 NETLIST
                                                              INITIAL-EVENTS
                                                              TIME MONITORED))
                      ((TYPEP #:VAL360 '<SET>)
                       (GET #:VAL360 NETLIST INITIAL-EVENTS TIME MONITORED))
                      (T
                       (ERROR "~S is not a function or collection"
                              'RUN-SIMULATION)))))))
          (PROGN
           (SWAP! *SIM-CONTEXT* #'ASSOC :HISTORY HISTORY)
           :SIMULATION-COMPLETE)))))) 
(DEFUN DISPLAY (&REST NODES)
  (LET ((HISTORY (GET (DEREF *SIM-CONTEXT*) :HISTORY)))
    (MAP
     (LAMBDA (NODE)
       (PRINT (STR "Events for " NODE ":"))
       (LET ((EVTS (GET HISTORY NODE)))
         (IF (TRUTHY? (EMPTY? EVTS))
             (PRINT "  (no events)")
             (MAP
              (LAMBDA (E)
                (PRINT
                 (STR "  T="
                      (LET ((#:START-361 (GET-INTERNAL-REAL-TIME)))
                        (LET ((#:RESULT-362 (PROGN E)))
                          (LET ((#:END-363 (GET-INTERNAL-REAL-TIME)))
                            (PROGN
                             (FORMAT T "Elapsed time: ~,3f ms~%"
                                     (*
                                      (/ (- #:END-363 #:START-361)
                                         INTERNAL-TIME-UNITS-PER-SECOND)
                                      1000.0))
                             #:RESULT-362))))
                      " V=" (GET E :VALUE))))
              EVTS))))
     NODES))) 