;;; Transpiled from lsim.fol by FOL compiler

;;; This file was automatically generated. Do not edit directly.

(DEFVAR *MODULES* (ATOM (FOL.COMPILER.COLLECTIONS:DICT)))

(DEFUN REGISTER-MODULE (NAME DEF)
  (FOL.COMPILER.MUTABLE:SWAP! *MODULES* #'ASSOC NAME DEF))

(DEFUN GET-MODULE (NAME) (GET (FOL.COMPILER.MUTABLE:DEREF *MODULES*) NAME))

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
    (LET ((LOGIC-FN (COMPONENT-LOGIC-FN COMP)))
      (LET ((DELAYS (COMPONENT-DELAYS COMP)))
        (LET ((NEW-STATES (FUNCALL LOGIC-FN INPUT-STATES)))
          (MAP
           (LAMBDA (OUT-PORT)
             (LET ((DELAY
                    (REDUCE
                     (LAMBDA (MAX-D IN-PORT)
                       (LET ((D (GET (GET DELAYS IN-PORT) OUT-PORT)))
                         (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                              (AND D (> D MAX-D)))
                             D
                             MAX-D)))
                     0 CHANGED-INPUTS)))
               (FOL.COMPILER.COLLECTIONS:DICT :VALUE (GET NEW-STATES OUT-PORT)
                                              :DELAY DELAY :PORT OUT-PORT)))
           (COMPONENT-OUTPUTS COMP))))))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S"
           'COMPUTE-NEXT-STATE (LIST COMP INPUT-STATES CHANGED-INPUTS)))))

(DEFVAR *PRIMITIVES* (ATOM (FOL.COMPILER.COLLECTIONS:DICT)))

(DEFUN REGISTER-PRIMITIVE (NAME FACTORY)
  (FOL.COMPILER.MUTABLE:SWAP! *PRIMITIVES* #'ASSOC NAME FACTORY))

(DEFUN GET-PRIMITIVE (NAME)
  (GET (FOL.COMPILER.MUTABLE:DEREF *PRIMITIVES*) NAME))

(REGISTER-PRIMITIVE 'NOT
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOT :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN (FOL.COMPILER.COLLECTIONS:DICT :OUT 1))
    :LOGIC-FN
    (LAMBDA (S) (FOL.COMPILER.COLLECTIONS:DICT :OUT (NOT (GET S :IN)))))))

(REGISTER-PRIMITIVE 'NAND
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NAND :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN2 :IN1) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN2 (FOL.COMPILER.COLLECTIONS:DICT :OUT 2)
                                   :IN1 (FOL.COMPILER.COLLECTIONS:DICT :OUT 2))
    :LOGIC-FN
    (LAMBDA (S)
      (FOL.COMPILER.COLLECTIONS:DICT :OUT
                                     (NOT (AND (GET S :IN1) (GET S :IN2))))))))

(REGISTER-PRIMITIVE 'NOR
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'NOR :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN2 :IN1) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN2 (FOL.COMPILER.COLLECTIONS:DICT :OUT 2)
                                   :IN1 (FOL.COMPILER.COLLECTIONS:DICT :OUT 2))
    :LOGIC-FN
    (LAMBDA (S)
      (FOL.COMPILER.COLLECTIONS:DICT :OUT
                                     (NOT (OR (GET S :IN1) (GET S :IN2))))))))

(REGISTER-PRIMITIVE 'AND
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'AND :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN2 :IN1) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN2 (FOL.COMPILER.COLLECTIONS:DICT :OUT 3)
                                   :IN1 (FOL.COMPILER.COLLECTIONS:DICT :OUT 3))
    :LOGIC-FN
    (LAMBDA (S)
      (FOL.COMPILER.COLLECTIONS:DICT :OUT (AND (GET S :IN1) (GET S :IN2)))))))

(REGISTER-PRIMITIVE 'OR
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'OR :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN2 :IN1) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN2 (FOL.COMPILER.COLLECTIONS:DICT :OUT 3)
                                   :IN1 (FOL.COMPILER.COLLECTIONS:DICT :OUT 3))
    :LOGIC-FN
    (LAMBDA (S)
      (FOL.COMPILER.COLLECTIONS:DICT :OUT (OR (GET S :IN1) (GET S :IN2)))))))

