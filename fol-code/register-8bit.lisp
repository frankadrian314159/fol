;;; Transpiled from register-8bit.fol by FOL compiler

;;; This file was automatically generated. Do not edit directly.

(REGISTER-PRIMITIVE 'D-LATCH
 (LAMBDA (NAME PARAM CONNS)
   (MAKE <LOGIC-COMPONENT> :NAME NAME :TYPE 'D-LATCH :CONNECTIONS CONNS :INPUTS
    (FOL.COMPILER.CL-UTILS:MAKE-CL-SET :CLK :D) :OUTPUTS
    (FOL.COMPILER.CL-UTILS:MAKE-CL-SET :Q) :DELAYS
    (FOL.COMPILER.CL-UTILS:MAKE-CL-DICT :CLK
                                        (FOL.COMPILER.CL-UTILS:MAKE-CL-DICT :Q
                                                                            3)
                                        :D
                                        (FOL.COMPILER.CL-UTILS:MAKE-CL-DICT :Q
                                                                            4))
    :LOGIC-FN
    (LAMBDA (S)
      (LET ((D (GET S :D)))
        (LET ((CLK (GET S :CLK)))
          (LET ((PREV-Q (GET S :PREV-Q NIL)))
            (FOL.COMPILER.CL-UTILS:MAKE-CL-DICT :PREV-Q
                                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                     CLK)
                                                    D
                                                    PREV-Q)
                                                :Q
                                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                     CLK)
                                                    D
                                                    PREV-Q)))))))))

(DEFPART REGISTER-8BIT
 (FOL.COMPILER.CL-UTILS:MAKE-CL-VECTOR D0 D1 D2 D3 D4 D5 D6 D7 CLK Q0 Q1 Q2 Q3
                                       Q4 Q5 Q6 Q7)
 (D-LATCH LATCH0 :D D0 :CLK CLK :Q Q0) (D-LATCH LATCH1 :D D1 :CLK CLK :Q Q1)
 (D-LATCH LATCH2 :D D2 :CLK CLK :Q Q2) (D-LATCH LATCH3 :D D3 :CLK CLK :Q Q3)
 (D-LATCH LATCH4 :D D4 :CLK CLK :Q Q4) (D-LATCH LATCH5 :D D5 :CLK CLK :Q Q5)
 (D-LATCH LATCH6 :D D6 :CLK CLK :Q Q6) (D-LATCH LATCH7 :D D7 :CLK CLK :Q Q7))

(DEFPART TEST-REGISTER-8BIT
 (FOL.COMPILER.CL-UTILS:MAKE-CL-VECTOR CLK IN0 IN1 IN2 IN3 IN4 IN5 IN6 IN7)
 (REGISTER-8BIT REG :D0 IN0 :D1 IN1 :D2 IN2 :D3 IN3 :D4 IN4 :D5 IN5 :D6 IN6 :D7
  IN7 :CLK CLK :Q0 OUT0 :Q1 OUT1 :Q2 OUT2 :Q3 OUT3 :Q4 OUT4 :Q5 OUT5 :Q6 OUT6
  :Q7 OUT7))

