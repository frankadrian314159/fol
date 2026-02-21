;;; Transpiled from 32bit-300-p.fol
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

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('SR-LATCH
           (MAKE '<MODULE-DEF> :NAME 'SR-LATCH :PORTS (VECTOR 'R 'S 'Q 'QBAR)
                 :BODY
                 (VECTOR (VECTOR 'NAND 'NAND1 :IN1 'S :IN2 'QBAR :OUT 'Q)
                         (VECTOR 'NAND 'NAND2 :IN1 'R :IN2 'Q :OUT 'QBAR)))))
    (LET ((#2=#:VAL431 REGISTER-MODULE))
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
    (LET ((#2=#:VAL432 REGISTER-MODULE))
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
    (LET ((#2=#:VAL433 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('TOP32
           (MAKE '<MODULE-DEF> :NAME 'TOP32 :PORTS (VECTOR) :BODY
                 (VECTOR
                  (VECTOR 'REGISTER-32BIT 'REG :CLK 'CLK :D0 'D0 :D1 'D1 :D2
                          'D2 :D3 'D3 :D4 'D4 :D5 'D5 :D6 'D6 :D7 'D7 :D8 'D8
                          :D9 'D9 :D10 'D10 :D11 'D11 :D12 'D12 :D13 'D13 :D14
                          'D14 :D15 'D15 :D16 'D16 :D17 'D17 :D18 'D18 :D19
                          'D19 :D20 'D20 :D21 'D21 :D22 'D22 :D23 'D23 :D24
                          'D24 :D25 'D25 :D26 'D26 :D27 'D27 :D28 'D28 :D29
                          'D29 :D30 'D30 :D31 'D31 :Q0 'Q0 :Q1 'Q1 :Q2 'Q2 :Q3
                          'Q3 :Q4 'Q4 :Q5 'Q5 :Q6 'Q6 :Q7 'Q7 :Q8 'Q8 :Q9 'Q9
                          :Q10 'Q10 :Q11 'Q11 :Q12 'Q12 :Q13 'Q13 :Q14 'Q14
                          :Q15 'Q15 :Q16 'Q16 :Q17 'Q17 :Q18 'Q18 :Q19 'Q19
                          :Q20 'Q20 :Q21 'Q21 :Q22 'Q22 :Q23 'Q23 :Q24 'Q24
                          :Q25 'Q25 :Q26 'Q26 :Q27 'Q27 :Q28 'Q28 :Q29 'Q29
                          :Q30 'Q30 :Q31 'Q31)))))
    (LET ((#2=#:VAL434 REGISTER-MODULE))
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
    (LET ((#2=#:VAL435 MONITOR))
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
      (LET ((#2=#:VAL436 ADDEVENTS))
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
      (LET ((#2=#:VAL437 ADDEVENTS))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'ADDEVENTS))))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(0))
    (LET ((#2=#:VAL438 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(10))
    (LET ((#2=#:VAL439 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(20))
    (LET ((#2=#:VAL440 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(30))
    (LET ((#2=#:VAL441 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(40))
    (LET ((#2=#:VAL442 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(50))
    (LET ((#2=#:VAL443 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(60))
    (LET ((#2=#:VAL444 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(70))
    (LET ((#2=#:VAL445 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(80))
    (LET ((#2=#:VAL446 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(90))
    (LET ((#2=#:VAL447 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(100))
    (LET ((#2=#:VAL448 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(110))
    (LET ((#2=#:VAL449 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(120))
    (LET ((#2=#:VAL450 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(130))
    (LET ((#2=#:VAL451 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(140))
    (LET ((#2=#:VAL452 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(150))
    (LET ((#2=#:VAL453 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(160))
    (LET ((#2=#:VAL454 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(170))
    (LET ((#2=#:VAL455 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(180))
    (LET ((#2=#:VAL456 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(190))
    (LET ((#2=#:VAL457 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(200))
    (LET ((#2=#:VAL458 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(210))
    (LET ((#2=#:VAL459 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(220))
    (LET ((#2=#:VAL460 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(230))
    (LET ((#2=#:VAL461 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(240))
    (LET ((#2=#:VAL462 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(250))
    (LET ((#2=#:VAL463 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(260))
    (LET ((#2=#:VAL464 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(270))
    (LET ((#2=#:VAL465 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(280))
    (LET ((#2=#:VAL466 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(290))
    (LET ((#2=#:VAL467 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADDEVENTS)
    (ADDEVENTS
     . #1=((DICT :NODE 'CLK :VALUE 1 :TIME 3)
           (DICT :NODE 'CLK :VALUE 0 :TIME 8)
           (DICT :NODE 'CLK :VALUE 1 :TIME 13)
           (DICT :NODE 'CLK :VALUE 0 :TIME 18)
           (DICT :NODE 'CLK :VALUE 1 :TIME 23)
           (DICT :NODE 'CLK :VALUE 0 :TIME 28)
           (DICT :NODE 'CLK :VALUE 1 :TIME 33)
           (DICT :NODE 'CLK :VALUE 0 :TIME 38)
           (DICT :NODE 'CLK :VALUE 1 :TIME 43)
           (DICT :NODE 'CLK :VALUE 0 :TIME 48)
           (DICT :NODE 'CLK :VALUE 1 :TIME 53)
           (DICT :NODE 'CLK :VALUE 0 :TIME 58)
           (DICT :NODE 'CLK :VALUE 1 :TIME 63)
           (DICT :NODE 'CLK :VALUE 0 :TIME 68)
           (DICT :NODE 'CLK :VALUE 1 :TIME 73)
           (DICT :NODE 'CLK :VALUE 0 :TIME 78)
           (DICT :NODE 'CLK :VALUE 1 :TIME 83)
           (DICT :NODE 'CLK :VALUE 0 :TIME 88)
           (DICT :NODE 'CLK :VALUE 1 :TIME 93)
           (DICT :NODE 'CLK :VALUE 0 :TIME 98)
           (DICT :NODE 'CLK :VALUE 1 :TIME 103)
           (DICT :NODE 'CLK :VALUE 0 :TIME 108)
           (DICT :NODE 'CLK :VALUE 1 :TIME 113)
           (DICT :NODE 'CLK :VALUE 0 :TIME 118)
           (DICT :NODE 'CLK :VALUE 1 :TIME 123)
           (DICT :NODE 'CLK :VALUE 0 :TIME 128)
           (DICT :NODE 'CLK :VALUE 1 :TIME 133)
           (DICT :NODE 'CLK :VALUE 0 :TIME 138)
           (DICT :NODE 'CLK :VALUE 1 :TIME 143)
           (DICT :NODE 'CLK :VALUE 0 :TIME 148)
           (DICT :NODE 'CLK :VALUE 1 :TIME 153)
           (DICT :NODE 'CLK :VALUE 0 :TIME 158)
           (DICT :NODE 'CLK :VALUE 1 :TIME 163)
           (DICT :NODE 'CLK :VALUE 0 :TIME 168)
           (DICT :NODE 'CLK :VALUE 1 :TIME 173)
           (DICT :NODE 'CLK :VALUE 0 :TIME 178)
           (DICT :NODE 'CLK :VALUE 1 :TIME 183)
           (DICT :NODE 'CLK :VALUE 0 :TIME 188)
           (DICT :NODE 'CLK :VALUE 1 :TIME 193)
           (DICT :NODE 'CLK :VALUE 0 :TIME 198)
           (DICT :NODE 'CLK :VALUE 1 :TIME 203)
           (DICT :NODE 'CLK :VALUE 0 :TIME 208)
           (DICT :NODE 'CLK :VALUE 1 :TIME 213)
           (DICT :NODE 'CLK :VALUE 0 :TIME 218)
           (DICT :NODE 'CLK :VALUE 1 :TIME 223)
           (DICT :NODE 'CLK :VALUE 0 :TIME 228)
           (DICT :NODE 'CLK :VALUE 1 :TIME 233)
           (DICT :NODE 'CLK :VALUE 0 :TIME 238)
           (DICT :NODE 'CLK :VALUE 1 :TIME 243)
           (DICT :NODE 'CLK :VALUE 0 :TIME 248)
           (DICT :NODE 'CLK :VALUE 1 :TIME 253)
           (DICT :NODE 'CLK :VALUE 0 :TIME 258)
           (DICT :NODE 'CLK :VALUE 1 :TIME 263)
           (DICT :NODE 'CLK :VALUE 0 :TIME 268)
           (DICT :NODE 'CLK :VALUE 1 :TIME 273)
           (DICT :NODE 'CLK :VALUE 0 :TIME 278)
           (DICT :NODE 'CLK :VALUE 1 :TIME 283)
           (DICT :NODE 'CLK :VALUE 0 :TIME 288)
           (DICT :NODE 'CLK :VALUE 1 :TIME 293)
           (DICT :NODE 'CLK :VALUE 0 :TIME 298)))
    (LET ((#2=#:VAL468 ADDEVENTS))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADDEVENTS)))))

(DEFUN RUN-BENCH ()
  (DECLARE (SPECIAL RUNLSIM))
  (IF (FBOUNDP 'RUNLSIM)
      (RUNLSIM . #1=('TOP32 300))
      (LET ((#2=#:VAL469 RUNLSIM))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              ((TYPEP #2# '<DICT>) (GET #2# . #1#))
              ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
              ((TYPEP #2# '<SET>) (GET #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'RUNLSIM))))))
