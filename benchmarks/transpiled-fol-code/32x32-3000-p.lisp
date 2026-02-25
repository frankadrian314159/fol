;;; 32x32-3000-p circuit definition
(in-package :fol.core)

(DEFPACKAGE "PLSIM"
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
                          "SYMBOL"))

(IN-PACKAGE "PLSIM")

;;; Register SR-LATCH module
(REGISTER-MODULE
 'SR-LATCH
 (MAKE '<MODULE-DEF> :NAME 'SR-LATCH :PORTS (VECTOR 'R 'S 'Q 'QBAR)
       :BODY
       (VECTOR (VECTOR 'NAND 'NAND1 :IN1 'S :IN2 'QBAR :OUT 'Q)
               (VECTOR 'NAND 'NAND2 :IN1 'R :IN2 'Q :OUT 'QBAR))))

;;; Register D-LATCH module
(REGISTER-MODULE
 'D-LATCH
 (MAKE '<MODULE-DEF> :NAME 'D-LATCH :PORTS (VECTOR 'CLK 'D 'Q 'QBAR)
       :BODY
       (VECTOR (VECTOR 'NAND 'NAND1 :IN1 'D :IN2 'CLK :OUT 'S)
               (VECTOR 'NAND 'NAND2 :IN1 'S :IN2 'CLK :OUT 'R)
               (VECTOR 'SR-LATCH 'LATCH :R 'R :S 'S :Q 'Q :QBAR 'QBAR))))

;;; Register REGISTER-32BIT module
(REGISTER-MODULE
 'REGISTER-32BIT
 (MAKE '<MODULE-DEF> :NAME 'REGISTER-32BIT :PORTS
       (apply #'VECTOR
              (append '(CLK)
                      (cl:loop for i below 32 collect (cl:intern (cl:format nil "D~D" i) "PLSIM"))
                      (cl:loop for i below 32 collect (cl:intern (cl:format nil "Q~D" i) "PLSIM"))))
       :BODY
       (apply #'VECTOR
              (cl:loop for i below 32
                       collect (VECTOR 'D-LATCH
                                       (cl:intern (cl:format nil "BIT~D" i) "PLSIM")
                                       :CLK 'CLK
                                       :D (cl:intern (cl:format nil "D~D" i) "PLSIM")
                                       :Q (cl:intern (cl:format nil "Q~D" i) "PLSIM")
                                       :QBAR (cl:intern (cl:format nil "QBAR~D" i) "PLSIM"))))))

;;; Programmatically build and register TOP32X32 module with 32 cascaded stages
(REGISTER-MODULE
 'TOP32X32
 (MAKE '<MODULE-DEF> :NAME 'TOP32X32 :PORTS (VECTOR)
       :BODY
       (apply #'VECTOR
              (cl:loop for stage below 32
                       collect
                       (let* ((reg-name (cl:intern (cl:format nil "REG~D" stage) "PLSIM"))
                              ;; Input signal prefix: stage 0 reads from D*, others from S<prev>Q*
                              (in-prefix (if (cl:= stage 0) "D" (cl:format nil "S~DQ" (cl:1- stage))))
                              ;; Output signal prefix: last stage writes to Q*, others to S<stage>Q*
                              (out-prefix (if (cl:= stage 31) "Q" (cl:format nil "S~DQ" stage))))
                         (apply #'VECTOR
                                (cl:append
                                 (cl:list 'REGISTER-32BIT reg-name :CLK 'CLK)
                                 (cl:loop for bit below 32
                                          append (cl:list
                                                  (cl:intern (cl:format nil "D~D" bit) "KEYWORD")
                                                  (cl:intern (cl:format nil "~A~D" in-prefix bit) "PLSIM")))
                                 (cl:loop for bit below 32
                                          append (cl:list
                                                  (cl:intern (cl:format nil "Q~D" bit) "KEYWORD")
                                                  (cl:intern (cl:format nil "~A~D" out-prefix bit) "PLSIM"))))))))))

;;; Monitor final outputs Q0..Q31
(apply #'MONITOR
       (cl:loop for i below 32
                collect (cl:intern (cl:format nil "Q~D" i) "PLSIM")))

;;; ADD-P1: even bits = 1, odd bits = 0
(DEFUN ADD-P1 (TIME-VAL)
  (apply #'ADDEVENTS
         (cl:loop for i below 32
                  collect (DICT :NODE (cl:intern (cl:format nil "D~D" i) "PLSIM")
                                :VALUE (if (cl:evenp i) 1 0)
                                :TIME TIME-VAL))))

;;; ADD-P2: even bits = 0, odd bits = 1
(DEFUN ADD-P2 (TIME-VAL)
  (apply #'ADDEVENTS
         (cl:loop for i below 32
                  collect (DICT :NODE (cl:intern (cl:format nil "D~D" i) "PLSIM")
                                :VALUE (if (cl:evenp i) 0 1)
                                :TIME TIME-VAL))))

;;; SETUP-SIMULATION: 300 data pattern changes + 300 clock events
(DEFUN SETUP-SIMULATION ()
  (cl:dotimes (k 300)
    (if (cl:evenp k)
        (ADD-P1 (cl:* k 10))
        (ADD-P2 (cl:* k 10))))
  (cl:dotimes (k 300)
    (ADDEVENTS
     (DICT :NODE 'CLK :VALUE 1 :TIME (+ 3 (cl:* k 10)))
     (DICT :NODE 'CLK :VALUE 0 :TIME (+ 8 (cl:* k 10))))))

(SETUP-SIMULATION)

(DEFUN RUN-BENCH ()
  (RUNLSIM 'TOP32X32 3000))
