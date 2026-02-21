;;; Transpiled from 8x32-900.fol
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
                          "SYMBOL"))

(IN-PACKAGE "LSIM")

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('SR-LATCH
           (MAKE '<MODULE-DEF> :NAME 'SR-LATCH :PORTS (VECTOR 'R 'S 'Q 'QBAR)
                 :BODY
                 (VECTOR (VECTOR 'NAND 'NAND1 :IN1 'S :IN2 'QBAR :OUT 'Q)
                         (VECTOR 'NAND 'NAND2 :IN1 'R :IN2 'Q :OUT 'QBAR)))))
    (LET ((#2=#:VAL371 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('D-LATCH
           (MAKE '<MODULE-DEF> :NAME 'D-LATCH :PORTS (VECTOR 'CLK 'D 'Q 'QBAR)
                 :BODY
                 (VECTOR (VECTOR 'NAND 'NAND1 :IN1 'D :IN2 'CLK :OUT 'S)
                         (VECTOR 'NAND 'NAND2 :IN1 'S :IN2 'CLK :OUT 'R)
                         (VECTOR 'SR-LATCH 'LATCH :R 'R :S 'S :Q 'Q :QBAR
                                 'QBAR)))))
    (LET ((#2=#:VAL372 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('REGISTER-32BIT
           (MAKE '<MODULE-DEF> :NAME 'REGISTER-32BIT :PORTS
                 (VECTOR 'CLK 'D0 'D1 'D2 'D3 'D4 'D5 'D6 'D7 'D8 'D9 'D10 'D11
                         'D12 'D13 'D14 'D15 'D16 'D17 'D18 'D19 'D20 'D21 'D22
                         'D23 'D24 'D25 'D26 'D27 'D28 'D29 'D30 'D31 'Q0 'Q1
                         'Q2 'Q3 'Q4 'Q5 'Q6 'Q7 'Q8 'Q9 'Q10 'Q11 'Q12 'Q13
                         'Q14 'Q15 'Q16 'Q17 'Q18 'Q19 'Q20 'Q21 'Q22 'Q23 'Q24
                         'Q25 'Q26 'Q27 'Q28 'Q29 'Q30 'Q31)
                 :BODY
                 (VECTOR
                  (VECTOR 'D-LATCH 'BIT0 :CLK 'CLK :D 'D0 :Q 'Q0 :QBAR 'QBAR0)
                  (VECTOR 'D-LATCH 'BIT1 :CLK 'CLK :D 'D1 :Q 'Q1 :QBAR 'QBAR1)
                  (VECTOR 'D-LATCH 'BIT2 :CLK 'CLK :D 'D2 :Q 'Q2 :QBAR 'QBAR2)
                  (VECTOR 'D-LATCH 'BIT3 :CLK 'CLK :D 'D3 :Q 'Q3 :QBAR 'QBAR3)
                  (VECTOR 'D-LATCH 'BIT4 :CLK 'CLK :D 'D4 :Q 'Q4 :QBAR 'QBAR4)
                  (VECTOR 'D-LATCH 'BIT5 :CLK 'CLK :D 'D5 :Q 'Q5 :QBAR 'QBAR5)
                  (VECTOR 'D-LATCH 'BIT6 :CLK 'CLK :D 'D6 :Q 'Q6 :QBAR 'QBAR6)
                  (VECTOR 'D-LATCH 'BIT7 :CLK 'CLK :D 'D7 :Q 'Q7 :QBAR 'QBAR7)
                  (VECTOR 'D-LATCH 'BIT8 :CLK 'CLK :D 'D8 :Q 'Q8 :QBAR 'QBAR8)
                  (VECTOR 'D-LATCH 'BIT9 :CLK 'CLK :D 'D9 :Q 'Q9 :QBAR 'QBAR9)
                  (VECTOR 'D-LATCH 'BIT10 :CLK 'CLK :D 'D10 :Q 'Q10 :QBAR
                          'QBAR10)
                  (VECTOR 'D-LATCH 'BIT11 :CLK 'CLK :D 'D11 :Q 'Q11 :QBAR
                          'QBAR11)
                  (VECTOR 'D-LATCH 'BIT12 :CLK 'CLK :D 'D12 :Q 'Q12 :QBAR
                          'QBAR12)
                  (VECTOR 'D-LATCH 'BIT13 :CLK 'CLK :D 'D13 :Q 'Q13 :QBAR
                          'QBAR13)
                  (VECTOR 'D-LATCH 'BIT14 :CLK 'CLK :D 'D14 :Q 'Q14 :QBAR
                          'QBAR14)
                  (VECTOR 'D-LATCH 'BIT15 :CLK 'CLK :D 'D15 :Q 'Q15 :QBAR
                          'QBAR15)
                  (VECTOR 'D-LATCH 'BIT16 :CLK 'CLK :D 'D16 :Q 'Q16 :QBAR
                          'QBAR16)
                  (VECTOR 'D-LATCH 'BIT17 :CLK 'CLK :D 'D17 :Q 'Q17 :QBAR
                          'QBAR17)
                  (VECTOR 'D-LATCH 'BIT18 :CLK 'CLK :D 'D18 :Q 'Q18 :QBAR
                          'QBAR18)
                  (VECTOR 'D-LATCH 'BIT19 :CLK 'CLK :D 'D19 :Q 'Q19 :QBAR
                          'QBAR19)
                  (VECTOR 'D-LATCH 'BIT20 :CLK 'CLK :D 'D20 :Q 'Q20 :QBAR
                          'QBAR20)
                  (VECTOR 'D-LATCH 'BIT21 :CLK 'CLK :D 'D21 :Q 'Q21 :QBAR
                          'QBAR21)
                  (VECTOR 'D-LATCH 'BIT22 :CLK 'CLK :D 'D22 :Q 'Q22 :QBAR
                          'QBAR22)
                  (VECTOR 'D-LATCH 'BIT23 :CLK 'CLK :D 'D23 :Q 'Q23 :QBAR
                          'QBAR23)
                  (VECTOR 'D-LATCH 'BIT24 :CLK 'CLK :D 'D24 :Q 'Q24 :QBAR
                          'QBAR24)
                  (VECTOR 'D-LATCH 'BIT25 :CLK 'CLK :D 'D25 :Q 'Q25 :QBAR
                          'QBAR25)
                  (VECTOR 'D-LATCH 'BIT26 :CLK 'CLK :D 'D26 :Q 'Q26 :QBAR
                          'QBAR26)
                  (VECTOR 'D-LATCH 'BIT27 :CLK 'CLK :D 'D27 :Q 'Q27 :QBAR
                          'QBAR27)
                  (VECTOR 'D-LATCH 'BIT28 :CLK 'CLK :D 'D28 :Q 'Q28 :QBAR
                          'QBAR28)
                  (VECTOR 'D-LATCH 'BIT29 :CLK 'CLK :D 'D29 :Q 'Q29 :QBAR
                          'QBAR29)
                  (VECTOR 'D-LATCH 'BIT30 :CLK 'CLK :D 'D30 :Q 'Q30 :QBAR
                          'QBAR30)
                  (VECTOR 'D-LATCH 'BIT31 :CLK 'CLK :D 'D31 :Q 'Q31 :QBAR
                          'QBAR31)))))
    (LET ((#2=#:VAL373 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('TOP8X32
           (MAKE '<MODULE-DEF> :NAME 'TOP8X32 :PORTS (VECTOR) :BODY
                 (VECTOR
                  (VECTOR 'REGISTER-32BIT 'REG0 :CLK 'CLK :D0 'D0 :D1 'D1 :D2
                          'D2 :D3 'D3 :D4 'D4 :D5 'D5 :D6 'D6 :D7 'D7 :D8 'D8
                          :D9 'D9 :D10 'D10 :D11 'D11 :D12 'D12 :D13 'D13 :D14
                          'D14 :D15 'D15 :D16 'D16 :D17 'D17 :D18 'D18 :D19
                          'D19 :D20 'D20 :D21 'D21 :D22 'D22 :D23 'D23 :D24
                          'D24 :D25 'D25 :D26 'D26 :D27 'D27 :D28 'D28 :D29
                          'D29 :D30 'D30 :D31 'D31 :Q0 'S0Q0 :Q1 'S0Q1 :Q2
                          'S0Q2 :Q3 'S0Q3 :Q4 'S0Q4 :Q5 'S0Q5 :Q6 'S0Q6 :Q7
                          'S0Q7 :Q8 'S0Q8 :Q9 'S0Q9 :Q10 'S0Q10 :Q11 'S0Q11
                          :Q12 'S0Q12 :Q13 'S0Q13 :Q14 'S0Q14 :Q15 'S0Q15 :Q16
                          'S0Q16 :Q17 'S0Q17 :Q18 'S0Q18 :Q19 'S0Q19 :Q20
                          'S0Q20 :Q21 'S0Q21 :Q22 'S0Q22 :Q23 'S0Q23 :Q24
                          'S0Q24 :Q25 'S0Q25 :Q26 'S0Q26 :Q27 'S0Q27 :Q28
                          'S0Q28 :Q29 'S0Q29 :Q30 'S0Q30 :Q31 'S0Q31)
                  (VECTOR 'REGISTER-32BIT 'REG1 :CLK 'CLK :D0 'S0Q0 :D1 'S0Q1
                          :D2 'S0Q2 :D3 'S0Q3 :D4 'S0Q4 :D5 'S0Q5 :D6 'S0Q6 :D7
                          'S0Q7 :D8 'S0Q8 :D9 'S0Q9 :D10 'S0Q10 :D11 'S0Q11
                          :D12 'S0Q12 :D13 'S0Q13 :D14 'S0Q14 :D15 'S0Q15 :D16
                          'S0Q16 :D17 'S0Q17 :D18 'S0Q18 :D19 'S0Q19 :D20
                          'S0Q20 :D21 'S0Q21 :D22 'S0Q22 :D23 'S0Q23 :D24
                          'S0Q24 :D25 'S0Q25 :D26 'S0Q26 :D27 'S0Q27 :D28
                          'S0Q28 :D29 'S0Q29 :D30 'S0Q30 :D31 'S0Q31 :Q0 'S1Q0
                          :Q1 'S1Q1 :Q2 'S1Q2 :Q3 'S1Q3 :Q4 'S1Q4 :Q5 'S1Q5 :Q6
                          'S1Q6 :Q7 'S1Q7 :Q8 'S1Q8 :Q9 'S1Q9 :Q10 'S1Q10 :Q11
                          'S1Q11 :Q12 'S1Q12 :Q13 'S1Q13 :Q14 'S1Q14 :Q15
                          'S1Q15 :Q16 'S1Q16 :Q17 'S1Q17 :Q18 'S1Q18 :Q19
                          'S1Q19 :Q20 'S1Q20 :Q21 'S1Q21 :Q22 'S1Q22 :Q23
                          'S1Q23 :Q24 'S1Q24 :Q25 'S1Q25 :Q26 'S1Q26 :Q27
                          'S1Q27 :Q28 'S1Q28 :Q29 'S1Q29 :Q30 'S1Q30 :Q31
                          'S1Q31)
                  (VECTOR 'REGISTER-32BIT 'REG2 :CLK 'CLK :D0 'S1Q0 :D1 'S1Q1
                          :D2 'S1Q2 :D3 'S1Q3 :D4 'S1Q4 :D5 'S1Q5 :D6 'S1Q6 :D7
                          'S1Q7 :D8 'S1Q8 :D9 'S1Q9 :D10 'S1Q10 :D11 'S1Q11
                          :D12 'S1Q12 :D13 'S1Q13 :D14 'S1Q14 :D15 'S1Q15 :D16
                          'S1Q16 :D17 'S1Q17 :D18 'S1Q18 :D19 'S1Q19 :D20
                          'S1Q20 :D21 'S1Q21 :D22 'S1Q22 :D23 'S1Q23 :D24
                          'S1Q24 :D25 'S1Q25 :D26 'S1Q26 :D27 'S1Q27 :D28
                          'S1Q28 :D29 'S1Q29 :D30 'S1Q30 :D31 'S1Q31 :Q0 'S2Q0
                          :Q1 'S2Q1 :Q2 'S2Q2 :Q3 'S2Q3 :Q4 'S2Q4 :Q5 'S2Q5 :Q6
                          'S2Q6 :Q7 'S2Q7 :Q8 'S2Q8 :Q9 'S2Q9 :Q10 'S2Q10 :Q11
                          'S2Q11 :Q12 'S2Q12 :Q13 'S2Q13 :Q14 'S2Q14 :Q15
                          'S2Q15 :Q16 'S2Q16 :Q17 'S2Q17 :Q18 'S2Q18 :Q19
                          'S2Q19 :Q20 'S2Q20 :Q21 'S2Q21 :Q22 'S2Q22 :Q23
                          'S2Q23 :Q24 'S2Q24 :Q25 'S2Q25 :Q26 'S2Q26 :Q27
                          'S2Q27 :Q28 'S2Q28 :Q29 'S2Q29 :Q30 'S2Q30 :Q31
                          'S2Q31)
                  (VECTOR 'REGISTER-32BIT 'REG3 :CLK 'CLK :D0 'S2Q0 :D1 'S2Q1
                          :D2 'S2Q2 :D3 'S2Q3 :D4 'S2Q4 :D5 'S2Q5 :D6 'S2Q6 :D7
                          'S2Q7 :D8 'S2Q8 :D9 'S2Q9 :D10 'S2Q10 :D11 'S2Q11
                          :D12 'S2Q12 :D13 'S2Q13 :D14 'S2Q14 :D15 'S2Q15 :D16
                          'S2Q16 :D17 'S2Q17 :D18 'S2Q18 :D19 'S2Q19 :D20
                          'S2Q20 :D21 'S2Q21 :D22 'S2Q22 :D23 'S2Q23 :D24
                          'S2Q24 :D25 'S2Q25 :D26 'S2Q26 :D27 'S2Q27 :D28
                          'S2Q28 :D29 'S2Q29 :D30 'S2Q30 :D31 'S2Q31 :Q0 'S3Q0
                          :Q1 'S3Q1 :Q2 'S3Q2 :Q3 'S3Q3 :Q4 'S3Q4 :Q5 'S3Q5 :Q6
                          'S3Q6 :Q7 'S3Q7 :Q8 'S3Q8 :Q9 'S3Q9 :Q10 'S3Q10 :Q11
                          'S3Q11 :Q12 'S3Q12 :Q13 'S3Q13 :Q14 'S3Q14 :Q15
                          'S3Q15 :Q16 'S3Q16 :Q17 'S3Q17 :Q18 'S3Q18 :Q19
                          'S3Q19 :Q20 'S3Q20 :Q21 'S3Q21 :Q22 'S3Q22 :Q23
                          'S3Q23 :Q24 'S3Q24 :Q25 'S3Q25 :Q26 'S3Q26 :Q27
                          'S3Q27 :Q28 'S3Q28 :Q29 'S3Q29 :Q30 'S3Q30 :Q31
                          'S3Q31)
                  (VECTOR 'REGISTER-32BIT 'REG4 :CLK 'CLK :D0 'S3Q0 :D1 'S3Q1
                          :D2 'S3Q2 :D3 'S3Q3 :D4 'S3Q4 :D5 'S3Q5 :D6 'S3Q6 :D7
                          'S3Q7 :D8 'S3Q8 :D9 'S3Q9 :D10 'S3Q10 :D11 'S3Q11
                          :D12 'S3Q12 :D13 'S3Q13 :D14 'S3Q14 :D15 'S3Q15 :D16
                          'S3Q16 :D17 'S3Q17 :D18 'S3Q18 :D19 'S3Q19 :D20
                          'S3Q20 :D21 'S3Q21 :D22 'S3Q22 :D23 'S3Q23 :D24
                          'S3Q24 :D25 'S3Q25 :D26 'S3Q26 :D27 'S3Q27 :D28
                          'S3Q28 :D29 'S3Q29 :D30 'S3Q30 :D31 'S3Q31 :Q0 'S4Q0
                          :Q1 'S4Q1 :Q2 'S4Q2 :Q3 'S4Q3 :Q4 'S4Q4 :Q5 'S4Q5 :Q6
                          'S4Q6 :Q7 'S4Q7 :Q8 'S4Q8 :Q9 'S4Q9 :Q10 'S4Q10 :Q11
                          'S4Q11 :Q12 'S4Q12 :Q13 'S4Q13 :Q14 'S4Q14 :Q15
                          'S4Q15 :Q16 'S4Q16 :Q17 'S4Q17 :Q18 'S4Q18 :Q19
                          'S4Q19 :Q20 'S4Q20 :Q21 'S4Q21 :Q22 'S4Q22 :Q23
                          'S4Q23 :Q24 'S4Q24 :Q25 'S4Q25 :Q26 'S4Q26 :Q27
                          'S4Q27 :Q28 'S4Q28 :Q29 'S4Q29 :Q30 'S4Q30 :Q31
                          'S4Q31)
                  (VECTOR 'REGISTER-32BIT 'REG5 :CLK 'CLK :D0 'S4Q0 :D1 'S4Q1
                          :D2 'S4Q2 :D3 'S4Q3 :D4 'S4Q4 :D5 'S4Q5 :D6 'S4Q6 :D7
                          'S4Q7 :D8 'S4Q8 :D9 'S4Q9 :D10 'S4Q10 :D11 'S4Q11
                          :D12 'S4Q12 :D13 'S4Q13 :D14 'S4Q14 :D15 'S4Q15 :D16
                          'S4Q16 :D17 'S4Q17 :D18 'S4Q18 :D19 'S4Q19 :D20
                          'S4Q20 :D21 'S4Q21 :D22 'S4Q22 :D23 'S4Q23 :D24
                          'S4Q24 :D25 'S4Q25 :D26 'S4Q26 :D27 'S4Q27 :D28
                          'S4Q28 :D29 'S4Q29 :D30 'S4Q30 :D31 'S4Q31 :Q0 'S5Q0
                          :Q1 'S5Q1 :Q2 'S5Q2 :Q3 'S5Q3 :Q4 'S5Q4 :Q5 'S5Q5 :Q6
                          'S5Q6 :Q7 'S5Q7 :Q8 'S5Q8 :Q9 'S5Q9 :Q10 'S5Q10 :Q11
                          'S5Q11 :Q12 'S5Q12 :Q13 'S5Q13 :Q14 'S5Q14 :Q15
                          'S5Q15 :Q16 'S5Q16 :Q17 'S5Q17 :Q18 'S5Q18 :Q19
                          'S5Q19 :Q20 'S5Q20 :Q21 'S5Q21 :Q22 'S5Q22 :Q23
                          'S5Q23 :Q24 'S5Q24 :Q25 'S5Q25 :Q26 'S5Q26 :Q27
                          'S5Q27 :Q28 'S5Q28 :Q29 'S5Q29 :Q30 'S5Q30 :Q31
                          'S5Q31)
                  (VECTOR 'REGISTER-32BIT 'REG6 :CLK 'CLK :D0 'S5Q0 :D1 'S5Q1
                          :D2 'S5Q2 :D3 'S5Q3 :D4 'S5Q4 :D5 'S5Q5 :D6 'S5Q6 :D7
                          'S5Q7 :D8 'S5Q8 :D9 'S5Q9 :D10 'S5Q10 :D11 'S5Q11
                          :D12 'S5Q12 :D13 'S5Q13 :D14 'S5Q14 :D15 'S5Q15 :D16
                          'S5Q16 :D17 'S5Q17 :D18 'S5Q18 :D19 'S5Q19 :D20
                          'S5Q20 :D21 'S5Q21 :D22 'S5Q22 :D23 'S5Q23 :D24
                          'S5Q24 :D25 'S5Q25 :D26 'S5Q26 :D27 'S5Q27 :D28
                          'S5Q28 :D29 'S5Q29 :D30 'S5Q30 :D31 'S5Q31 :Q0 'S6Q0
                          :Q1 'S6Q1 :Q2 'S6Q2 :Q3 'S6Q3 :Q4 'S6Q4 :Q5 'S6Q5 :Q6
                          'S6Q6 :Q7 'S6Q7 :Q8 'S6Q8 :Q9 'S6Q9 :Q10 'S6Q10 :Q11
                          'S6Q11 :Q12 'S6Q12 :Q13 'S6Q13 :Q14 'S6Q14 :Q15
                          'S6Q15 :Q16 'S6Q16 :Q17 'S6Q17 :Q18 'S6Q18 :Q19
                          'S6Q19 :Q20 'S6Q20 :Q21 'S6Q21 :Q22 'S6Q22 :Q23
                          'S6Q23 :Q24 'S6Q24 :Q25 'S6Q25 :Q26 'S6Q26 :Q27
                          'S6Q27 :Q28 'S6Q28 :Q29 'S6Q29 :Q30 'S6Q30 :Q31
                          'S6Q31)
                  (VECTOR 'REGISTER-32BIT 'REG7 :CLK 'CLK :D0 'S6Q0 :D1 'S6Q1
                          :D2 'S6Q2 :D3 'S6Q3 :D4 'S6Q4 :D5 'S6Q5 :D6 'S6Q6 :D7
                          'S6Q7 :D8 'S6Q8 :D9 'S6Q9 :D10 'S6Q10 :D11 'S6Q11
                          :D12 'S6Q12 :D13 'S6Q13 :D14 'S6Q14 :D15 'S6Q15 :D16
                          'S6Q16 :D17 'S6Q17 :D18 'S6Q18 :D19 'S6Q19 :D20
                          'S6Q20 :D21 'S6Q21 :D22 'S6Q22 :D23 'S6Q23 :D24
                          'S6Q24 :D25 'S6Q25 :D26 'S6Q26 :D27 'S6Q27 :D28
                          'S6Q28 :D29 'S6Q29 :D30 'S6Q30 :D31 'S6Q31 :Q0 'Q0
                          :Q1 'Q1 :Q2 'Q2 :Q3 'Q3 :Q4 'Q4 :Q5 'Q5 :Q6 'Q6 :Q7
                          'Q7 :Q8 'Q8 :Q9 'Q9 :Q10 'Q10 :Q11 'Q11 :Q12 'Q12
                          :Q13 'Q13 :Q14 'Q14 :Q15 'Q15 :Q16 'Q16 :Q17 'Q17
                          :Q18 'Q18 :Q19 'Q19 :Q20 'Q20 :Q21 'Q21 :Q22 'Q22
                          :Q23 'Q23 :Q24 'Q24 :Q25 'Q25 :Q26 'Q26 :Q27 'Q27
                          :Q28 'Q28 :Q29 'Q29 :Q30 'Q30 :Q31 'Q31)))))
    (LET ((#2=#:VAL374 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'MONITOR)
    (MONITOR
     . #1=('Q0 'Q1 'Q2 'Q3 'Q4 'Q5 'Q6 'Q7 'Q8 'Q9 'Q10 'Q11 'Q12 'Q13 'Q14
           'Q15 'Q16 'Q17 'Q18 'Q19 'Q20 'Q21 'Q22 'Q23 'Q24 'Q25 'Q26 'Q27
           'Q28 'Q29 'Q30 'Q31))
    (LET ((#2=#:VAL375 MONITOR))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'MONITOR)))))

(DEFUN ADD-P1 (TIME-VAL)
  (DECLARE (SPECIAL ADDEVENTS))
  (IF (FBOUNDP 'ADDEVENTS)
      (ADDEVENTS
       . #1=((DICT :NODE 'D0 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D1 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D2 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D3 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D4 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D5 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D6 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D7 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D8 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D9 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D10 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D11 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D12 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D13 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D14 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D15 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D16 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D17 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D18 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D19 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D20 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D21 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D22 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D23 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D24 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D25 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D26 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D27 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D28 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D29 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D30 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D31 :VALUE 0 :TIME TIME-VAL)))
      (LET ((#2=#:VAL376 ADDEVENTS))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'ADDEVENTS))))))

(DEFUN ADD-P2 (TIME-VAL)
  (DECLARE (SPECIAL ADDEVENTS))
  (IF (FBOUNDP 'ADDEVENTS)
      (ADDEVENTS
       . #1=((DICT :NODE 'D0 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D1 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D2 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D3 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D4 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D5 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D6 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D7 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D8 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D9 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D10 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D11 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D12 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D13 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D14 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D15 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D16 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D17 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D18 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D19 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D20 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D21 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D22 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D23 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D24 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D25 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D26 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D27 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D28 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D29 :VALUE 1 :TIME TIME-VAL)
             (DICT :NODE 'D30 :VALUE 0 :TIME TIME-VAL)
             (DICT :NODE 'D31 :VALUE 1 :TIME TIME-VAL)))
      (LET ((#2=#:VAL377 ADDEVENTS))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'ADDEVENTS))))))

(DEFUN SETUP-SIMULATION ()
  (DECLARE (SPECIAL ADDEVENTS ADD-P2 ADD-P1))
  (BLOCK LOOP-BLOCK-3
    (LET ((K 0))
      (TAGBODY
       LOOP-3
        (LET ((RESULT-3
               (PROGN
                (IF (TRUTHY? (< K 90))
                    (PROGN
                     (IF (TRUTHY? (= (MOD K 2) 0))
                         (IF (FBOUNDP 'ADD-P1)
                             (ADD-P1 . #1=((* K 10)))
                             (LET ((#2=#:VAL378 ADD-P1))
                               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                                     ((TYPEP #2# . #3=('<DICT>))
                                      (GET #2# . #1#))
                                     ((TYPEP #2# . #4=('<VECTOR>))
                                      (NTH #2# . #1#))
                                     ((TYPEP #2# . #5=('<SET>))
                                      (GET #2# . #1#))
                                     (T
                                      (ERROR
                                       #6="~S is not a function or collection"
                                       'ADD-P1)))))
                         (IF (FBOUNDP 'ADD-P2)
                             (ADD-P2 . #7=((* K 10)))
                             (LET ((#8=#:VAL379 ADD-P2))
                               (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                                     ((TYPEP #8# . #3#) (GET #8# . #7#))
                                     ((TYPEP #8# . #4#) (NTH #8# . #7#))
                                     ((TYPEP #8# . #5#) (GET #8# . #7#))
                                     (T (ERROR #6# 'ADD-P2))))))
                     (PROGN (PSETQ K (+ K 1)) (GO LOOP-3)))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-3 RESULT-3)))))
  (BLOCK LOOP-BLOCK-4
    (LET ((K 0))
      (TAGBODY
       LOOP-4
        (LET ((RESULT-4
               (PROGN
                (IF (TRUTHY? (< K 90))
                    (PROGN
                     (IF (FBOUNDP 'ADDEVENTS)
                         (ADDEVENTS
                          . #9=((DICT :NODE 'CLK :VALUE 1 :TIME (+ 3 (* K 10)))
                                (DICT :NODE 'CLK :VALUE 0 :TIME
                                      (+ 8 (* K 10)))))
                         (LET ((#10=#:VAL380 ADDEVENTS))
                           (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                                 ((TYPEP #10# . #3#) (GET #10# . #9#))
                                 ((TYPEP #10# . #4#) (NTH #10# . #9#))
                                 ((TYPEP #10# . #5#) (GET #10# . #9#))
                                 (T (ERROR #6# 'ADDEVENTS)))))
                     (PROGN (PSETQ K (+ K 1)) (GO LOOP-4)))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-4 RESULT-4))))))

(IF (FBOUNDP 'SETUP-SIMULATION)
    (SETUP-SIMULATION)
    (LET ((#1=#:VAL381 SETUP-SIMULATION))
      (COND ((FUNCTIONP #1#) (FUNCALL #1#))
            (T
             (ERROR "~S is not a function or collection" 'SETUP-SIMULATION)))))

(DEFUN RUN-BENCH ()
  (DECLARE (SPECIAL RUNLSIM))
  (IF (FBOUNDP 'RUNLSIM)
      (RUNLSIM . #1=('TOP8X32 900))
      (LET ((#2=#:VAL382 RUNLSIM))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              ((TYPEP #2# '<DICT>) (GET #2# . #1#))
              ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
              ((TYPEP #2# '<SET>) (GET #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'RUNLSIM))))))
