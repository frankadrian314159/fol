;;; Transpiled from repro-macros.fol
(in-package :fol.core)

(DEFVAR ACC (ATOM 0))

(LET ((#1=#:MAX-242 3))
  (BLOCK LOOP-BLOCK-1
    (LET ((#2=#:I-243 0))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (PROGN
                (IF (TRUTHY? (COMMON-LISP:< #2# #1#))
                    (PROGN
                     (LET ((I #2#))
                       (PROGN
                        (SWAP! ACC (LAMBDA (A) (+ A 1)))
                        (PROGN (PSETQ #2# (INC #2#)) (GO LOOP-1)))))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))

(PRINTLN "Acc is:" (DEREF ACC))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF ACC) 3))))
    (PROGN (ERROR "dotimes executes body 3 times"))
    NIL)

(DEFVAR ACC2 (ATOM 0))

(LET ((#1=#:MAX-244 5))
  (BLOCK LOOP-BLOCK-2
    (LET ((#2=#:I-245 0))
      (TAGBODY
       LOOP-2
        (LET ((RESULT-2
               (PROGN
                (IF (TRUTHY? (COMMON-LISP:< #2# #1#))
                    (PROGN
                     (LET ((I #2#))
                       (PROGN
                        (SWAP! ACC2 (LAMBDA (A) (+ A I)))
                        (PROGN (PSETQ #2# (INC #2#)) (GO LOOP-2)))))
                    NIL))))
          (RETURN-FROM LOOP-BLOCK-2 RESULT-2))))))

(PRINTLN "Acc2 is:" (DEREF ACC2))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF ACC2) 10))))
    (PROGN (ERROR "dotimes with counter 0+1+2+3+4=10"))
    NIL)

(DEFVAR SUM-VEC (ATOM 0))

(BLOCK LOOP-BLOCK-3
  (LET ((#1=#:SEQ-246 (SEQ (VECTOR 1 2 3))))
    (TAGBODY
     LOOP-3
      (LET ((RESULT-3
             (PROGN
              (IF (TRUTHY? #1#)
                  (PROGN
                   (LET ((X (FIRST #1#)))
                     (PROGN
                      (SWAP! SUM-VEC (LAMBDA (A) (+ A X)))
                      (PROGN (PSETQ #1# (REST #1#)) (GO LOOP-3)))))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-3 RESULT-3)))))

(PRINTLN "Sum-vec is:" (DEREF SUM-VEC))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF SUM-VEC) 6))))
    (PROGN (ERROR "doseq sums vector elements"))
    NIL)

(PRINTLN "All assertions passed!")
