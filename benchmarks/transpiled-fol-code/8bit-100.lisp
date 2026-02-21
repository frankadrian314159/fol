;;; Transpiled from 8bit-100.fol
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
    (LET ((#2=#:VAL311 REGISTER-MODULE))
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
    (LET ((#2=#:VAL312 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('REGISTER-8BIT
           (MAKE '<MODULE-DEF> :NAME 'REGISTER-8BIT :PORTS
                 (VECTOR 'CLK 'D0 'D1 'D2 'D3 'D4 'D5 'D6 'D7 'Q0 'Q1 'Q2 'Q3
                         'Q4 'Q5 'Q6 'Q7)
                 :BODY
                 (VECTOR
                  (VECTOR 'D-LATCH 'BIT0 :CLK 'CLK :D 'D0 :Q 'Q0 :QBAR 'QBAR0)
                  (VECTOR 'D-LATCH 'BIT1 :CLK 'CLK :D 'D1 :Q 'Q1 :QBAR 'QBAR1)
                  (VECTOR 'D-LATCH 'BIT2 :CLK 'CLK :D 'D2 :Q 'Q2 :QBAR 'QBAR2)
                  (VECTOR 'D-LATCH 'BIT3 :CLK 'CLK :D 'D3 :Q 'Q3 :QBAR 'QBAR3)
                  (VECTOR 'D-LATCH 'BIT4 :CLK 'CLK :D 'D4 :Q 'Q4 :QBAR 'QBAR4)
                  (VECTOR 'D-LATCH 'BIT5 :CLK 'CLK :D 'D5 :Q 'Q5 :QBAR 'QBAR5)
                  (VECTOR 'D-LATCH 'BIT6 :CLK 'CLK :D 'D6 :Q 'Q6 :QBAR 'QBAR6)
                  (VECTOR 'D-LATCH 'BIT7 :CLK 'CLK :D 'D7 :Q 'Q7 :QBAR
                          'QBAR7)))))
    (LET ((#2=#:VAL313 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'REGISTER-MODULE)
    (REGISTER-MODULE
     . #1=('TOP
           (MAKE '<MODULE-DEF> :NAME 'TOP :PORTS (VECTOR) :BODY
                 (VECTOR
                  (VECTOR 'REGISTER-8BIT 'REG :CLK 'CLK :D0 'D0 :D1 'D1 :D2 'D2
                          :D3 'D3 :D4 'D4 :D5 'D5 :D6 'D6 :D7 'D7 :Q0 'Q0 :Q1
                          'Q1 :Q2 'Q2 :Q3 'Q3 :Q4 'Q4 :Q5 'Q5 :Q6 'Q6 :Q7
                          'Q7)))))
    (LET ((#2=#:VAL316 REGISTER-MODULE))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'REGISTER-MODULE)))))

(IF (FBOUNDP 'MONITOR)
    (MONITOR . #1=('Q0 'Q1 'Q2 'Q3 'Q4 'Q5 'Q6 'Q7))
    (LET ((#2=#:VAL317 MONITOR))
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
             (DICT :NODE 'D7 :VALUE 0 :TIME TIME-VAL)))
      (LET ((#2=#:VAL318 ADDEVENTS))
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
             (DICT :NODE 'D7 :VALUE 1 :TIME TIME-VAL)))
      (LET ((#2=#:VAL319 ADDEVENTS))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'ADDEVENTS))))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(0))
    (LET ((#2=#:VAL320 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(10))
    (LET ((#2=#:VAL321 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(20))
    (LET ((#2=#:VAL322 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(30))
    (LET ((#2=#:VAL323 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(40))
    (LET ((#2=#:VAL324 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(50))
    (LET ((#2=#:VAL325 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(60))
    (LET ((#2=#:VAL326 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(70))
    (LET ((#2=#:VAL327 ADD-P2))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P2)))))

(IF (FBOUNDP 'ADD-P1)
    (ADD-P1 . #1=(80))
    (LET ((#2=#:VAL328 ADD-P1))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            ((TYPEP #2# '<DICT>) (GET #2# . #1#))
            ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
            ((TYPEP #2# '<SET>) (GET #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADD-P1)))))

(IF (FBOUNDP 'ADD-P2)
    (ADD-P2 . #1=(90))
    (LET ((#2=#:VAL329 ADD-P2))
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
           (DICT :NODE 'CLK :VALUE 0 :TIME 98)))
    (LET ((#2=#:VAL330 ADDEVENTS))
      (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
            (T (ERROR "~S is not a function or collection" 'ADDEVENTS)))))

(DEFUN RUN-BENCH ()
  (DECLARE (SPECIAL RUNLSIM))
  (IF (FBOUNDP 'RUNLSIM)
      (RUNLSIM . #1=('TOP 100))
      (LET ((#2=#:VAL331 RUNLSIM))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              ((TYPEP #2# '<DICT>) (GET #2# . #1#))
              ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
              ((TYPEP #2# '<SET>) (GET #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'RUNLSIM))))))