(REGISTER-PRIMITIVE 'XOR
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XOR :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN2 :IN1) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN2 (FOL.COMPILER.COLLECTIONS:DICT :OUT 3)
                                   :IN1 (FOL.COMPILER.COLLECTIONS:DICT :OUT 3))
    :LOGIC-FN
    (LAMBDA (S)
      (LET ((A (GET S :IN1)))
        (LET ((B (GET S :IN2)))
          (FOL.COMPILER.COLLECTIONS:DICT :OUT
                                         (OR (AND A (NOT B))
                                             (AND (NOT A) B)))))))))

(REGISTER-PRIMITIVE 'XNOR
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'XNOR :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.COLLECTIONS:SET :IN2 :IN1) :OUTPUTS
    (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
    (FOL.COMPILER.COLLECTIONS:DICT :IN2 (FOL.COMPILER.COLLECTIONS:DICT :OUT 4)
                                   :IN1 (FOL.COMPILER.COLLECTIONS:DICT :OUT 4))
    :LOGIC-FN
    (LAMBDA (S)
      (LET ((A (GET S :IN1)))
        (LET ((B (GET S :IN2)))
          (FOL.COMPILER.COLLECTIONS:DICT :OUT
                                         (NOT
                                          (OR (AND A (NOT B))
                                              (AND (NOT A) B))))))))))

(REGISTER-PRIMITIVE 'DELAY
 (LAMBDA (NAME PARAM CONNS)
   (LET ((D (OR PARAM 0)))
     (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'DELAY :CONNECTIONS CONNS :INPUTS
      (FOL.COMPILER.COLLECTIONS:SET :IN) :OUTPUTS
      (FOL.COMPILER.COLLECTIONS:SET :OUT) :DELAYS
      (FOL.COMPILER.COLLECTIONS:DICT :IN
                                     (FOL.COMPILER.COLLECTIONS:DICT :OUT D))
      :LOGIC-FN
      (LAMBDA (S) (FOL.COMPILER.COLLECTIONS:DICT :OUT (GET S :IN)))))))

