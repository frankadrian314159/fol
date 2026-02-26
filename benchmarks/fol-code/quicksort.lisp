;;; Transpiled from quicksort.fol
(in-package :fol.core)

(DEFUN PARTITION (V LOW HIGH)
  (LET ((PIVOT (GET V HIGH)))
    (BLOCK LOOP-BLOCK-1
      (LET ((J LOW) (I (- LOW 1)) (CURR-V V))
        (TAGBODY
         LOOP-1
          (LET ((RESULT-1
                 (PROGN
                  (IF (TRUTHY? (< J HIGH))
                      (IF (TRUTHY? (<= (GET CURR-V J) PIVOT))
                          (LET ((NEXT-I (+ I 1)))
                            (LET ((TEMP (GET CURR-V NEXT-I)))
                              (LET ((V1 (ASSOC CURR-V NEXT-I (GET CURR-V J))))
                                (LET ((V2 (ASSOC V1 J TEMP)))
                                  (PROGN
                                   (PSETQ J (+ J 1)
                                          I NEXT-I
                                          CURR-V V2)
                                   (GO LOOP-1))))))
                          (PROGN
                           (PSETQ J (+ J 1)
                                  I I
                                  CURR-V CURR-V)
                           (GO LOOP-1)))
                      (LET ((NEXT-I (+ I 1)))
                        (LET ((TEMP (GET CURR-V NEXT-I)))
                          (LET ((V1 (ASSOC CURR-V NEXT-I (GET CURR-V HIGH))))
                            (LET ((V2 (ASSOC V1 HIGH TEMP)))
                              (VECTOR V2 NEXT-I)))))))))
            (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))

(DEFUN QSORT (V LOW HIGH)
  (DECLARE (SPECIAL QSORT))
  (IF (TRUTHY? (< LOW HIGH))
      (LET* ((#1=#:MV266 (MULTIPLE-VALUE-LIST (PARTITION V LOW HIGH)))
             (#2=#:VAL267
              (IF (COMMON-LISP:> (LENGTH #1#) 1)
                  #1#
                  (CAR #1#)))
             (#3=#:DESTR268 #2#)
             (V-PART (ELT #3# 0))
             (P (ELT #3# 1)))
        (LET ((V-LEFT
               (IF (FBOUNDP 'QSORT)
                   (QSORT . #4=(V-PART LOW (- P 1)))
                   (LET ((#5=#:VAL269 QSORT))
                     (COND ((FUNCTIONP #5#) (FUNCALL #5# . #4#))
                           (T
                            (ERROR #6="~S is not a function or collection"
                                   'QSORT)))))))
          (IF (FBOUNDP 'QSORT)
              (QSORT . #7=(V-LEFT (+ P 1) HIGH))
              (LET ((#8=#:VAL270 QSORT))
                (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                      (T (ERROR #6# 'QSORT)))))))
      V))
