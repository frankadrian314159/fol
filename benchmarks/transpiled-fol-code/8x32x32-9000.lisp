;;; Transpiled from 8x32x32-9000.fol
(in-package :fol.core)

(DEFPACKAGE "LSIM"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE))

(IN-PACKAGE "LSIM")

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('SR-LATCH
           (IF (FBOUNDP 'MAKE)
               (MAKE
                . #2=('<MODULE-DEF> :NAME 'SR-LATCH :PORTS
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'R 'S 'Q 'QBAR)
                      :BODY
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'NAND 'NAND1
                                                                 :IN1 'S :IN2
                                                                 'QBAR :OUT 'Q)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'NAND 'NAND2
                                                                 :IN1 'R :IN2
                                                                 'Q :OUT
                                                                 'QBAR))))
               (LET ((#3=#:VAL241 MAKE))
                 (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                       (T
                        (ERROR #4="~S is not a function or collection"
                               'MAKE)))))))
    (LET ((#5=#:VAL242 REGISTER-MODULE))
      (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #5# . #1#))
            (T (ERROR #4# 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('D-LATCH
           (IF (FBOUNDP 'MAKE)
               (MAKE
                . #2=('<MODULE-DEF> :NAME 'D-LATCH :PORTS
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'CLK 'D 'Q
                                                                'QBAR)
                      :BODY
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'NAND 'NAND1
                                                                 :IN1 'D :IN2
                                                                 'CLK :OUT 'S)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'NAND 'NAND2
                                                                 :IN1 'S :IN2
                                                                 'CLK :OUT 'R)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'SR-LATCH
                                                                 'LATCH :R 'R
                                                                 :S 'S :Q 'Q
                                                                 :QBAR
                                                                 'QBAR))))
               (LET ((#3=#:VAL243 MAKE))
                 (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                       (T
                        (ERROR #4="~S is not a function or collection"
                               'MAKE)))))))
    (LET ((#5=#:VAL244 REGISTER-MODULE))
      (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #5# . #1#))
            (T (ERROR #4# 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('REGISTER-32BIT
           (IF (FBOUNDP 'MAKE)
               (MAKE
                . #2=('<MODULE-DEF> :NAME 'REGISTER-32BIT :PORTS
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'CLK 'D0 'D1
                                                                'D2 'D3 'D4 'D5
                                                                'D6 'D7 'D8 'D9
                                                                'D10 'D11 'D12
                                                                'D13 'D14 'D15
                                                                'D16 'D17 'D18
                                                                'D19 'D20 'D21
                                                                'D22 'D23 'D24
                                                                'D25 'D26 'D27
                                                                'D28 'D29 'D30
                                                                'D31 'Q0 'Q1
                                                                'Q2 'Q3 'Q4 'Q5
                                                                'Q6 'Q7 'Q8 'Q9
                                                                'Q10 'Q11 'Q12
                                                                'Q13 'Q14 'Q15
                                                                'Q16 'Q17 'Q18
                                                                'Q19 'Q20 'Q21
                                                                'Q22 'Q23 'Q24
                                                                'Q25 'Q26 'Q27
                                                                'Q28 'Q29 'Q30
                                                                'Q31)
                      :BODY
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT0
                                                                 :CLK 'CLK :D
                                                                 'D0 :Q 'Q0
                                                                 :QBAR 'QBAR0)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT1
                                                                 :CLK 'CLK :D
                                                                 'D1 :Q 'Q1
                                                                 :QBAR 'QBAR1)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT2
                                                                 :CLK 'CLK :D
                                                                 'D2 :Q 'Q2
                                                                 :QBAR 'QBAR2)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT3
                                                                 :CLK 'CLK :D
                                                                 'D3 :Q 'Q3
                                                                 :QBAR 'QBAR3)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT4
                                                                 :CLK 'CLK :D
                                                                 'D4 :Q 'Q4
                                                                 :QBAR 'QBAR4)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT5
                                                                 :CLK 'CLK :D
                                                                 'D5 :Q 'Q5
                                                                 :QBAR 'QBAR5)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT6
                                                                 :CLK 'CLK :D
                                                                 'D6 :Q 'Q6
                                                                 :QBAR 'QBAR6)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT7
                                                                 :CLK 'CLK :D
                                                                 'D7 :Q 'Q7
                                                                 :QBAR 'QBAR7)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT8
                                                                 :CLK 'CLK :D
                                                                 'D8 :Q 'Q8
                                                                 :QBAR 'QBAR8)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH 'BIT9
                                                                 :CLK 'CLK :D
                                                                 'D9 :Q 'Q9
                                                                 :QBAR 'QBAR9)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT10 :CLK
                                                                 'CLK :D 'D10
                                                                 :Q 'Q10 :QBAR
                                                                 'QBAR10)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT11 :CLK
                                                                 'CLK :D 'D11
                                                                 :Q 'Q11 :QBAR
                                                                 'QBAR11)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT12 :CLK
                                                                 'CLK :D 'D12
                                                                 :Q 'Q12 :QBAR
                                                                 'QBAR12)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT13 :CLK
                                                                 'CLK :D 'D13
                                                                 :Q 'Q13 :QBAR
                                                                 'QBAR13)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT14 :CLK
                                                                 'CLK :D 'D14
                                                                 :Q 'Q14 :QBAR
                                                                 'QBAR14)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT15 :CLK
                                                                 'CLK :D 'D15
                                                                 :Q 'Q15 :QBAR
                                                                 'QBAR15)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT16 :CLK
                                                                 'CLK :D 'D16
                                                                 :Q 'Q16 :QBAR
                                                                 'QBAR16)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT17 :CLK
                                                                 'CLK :D 'D17
                                                                 :Q 'Q17 :QBAR
                                                                 'QBAR17)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT18 :CLK
                                                                 'CLK :D 'D18
                                                                 :Q 'Q18 :QBAR
                                                                 'QBAR18)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT19 :CLK
                                                                 'CLK :D 'D19
                                                                 :Q 'Q19 :QBAR
                                                                 'QBAR19)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT20 :CLK
                                                                 'CLK :D 'D20
                                                                 :Q 'Q20 :QBAR
                                                                 'QBAR20)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT21 :CLK
                                                                 'CLK :D 'D21
                                                                 :Q 'Q21 :QBAR
                                                                 'QBAR21)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT22 :CLK
                                                                 'CLK :D 'D22
                                                                 :Q 'Q22 :QBAR
                                                                 'QBAR22)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT23 :CLK
                                                                 'CLK :D 'D23
                                                                 :Q 'Q23 :QBAR
                                                                 'QBAR23)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT24 :CLK
                                                                 'CLK :D 'D24
                                                                 :Q 'Q24 :QBAR
                                                                 'QBAR24)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT25 :CLK
                                                                 'CLK :D 'D25
                                                                 :Q 'Q25 :QBAR
                                                                 'QBAR25)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT26 :CLK
                                                                 'CLK :D 'D26
                                                                 :Q 'Q26 :QBAR
                                                                 'QBAR26)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT27 :CLK
                                                                 'CLK :D 'D27
                                                                 :Q 'Q27 :QBAR
                                                                 'QBAR27)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT28 :CLK
                                                                 'CLK :D 'D28
                                                                 :Q 'Q28 :QBAR
                                                                 'QBAR28)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT29 :CLK
                                                                 'CLK :D 'D29
                                                                 :Q 'Q29 :QBAR
                                                                 'QBAR29)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT30 :CLK
                                                                 'CLK :D 'D30
                                                                 :Q 'Q30 :QBAR
                                                                 'QBAR30)
                       (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR 'D-LATCH
                                                                 'BIT31 :CLK
                                                                 'CLK :D 'D31
                                                                 :Q 'Q31 :QBAR
                                                                 'QBAR31))))
               (LET ((#3=#:VAL245 MAKE))
                 (COND ((FUNCTIONP #3#) (FUNCALL #3# . #2#))
                       (T
                        (ERROR #4="~S is not a function or collection"
                               'MAKE)))))))
    (LET ((#5=#:VAL246 REGISTER-MODULE))
      (COND ((FUNCTIONP #5#) (FUNCALL #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<DICT>)
             (FOL.COMPILER.COLLECTIONS:GET #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #5# . #1#))
            ((TYPEP #5# 'FOL.COMPILER.COLLECTIONS:<SET>)
             (FOL.COMPILER.COLLECTIONS:GET #5# . #1#))
            (T (ERROR #4# 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('PIPELINE-32X32
           (IF (FBOUNDP 'MAKE)
               (MAKE
                . #2=('<MODULE-DEF> :NAME 'PIPELINE-32X32 :PORTS
                      (LET ((P
                             (BLOCK LOOP-BLOCK-1
                               (LET ((I 0)
                                     (ACC
                                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                                       'CLK)))
                                 (TAGBODY
                                  LOOP-1
                                   (LET ((RESULT-1
                                          (PROGN
                                           (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                (< I 32))
                                               (PROGN
                                                (PSETQ I (1+ I)
                                                       ACC
                                                         (IF (FBOUNDP 'CONJ)
                                                             (CONJ
                                                              . #3=(ACC
                                                                    (INTERN
                                                                     (FORMAT
                                                                      NIL "D~D"
                                                                      I))))
                                                             (LET ((#4=#:VAL247
                                                                    CONJ))
                                                               (COND
                                                                ((FUNCTIONP
                                                                  #4#)
                                                                 (FUNCALL #4#
                                                                          . #3#))
                                                                ((TYPEP #4#
                                                                        . #5=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                                 (FOL.COMPILER.COLLECTIONS:GET
                                                                  #4# . #3#))
                                                                ((TYPEP #4#
                                                                        . #6=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                                 (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                  #4# . #3#))
                                                                ((TYPEP #4#
                                                                        . #7=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                                 (FOL.COMPILER.COLLECTIONS:GET
                                                                  #4# . #3#))
                                                                (T
                                                                 (ERROR
                                                                  #8="~S is not a function or collection"
                                                                  'CONJ))))))
                                                (GO LOOP-1))
                                               ACC))))
                                     (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))
                        (BLOCK LOOP-BLOCK-2
                          (LET ((I 0) (ACC P))
                            (TAGBODY
                             LOOP-2
                              (LET ((RESULT-2
                                     (PROGN
                                      (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                           (< I 32))
                                          (PROGN
                                           (PSETQ I (1+ I)
                                                  ACC
                                                    (IF (FBOUNDP 'CONJ)
                                                        (CONJ
                                                         . #9=(ACC
                                                               (INTERN
                                                                (FORMAT NIL
                                                                        "Q~D"
                                                                        I))))
                                                        (LET ((#10=#:VAL248
                                                               CONJ))
                                                          (COND
                                                           ((FUNCTIONP #10#)
                                                            (FUNCALL #10#
                                                                     . #9#))
                                                           ((TYPEP #10# . #5#)
                                                            (FOL.COMPILER.COLLECTIONS:GET
                                                             #10# . #9#))
                                                           ((TYPEP #10# . #6#)
                                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                             #10# . #9#))
                                                           ((TYPEP #10# . #7#)
                                                            (FOL.COMPILER.COLLECTIONS:GET
                                                             #10# . #9#))
                                                           (T
                                                            (ERROR #8#
                                                                   'CONJ))))))
                                           (GO LOOP-2))
                                          ACC))))
                                (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))
                      :BODY
                      (LET ((GENERATE-STAGE
                             (LAMBDA (STAGE)
                               (DECLARE (SPECIAL CONJ))
                               (LET ((REG-NAME
                                      (INTERN (FORMAT NIL "REG~D" STAGE))))
                                 (LET ((SPEC
                                        (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                                         'REGISTER-32BIT REG-NAME :CLK 'CLK)))
                                   (BLOCK LOOP-BLOCK-3
                                     (LET ((BIT 0) (CURR-SPEC SPEC))
                                       (TAGBODY
                                        LOOP-3
                                         (LET ((RESULT-3
                                                (PROGN
                                                 (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                      (< BIT 32))
                                                     (LET ((DK
                                                            (INTERN
                                                             (FORMAT NIL "D~D"
                                                                     BIT)
                                                             "KEYWORD")))
                                                       (LET ((QK
                                                              (INTERN
                                                               (FORMAT NIL
                                                                       "Q~D"
                                                                       BIT)
                                                               "KEYWORD")))
                                                         (LET ((D-WIRE
                                                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                     (= STAGE
                                                                        0))
                                                                    (INTERN
                                                                     (FORMAT
                                                                      NIL "D~D"
                                                                      BIT))
                                                                    (INTERN
                                                                     (FORMAT
                                                                      NIL
                                                                      "S~DQ~D"
                                                                      (- STAGE
                                                                         1)
                                                                      BIT)))))
                                                           (LET ((Q-WIRE
                                                                  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                       (= STAGE
                                                                          31))
                                                                      (INTERN
                                                                       (FORMAT
                                                                        NIL
                                                                        "Q~D"
                                                                        BIT))
                                                                      (INTERN
                                                                       (FORMAT
                                                                        NIL
                                                                        "S~DQ~D"
                                                                        STAGE
                                                                        BIT)))))
                                                             (PROGN
                                                              (PSETQ BIT
                                                                       (1+ BIT)
                                                                     CURR-SPEC
                                                                       (IF (FBOUNDP
                                                                            'CONJ)
                                                                           (CONJ
                                                                            . #11=(CURR-SPEC
                                                                                   DK
                                                                                   D-WIRE
                                                                                   QK
                                                                                   Q-WIRE))
                                                                           (LET ((#12=#:VAL249
                                                                                  CONJ))
                                                                             (COND
                                                                              ((FUNCTIONP
                                                                                #12#)
                                                                               (FUNCALL
                                                                                #12#
                                                                                . #11#))
                                                                              (T
                                                                               (ERROR
                                                                                #8#
                                                                                'CONJ))))))
                                                              (GO LOOP-3))))))
                                                     CURR-SPEC))))
                                           (RETURN-FROM LOOP-BLOCK-3
                                             RESULT-3))))))))))
                        (BLOCK LOOP-BLOCK-4
                          (LET ((STAGE 0)
                                (BODY
                                 (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR)))
                            (TAGBODY
                             LOOP-4
                              (LET ((RESULT-4
                                     (PROGN
                                      (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                           (< STAGE 32))
                                          (PROGN
                                           (PSETQ STAGE (1+ STAGE)
                                                  BODY
                                                    (IF (FBOUNDP 'CONJ)
                                                        (CONJ
                                                         . #13=(BODY
                                                                (LET ((#14=#:OP250
                                                                       GENERATE-STAGE))
                                                                  (COND
                                                                   ((FUNCTIONP
                                                                     #14#)
                                                                    (FUNCALL
                                                                     #14#
                                                                     . #15=(STAGE)))
                                                                   ((TYPEP #14#
                                                                           . #5#)
                                                                    (FOL.COMPILER.COLLECTIONS:GET
                                                                     #14#
                                                                     . #15#))
                                                                   ((TYPEP #14#
                                                                           . #6#)
                                                                    (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                     #14#
                                                                     . #15#))
                                                                   ((TYPEP #14#
                                                                           . #7#)
                                                                    (FOL.COMPILER.COLLECTIONS:GET
                                                                     #14#
                                                                     . #15#))
                                                                   (T
                                                                    (ERROR
                                                                     "Value ~S is not callable or a collection"
                                                                     #14#))))))
                                                        (LET ((#16=#:VAL251
                                                               CONJ))
                                                          (COND
                                                           ((FUNCTIONP #16#)
                                                            (FUNCALL #16#
                                                                     . #13#))
                                                           ((TYPEP #16# . #5#)
                                                            (FOL.COMPILER.COLLECTIONS:GET
                                                             #16# . #13#))
                                                           ((TYPEP #16# . #6#)
                                                            (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                             #16# . #13#))
                                                           ((TYPEP #16# . #7#)
                                                            (FOL.COMPILER.COLLECTIONS:GET
                                                             #16# . #13#))
                                                           (T
                                                            (ERROR #8#
                                                                   'CONJ))))))
                                           (GO LOOP-4))
                                          BODY))))
                                (RETURN-FROM LOOP-BLOCK-4 RESULT-4))))))))
               (LET ((#17=#:VAL252 MAKE))
                 (COND ((FUNCTIONP #17#) (FUNCALL #17# . #2#))
                       (T (ERROR #8# 'MAKE)))))))
    (LET ((#18=#:VAL253 REGISTER-MODULE))
      (COND ((FUNCTIONP #18#) (FUNCALL #18# . #1#))
            ((TYPEP #18# . #5#) (FOL.COMPILER.COLLECTIONS:GET #18# . #1#))
            ((TYPEP #18# . #6#)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #18# . #1#))
            ((TYPEP #18# . #7#) (FOL.COMPILER.COLLECTIONS:GET #18# . #1#))
            (T (ERROR #8# 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('TOP8X32X32
           (IF (FBOUNDP 'MAKE)
               (MAKE
                . #2=('<MODULE-DEF> :NAME 'TOP8X32X32 :PORTS
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR) :BODY
                      (BLOCK LOOP-BLOCK-5
                        (LET ((P-IDX 0)
                              (BODY (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR)))
                          (TAGBODY
                           LOOP-5
                            (LET ((RESULT-5
                                   (PROGN
                                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                         (< P-IDX 8))
                                        (LET ((INST-NAME
                                               (INTERN
                                                (FORMAT NIL "PIPE~D" P-IDX))))
                                          (LET ((SPEC
                                                 (FOL.COMPILER.COLLECTION-FUNCTIONS:VECTOR
                                                  'PIPELINE-32X32 INST-NAME
                                                  :CLK 'CLK)))
                                            (LET ((FULL-SPEC
                                                   (BLOCK LOOP-BLOCK-6
                                                     (LET ((BIT 0)
                                                           (CURR-SPEC SPEC))
                                                       (TAGBODY
                                                        LOOP-6
                                                         (LET ((RESULT-6
                                                                (PROGN
                                                                 (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                      (< BIT
                                                                         32))
                                                                     (LET ((DK
                                                                            (INTERN
                                                                             (FORMAT
                                                                              NIL
                                                                              "D~D"
                                                                              BIT)
                                                                             "KEYWORD")))
                                                                       (LET ((QK
                                                                              (INTERN
                                                                               (FORMAT
                                                                                NIL
                                                                                "Q~D"
                                                                                BIT)
                                                                               "KEYWORD")))
                                                                         (LET ((D-WIRE
                                                                                (INTERN
                                                                                 (FORMAT
                                                                                  NIL
                                                                                  "D~D"
                                                                                  BIT))))
                                                                           (LET ((Q-WIRE
                                                                                  (INTERN
                                                                                   (FORMAT
                                                                                    NIL
                                                                                    "P~DQ~D"
                                                                                    P-IDX
                                                                                    BIT))))
                                                                             (PROGN
                                                                              (PSETQ BIT
                                                                                       (1+
                                                                                        BIT)
                                                                                     CURR-SPEC
                                                                                       (IF (FBOUNDP
                                                                                            'CONJ)
                                                                                           (CONJ
                                                                                            . #3=(CURR-SPEC
                                                                                                  DK
                                                                                                  D-WIRE
                                                                                                  QK
                                                                                                  Q-WIRE))
                                                                                           (LET ((#4=#:VAL254
                                                                                                  CONJ))
                                                                                             (COND
                                                                                              ((FUNCTIONP
                                                                                                #4#)
                                                                                               (FUNCALL
                                                                                                #4#
                                                                                                . #3#))
                                                                                              (T
                                                                                               (ERROR
                                                                                                #5="~S is not a function or collection"
                                                                                                'CONJ))))))
                                                                              (GO
                                                                               LOOP-6))))))
                                                                     CURR-SPEC))))
                                                           (RETURN-FROM
                                                               LOOP-BLOCK-6
                                                             RESULT-6)))))))
                                              (PROGN
                                               (PSETQ P-IDX (1+ P-IDX)
                                                      BODY
                                                        (IF (FBOUNDP 'CONJ)
                                                            (CONJ
                                                             . #6=(BODY
                                                                   FULL-SPEC))
                                                            (LET ((#7=#:VAL255
                                                                   CONJ))
                                                              (COND
                                                               ((FUNCTIONP #7#)
                                                                (FUNCALL #7#
                                                                         . #6#))
                                                               ((TYPEP #7#
                                                                       . #8=('FOL.COMPILER.COLLECTIONS:<DICT>))
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #7# . #6#))
                                                               ((TYPEP #7#
                                                                       . #9=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                                                                (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH
                                                                 #7# . #6#))
                                                               ((TYPEP #7#
                                                                       . #10=('FOL.COMPILER.COLLECTIONS:<SET>))
                                                                (FOL.COMPILER.COLLECTIONS:GET
                                                                 #7# . #6#))
                                                               (T
                                                                (ERROR #5#
                                                                       'CONJ))))))
                                               (GO LOOP-5)))))
                                        BODY))))
                              (RETURN-FROM LOOP-BLOCK-5 RESULT-5)))))))
               (LET ((#11=#:VAL256 MAKE))
                 (COND ((FUNCTIONP #11#) (FUNCALL #11# . #2#))
                       (T (ERROR #5# 'MAKE)))))))
    (LET ((#12=#:VAL257 REGISTER-MODULE))
      (COND ((FUNCTIONP #12#) (FUNCALL #12# . #1#))
            ((TYPEP #12# . #8#) (FOL.COMPILER.COLLECTIONS:GET #12# . #1#))
            ((TYPEP #12# . #9#)
             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #12# . #1#))
            ((TYPEP #12# . #10#) (FOL.COMPILER.COLLECTIONS:GET #12# . #1#))
            (T (ERROR #5# 'REGISTER-MODULE)))))

(BLOCK LOOP-BLOCK-7
  (LET ((P-IDX 0))
    (TAGBODY
     LOOP-7
      (LET ((RESULT-7
             (PROGN
              (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< P-IDX 8))
                  (PROGN
                   (BLOCK LOOP-BLOCK-8
                     (LET ((BIT-IDX 0))
                       (TAGBODY
                        LOOP-8
                         (LET ((RESULT-8
                                (PROGN
                                 (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                      (< BIT-IDX 32))
                                     (PROGN
                                      (IF (FBOUNDP 'MONITOR)
                                          (MONITOR
                                           . #1=((INTERN
                                                  (FORMAT NIL "P~DQ~D" P-IDX
                                                          BIT-IDX))))
                                          (LET ((#2=#:VAL258 MONITOR))
                                            (COND
                                             ((FUNCTIONP #2#)
                                              (FUNCALL #2# . #1#))
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
                                               'MONITOR)))))
                                      (PROGN
                                       (PSETQ BIT-IDX (1+ BIT-IDX))
                                       (GO LOOP-8)))
                                     NIL))))
                           (RETURN-FROM LOOP-BLOCK-8 RESULT-8)))))
                   (PROGN (PSETQ P-IDX (1+ P-IDX)) (GO LOOP-7)))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-7 RESULT-7)))))

(DEFUN ADD-P1 (TIME-VAL)
  (DECLARE (SPECIAL ADDEVENTS))
  (BLOCK LOOP-BLOCK-9
    (LET ((I 0))
      (TAGBODY
       LOOP-9
        (LET ((RESULT-9
               (PROGN
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< I 32))
                    (PROGN
                     (IF (FBOUNDP 'ADDEVENTS)
                         (ADDEVENTS
                          . #1=((FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :TIME
                                                                        TIME-VAL
                                                                        :VALUE
                                                                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                             (EVENP
                                                                              I))
                                                                            1
                                                                            0)
                                                                        :NODE
                                                                        (INTERN
                                                                         (FORMAT
                                                                          NIL
                                                                          "D~D"
                                                                          I)))))
                         (LET ((#2=#:VAL259 ADDEVENTS))
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
                                         'ADDEVENTS)))))
                     (PROGN (PSETQ I (1+ I)) (GO LOOP-9)))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-9 RESULT-9))))))

(DEFUN ADD-P2 (TIME-VAL)
  (DECLARE (SPECIAL ADDEVENTS))
  (BLOCK LOOP-BLOCK-10
    (LET ((I 0))
      (TAGBODY
       LOOP-10
        (LET ((RESULT-10
               (PROGN
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< I 32))
                    (PROGN
                     (IF (FBOUNDP 'ADDEVENTS)
                         (ADDEVENTS
                          . #1=((FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :TIME
                                                                        TIME-VAL
                                                                        :VALUE
                                                                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                             (EVENP
                                                                              I))
                                                                            0
                                                                            1)
                                                                        :NODE
                                                                        (INTERN
                                                                         (FORMAT
                                                                          NIL
                                                                          "D~D"
                                                                          I)))))
                         (LET ((#2=#:VAL260 ADDEVENTS))
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
                                         'ADDEVENTS)))))
                     (PROGN (PSETQ I (1+ I)) (GO LOOP-10)))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-10 RESULT-10))))))

(DEFUN SETUP-SIMULATION ()
  (DECLARE (SPECIAL ADDEVENTS))
  (BLOCK LOOP-BLOCK-11
    (LET ((K 0))
      (TAGBODY
       LOOP-11
        (LET ((RESULT-11
               (PROGN
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< K 900))
                    (PROGN
                     (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (EVENP K))
                         (ADD-P1 (* K 10))
                         (ADD-P2 (* K 10)))
                     (PROGN (PSETQ K (1+ K)) (GO LOOP-11)))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-11 RESULT-11)))))
  (BLOCK LOOP-BLOCK-12
    (LET ((K 0))
      (TAGBODY
       LOOP-12
        (LET ((RESULT-12
               (PROGN
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< K 900))
                    (PROGN
                     (IF (FBOUNDP 'ADDEVENTS)
                         (ADDEVENTS
                          . #1=((FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :TIME
                                                                        (+ 3
                                                                           (* K
                                                                              10))
                                                                        :VALUE
                                                                        1 :NODE
                                                                        'CLK)
                                (FOL.COMPILER.COLLECTION-FUNCTIONS:DICT :TIME
                                                                        (+ 8
                                                                           (* K
                                                                              10))
                                                                        :VALUE
                                                                        0 :NODE
                                                                        'CLK)))
                         (LET ((#2=#:VAL261 ADDEVENTS))
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
                                         'ADDEVENTS)))))
                     (PROGN (PSETQ K (1+ K)) (GO LOOP-12)))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-12 RESULT-12))))))

(SETUP-SIMULATION)

(DEFUN RUN-BENCH ()
  (DECLARE (SPECIAL RUNLSIM))
  (IF (FBOUNDP 'RUNLSIM)
      (RUNLSIM . #1=('TOP8X32X32 9000))
      (LET ((#2=#:VAL262 RUNLSIM))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<DICT>)
               (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
              ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<VECTOR>)
               (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
              ((TYPEP #2# 'FOL.COMPILER.COLLECTIONS:<SET>)
               (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'RUNLSIM))))))