(DEFMACRO DEFPART (NAME PORTS &BODY BODY)
  `(REGISTER-MODULE ',NAME
    (MAKE <MODULE-DEF> :NAME ',NAME :PORTS ',PORTS :BODY ',BODY)))

(DEFUN QUALIFY-NAME (PREFIX NAME)
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (NIL? PREFIX))
      NAME
      (SYMBOL (STR PREFIX "/" NAME))))

(DEFUN RESOLVE-NODE (NODE-SYM PREFIX BINDINGS)
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (CONTAINS? BINDINGS NODE-SYM))
      (GET BINDINGS NODE-SYM)
      (QUALIFY-NAME PREFIX NODE-SYM)))

(DEFUN PARSE-CONNECTIONS (ARGS PREFIX BINDINGS)
  (BLOCK LOOP-BLOCK-1
    (LET ((REM ARGS) (ACC (FOL.COMPILER.COLLECTIONS:DICT)))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (PROGN
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (EMPTY? REM))
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
  (LET ((TYPE (FIRST SPEC)))
    (LET ((NAME (SECOND SPEC)))
      (LET ((RAW-ARGS (REST (REST SPEC))))
        (LET ((HAS-PARAM?
               (AND (NOT (EMPTY? RAW-ARGS)) (NOT (KEYWORD? (FIRST RAW-ARGS))))))
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
                      (COND
                       ((FOL.COMPILER.PRIMITIVES:TRUTHY? MODULE-DEF)
                        (REDUCE
                         (LAMBDA (ACC CHILD-SPEC)
                           (CONCAT ACC
                            (EXPAND-SPEC CHILD-SPEC FULL-NAME RESOLVED-CONNS)))
                         (FOL.COMPILER.COLLECTIONS:VECTOR)
                         (MODULE-BODY MODULE-DEF)))
                       ((FOL.COMPILER.PRIMITIVES:TRUTHY? PRIMITIVE-FACTORY)
                        (FOL.COMPILER.COLLECTIONS:VECTOR
                         (FUNCALL PRIMITIVE-FACTORY FULL-NAME PARAM
                                  RESOLVED-CONNS)))
                       ((FOL.COMPILER.PRIMITIVES:TRUTHY? :ELSE)
                        (FOL.COMPILER.COLLECTIONS:VECTOR
                         (MAKE <COMPONENT> :NAME FULL-NAME :TYPE TYPE
                          :CONNECTIONS RESOLVED-CONNS)))))))))))))))

(DEFUN EXPAND-NETLIST (TOP-MODULE-NAME)
  (LET ((DEF (GET-MODULE TOP-MODULE-NAME)))
    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (NIL? DEF))
        (ERROR (STR "Module " TOP-MODULE-NAME " not found"))
        (LET ((TOP-BINDINGS
               (REDUCE (LAMBDA (ACC P) (ASSOC ACC P P))
                       (FOL.COMPILER.COLLECTIONS:DICT) (MODULE-PORTS DEF))))
          (REDUCE
           (LAMBDA (ACC SPEC) (CONCAT ACC (EXPAND-SPEC SPEC NIL TOP-BINDINGS)))
           (FOL.COMPILER.COLLECTIONS:VECTOR) (MODULE-BODY DEF))))))

(DEFGENERIC REGISTER-CONNECTIVITY
    (COMP MAP))

(DEFMETHOD REGISTER-CONNECTIVITY (COMP MAP) MAP)

(DEFUN REGISTER-CONNECTIVITY (COMP MAP)
  (COND
   ((TYPEP COMP '<LOGIC-COMPONENT>)
    (REDUCE
     (LAMBDA (ACC PORT)
       (LET ((NODE (GET (COMPONENT-CONNECTIONS COMP) PORT)))
         (UPDATE ACC NODE
          (LAMBDA (COMPS)
            (CONJ (OR COMPS (FOL.COMPILER.COLLECTIONS:VECTOR)) COMP)))))
     MAP (COMPONENT-INPUTS COMP)))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S"
           'REGISTER-CONNECTIVITY (LIST COMP MAP)))))

(DEFUN INSERT-EVENT (QUEUE EVENT)
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (EMPTY? QUEUE))
      (FOL.COMPILER.COLLECTIONS:VECTOR EVENT)
      (LET ((HEAD (FIRST QUEUE)))
        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
             (< (GET EVENT :TIME) (GET HEAD :TIME)))
            (CONS EVENT QUEUE)
            (CONS HEAD (INSERT-EVENT (REST QUEUE) EVENT))))))

(DEFUN MERGE-EVENTS (QUEUE NEW-EVENTS) (REDUCE INSERT-EVENT QUEUE NEW-EVENTS))

(DEFUN GET-INPUT-STATES (COMP NODE-VALUES)
  (REDUCE
   (LAMBDA (ACC PORT)
     (LET ((NODE (GET (COMPONENT-CONNECTIONS COMP) PORT)))
       (ASSOC ACC PORT (GET NODE-VALUES NODE))))
   (FOL.COMPILER.COLLECTIONS:DICT) (COMPONENT-INPUTS COMP)))

(DEFUN GET-CHANGED-PORTS (COMP CHANGED-NODES)
  (FILTER
   (LAMBDA (PORT)
     (LET ((NODE (GET (COMPONENT-CONNECTIONS COMP) PORT)))
       (CONTAINS? CHANGED-NODES NODE)))
   (COMPONENT-INPUTS COMP)))

(DEFUN RUN-SIMULATION (NETLIST INITIAL-EVENTS MAX-TIME MONITORED-NODES)
  (LET ((CONNECTIVITY
         (REDUCE (LAMBDA (ACC C) (REGISTER-CONNECTIVITY C ACC))
                 (FOL.COMPILER.COLLECTIONS:DICT) NETLIST)))
    (BLOCK LOOP-BLOCK-2
      (LET ((QUEUE (SORT-BY :TIME INITIAL-EVENTS))
            (NODE-VALUES (FOL.COMPILER.COLLECTIONS:DICT))
            (EVENT-HISTORY (FOL.COMPILER.COLLECTIONS:DICT))
            (CURRENT-TIME 0))
        (TAGBODY
         LOOP-2
          (LET ((RESULT-2
                 (PROGN
                  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                       (OR (EMPTY? QUEUE) (> CURRENT-TIME MAX-TIME)))
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
                                    (FOL.COMPILER.COLLECTIONS:DICT) BATCH)))
                              (LET ((NEW-NODE-VALUES
                                     (MERGE NODE-VALUES UPDATES)))
                                (LET ((NEW-EVENT-HISTORY
                                       (REDUCE
                                        (LAMBDA (ACC EVT)
                                          (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                               (CONTAINS? MONITORED-NODES
                                                (GET EVT :NODE)))
                                              (UPDATE ACC (GET EVT :NODE)
                                               (LAMBDA (EVTS)
                                                 (CONJ
                                                  (OR EVTS
                                                      (FOL.COMPILER.COLLECTIONS:VECTOR))
                                                  EVT)))
                                              ACC))
                                        EVENT-HISTORY BATCH)))
                                  (LET ((CHANGED-NODES (KEYS UPDATES)))
                                    (LET ((AFFECTED-COMPS
                                           (REDUCE
                                            (LAMBDA (ACC NODE)
                                              (REDUCE CONJ ACC
                                                      (GET CONNECTIVITY NODE)))
                                            (FOL.COMPILER.COLLECTIONS:SET)
                                            CHANGED-NODES)))
                                      (LET ((NEW-EVENTS
                                             (MAPCAT
                                              (LAMBDA (COMP)
                                                (LET ((INPUT-STATES
                                                       (GET-INPUT-STATES COMP
                                                        NEW-NODE-VALUES)))
                                                  (LET ((CHANGED-PORTS
                                                         (GET-CHANGED-PORTS
                                                          COMP
                                                          (FOL.COMPILER.COLLECTIONS:SET
                                                           CHANGED-NODES))))
                                                    (LET ((RESULTS
                                                           (COMPUTE-NEXT-STATE
                                                            COMP INPUT-STATES
                                                            CHANGED-PORTS)))
                                                      (MAP
                                                       (LAMBDA (RES)
                                                         (FOL.COMPILER.COLLECTIONS:DICT
                                                          :NODE
                                                          (GET
                                                           (COMPONENT-CONNECTIONS
                                                            COMP)
                                                           (GET RES :PORT))
                                                          :VALUE
                                                          (GET RES :VALUE)
                                                          :TIME
                                                          (+ EVENT-TIME
                                                             (GET RES
                                                                  :DELAY))))
                                                       RESULTS)))))
                                              AFFECTED-COMPS)))
                                        (PROGN
                                         (PSETQ QUEUE
                                                  (MERGE-EVENTS REMAINING
                                                   NEW-EVENTS)
                                                NODE-VALUES NEW-NODE-VALUES
                                                EVENT-HISTORY NEW-EVENT-HISTORY
                                                CURRENT-TIME EVENT-TIME)
                                         (GO LOOP-2)))))))))))))))
            (RETURN-FROM LOOP-BLOCK-2 RESULT-2)))))))

(DEFVAR *SIM-CONTEXT*
  (ATOM
   (FOL.COMPILER.COLLECTIONS:DICT :EVENTS (FOL.COMPILER.COLLECTIONS:VECTOR)
                                  :MONITORED (FOL.COMPILER.COLLECTIONS:SET)
                                  :HISTORY (FOL.COMPILER.COLLECTIONS:DICT))))

(DEFUN MONITOR (&REST NODES)
  (FOL.COMPILER.MUTABLE:SWAP! *SIM-CONTEXT* #'UPDATE :MONITORED
                              (LAMBDA (S)
                                (INTO (OR S (FOL.COMPILER.COLLECTIONS:SET))
                                 NODES))))

(DEFUN EVENTS (&REST EVENTS)
  (FOL.COMPILER.MUTABLE:SWAP! *SIM-CONTEXT* #'UPDATE :EVENTS
                              (LAMBDA (Q) (CONCAT Q EVENTS))))

(DEFUN RUN (MODULE-NAME TIME)
  (LET ((NETLIST (EXPAND-NETLIST MODULE-NAME)))
    (LET ((INITIAL-EVENTS
           (GET (FOL.COMPILER.MUTABLE:DEREF *SIM-CONTEXT*) :EVENTS)))
      (LET ((MONITORED
             (GET (FOL.COMPILER.MUTABLE:DEREF *SIM-CONTEXT*) :MONITORED)))
        (LET ((HISTORY (RUN-SIMULATION NETLIST INITIAL-EVENTS TIME MONITORED)))
          (PROGN
           (FOL.COMPILER.MUTABLE:SWAP! *SIM-CONTEXT* #'ASSOC :HISTORY HISTORY)
           :SIMULATION-COMPLETE))))))

(DEFUN DISPLAY (&REST NODES)
  (LET ((HISTORY (GET (FOL.COMPILER.MUTABLE:DEREF *SIM-CONTEXT*) :HISTORY)))
    (MAP
     (LAMBDA (NODE)
       (PRINT (STR "Events for " NODE ":"))
       (LET ((EVTS (GET HISTORY NODE)))
         (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (EMPTY? EVTS))
             (PRINT "  (no events)")
             (MAP
              (LAMBDA (E)
                (PRINT (STR "  T=" (GET E :TIME) " V=" (GET E :VALUE))))
              EVTS))))
     NODES)))

