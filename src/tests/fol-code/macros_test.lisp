;;; Transpiled from macros_test.fol
(in-package :fol.core)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? TRUE)
            (PROGN 42)
            NIL)
        42))))
    (PROGN (ERROR "when true returns body result"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? FALSE)
            (PROGN 42)
            NIL)
        NIL))))
    (PROGN (ERROR "when false returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? TRUE)
            (PROGN 1 2 3)
            NIL)
        3))))
    (PROGN (ERROR "when with multiple exprs returns last"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? FALSE)
            NIL
            (PROGN 42))
        42))))
    (PROGN (ERROR "when-not false returns body result"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? TRUE)
            NIL
            (PROGN 42))
        NIL))))
    (PROGN (ERROR "when-not true returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? FALSE)
            NIL
            (PROGN 1 2 3))
        3))))
    (PROGN (ERROR "when-not with multiple exprs returns last"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? TRUE)
            99
            42)
        99))))
    (PROGN (ERROR "if-not true goes to else"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? FALSE)
            99
            42)
        42))))
    (PROGN (ERROR "if-not false goes to then"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (IF (TRUTHY? FALSE)
            NIL
            42)
        42))))
    (PROGN (ERROR "if-not false without else returns then-clause"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X 5))
          (IF (TRUTHY? X)
              (PROGN (+ X 1))
              NIL))
        6))))
    (PROGN (ERROR "when-let binds and returns body"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X NIL))
          (IF (TRUTHY? X)
              (PROGN 42)
              NIL))
        NIL))))
    (PROGN (ERROR "when-let with nil returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X FALSE))
          (IF (TRUTHY? X)
              (PROGN 42)
              NIL))
        NIL))))
    (PROGN (ERROR "when-let with false returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X 5))
          (IF (TRUTHY? X)
              (+ X 1)
              0))
        6))))
    (PROGN (ERROR "if-let with non-nil executes then"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X NIL))
          (IF (TRUTHY? X)
              99
              42))
        42))))
    (PROGN (ERROR "if-let with nil executes else"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X FALSE))
          (IF (TRUTHY? X)
              99
              42))
        42))))
    (PROGN (ERROR "if-let with false executes else"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SOME-240 5))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN
               (LET ((X #1#))
                 (+ X 1)))
              NIL))
        6))))
    (PROGN (ERROR "when-some with value returns body"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SOME-241 NIL))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN
               (LET ((X #1#))
                 42))
              NIL))
        NIL))))
    (PROGN (ERROR "when-some with nil returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SOME-242 FALSE))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN
               (LET ((X #1#))
                 "pass"))
              NIL))
        NIL))))
    (PROGN (ERROR "when-some with false fails check"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SOME-243 5))
          (IF (TRUTHY? (SOME? #1#))
              (LET ((X #1#))
                (+ X 1))
              0))
        6))))
    (PROGN (ERROR "if-some with value executes then"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SOME-244 NIL))
          (IF (TRUTHY? (SOME? #1#))
              (LET ((X #1#))
                99)
              42))
        42))))
    (PROGN (ERROR "if-some with nil executes else"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SOME-245 FALSE))
          (IF (TRUTHY? (SOME? #1#))
              (LET ((X #1#))
                "pass")
              "fail"))
        "fail"))))
    (PROGN (ERROR "if-some with false fails check"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SEQ-246 (SEQ (VECTOR 1 2 3))))
          (IF (TRUTHY? #1#)
              (PROGN
               (LET ((X (FIRST #1#)))
                 (+ X 10)))
              NIL))
        11))))
    (PROGN (ERROR "when-first binds first element"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SEQ-247 (SEQ (VECTOR))))
          (IF (TRUTHY? #1#)
              (PROGN
               (LET ((X (FIRST #1#)))
                 42))
              NIL))
        NIL))))
    (PROGN (ERROR "when-first with empty seq returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:SEQ-248 (SEQ (VECTOR 5))))
          (IF (TRUTHY? #1#)
              (PROGN
               (LET ((X (FIRST #1#)))
                 (INC X)))
              NIL))
        6))))
    (PROGN (ERROR "when-first increments first element"))
    NIL)

(DEFVAR ACC (ATOM 0))

(LET ((#1=#:MAX-249 3))
  (BLOCK LOOP-BLOCK-1
    (LET ((#2=#:I-250 0))
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

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF ACC) 3))))
    (PROGN (ERROR "dotimes executes body 3 times"))
    NIL)

(DEFVAR ACC2 (ATOM 0))

(LET ((#1=#:MAX-251 5))
  (BLOCK LOOP-BLOCK-2
    (LET ((#2=#:I-252 0))
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

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF ACC2) 10))))
    (PROGN (ERROR "dotimes with counter 0+1+2+3+4=10"))
    NIL)

(DEFVAR SUM-VEC (ATOM 0))

(BLOCK LOOP-BLOCK-3
  (LET ((#1=#:SEQ-253 (SEQ (VECTOR 1 2 3))))
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

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF SUM-VEC) 6))))
    (PROGN (ERROR "doseq sums vector elements"))
    NIL)

(DEFVAR ITEMS (ATOM (VECTOR)))

(BLOCK LOOP-BLOCK-4
  (LET ((#1=#:SEQ-254 (SEQ (VECTOR 10 20 30))))
    (TAGBODY
     LOOP-4
      (LET ((RESULT-4
             (PROGN
              (IF (TRUTHY? #1#)
                  (PROGN
                   (LET ((X (FIRST #1#)))
                     (PROGN
                      (SWAP! ITEMS (LAMBDA (A) (CONJ A X)))
                      (PROGN (PSETQ #1# (REST #1#)) (GO LOOP-4)))))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-4 RESULT-4)))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF ITEMS) (VECTOR 10 20 30)))))
    (PROGN (ERROR "doseq collects items"))
    NIL)

(DEFVAR FOR-RESULT1
  (LET ((#1=#:RESULT-255 (VECTOR)))
    (BLOCK LOOP-BLOCK-5
      (LET ((#2=#:SEQ-256 (SEQ (VECTOR 1 2 3))) (#1# #1#))
        (TAGBODY
         LOOP-5
          (LET ((RESULT-5
                 (PROGN
                  (IF (TRUTHY? (TRUTHY? #2#))
                      (PROGN
                       (LET ((#3=#:ITEM-257 (FIRST #2#)))
                         (LET ((X #3#))
                           (PROGN
                            (PSETQ #2# (REST #2#)
                                   #1# (CONJ #1# (PROGN (INC X))))
                            (GO LOOP-5)))))
                      #1#))))
            (RETURN-FROM LOOP-BLOCK-5 RESULT-5)))))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (FIRST FOR-RESULT1) 2))))
    (PROGN (ERROR "for returns first element"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (FIRST (REST FOR-RESULT1)) 3))))
    (PROGN (ERROR "for returns second element"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT (TRUTHY? (= (FIRST (REST (REST FOR-RESULT1))) 4))))
    (PROGN (ERROR "for returns third element"))
    NIL)

(DEFVAR FOR-RESULT2
  (LET ((#1=#:RESULT-258 (VECTOR)))
    (BLOCK LOOP-BLOCK-6
      (LET ((#2=#:SEQ-259 (SEQ (VECTOR 5 10))) (#1# #1#))
        (TAGBODY
         LOOP-6
          (LET ((RESULT-6
                 (PROGN
                  (IF (TRUTHY? (TRUTHY? #2#))
                      (PROGN
                       (LET ((#3=#:ITEM-260 (FIRST #2#)))
                         (LET ((X #3#))
                           (PROGN
                            (PSETQ #2# (REST #2#)
                                   #1# (CONJ #1# (PROGN (* X 2))))
                            (GO LOOP-6)))))
                      #1#))))
            (RETURN-FROM LOOP-BLOCK-6 RESULT-6)))))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (FIRST FOR-RESULT2) 10))))
    (PROGN (ERROR "for multiplies first element"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (FIRST (REST FOR-RESULT2)) 20))))
    (PROGN (ERROR "for multiplies second element"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (+ 5 10) 15))))
    (PROGN (ERROR "-> threads value as first arg"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (* (+ 5 10) 2) 30))))
    (PROGN (ERROR "-> threads through multiple forms"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (INC (INC 5)) 7))))
    (PROGN (ERROR "-> works with function symbols"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (- (* (+ 2 3) 4) 1) 19))))
    (PROGN (ERROR "-> complex threading"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (+ 10 5) 15))))
    (PROGN (ERROR "->> threads value as last arg"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (+ 1 (* 2 5)) 11))))
    (PROGN (ERROR "->> last arg threading"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X
               (LET ((X 5))
                 (+ X 10))))
          (- X 5))
        10))))
    (PROGN (ERROR "as-> binds and threads through expressions"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((X
               (LET ((X
                      (LET ((X 3))
                        (* X 2))))
                 (+ X 1))))
          (- X 2))
        5))))
    (PROGN (ERROR "as-> complex transformations"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-261 5))
          (IF (TRUTHY? TRUE)
              (+ #1# 10)
              #1#))
        15))))
    (PROGN (ERROR "cond-> executes with true condition"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-262 5))
          (IF (TRUTHY? FALSE)
              (+ #1# 10)
              #1#))
        5))))
    (PROGN (ERROR "cond-> skips with false condition"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-264
               (LET ((#2=#:EXPR-263 5))
                 (IF (TRUTHY? TRUE)
                     (+ #2# 10)
                     #2#))))
          (IF (TRUTHY? TRUE)
              (* #1# 2)
              #1#))
        30))))
    (PROGN (ERROR "cond-> chains multiple conditions"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-266
               (LET ((#2=#:EXPR-265 5))
                 (IF (TRUTHY? TRUE)
                     (+ #2# 10)
                     #2#))))
          (IF (TRUTHY? FALSE)
              (* #1# 2)
              #1#))
        15))))
    (PROGN (ERROR "cond-> skips later false conditions"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-267 5))
          (IF (TRUTHY? TRUE)
              (+ 10 #1#)
              #1#))
        15))))
    (PROGN (ERROR "cond->> executes with true condition"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-268 5))
          (IF (TRUTHY? FALSE)
              (+ 10 #1#)
              #1#))
        5))))
    (PROGN (ERROR "cond->> skips with false condition"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-270
               (LET ((#2=#:EXPR-269 5))
                 (IF (TRUTHY? TRUE)
                     (* 2 #2#)
                     #2#))))
          (IF (TRUTHY? TRUE)
              (+ 10 #1#)
              #1#))
        20))))
    (PROGN (ERROR "cond->> chains multiple conditions (thread-last)"))
    NIL)

(DEFVAR MYVAR 10)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((MYVAR 20))
          MYVAR)
        20))))
    (PROGN (ERROR "with-redefs temporarily rebinds"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= MYVAR 10))))
    (PROGN (ERROR "with-redefs restores original binding"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= NIL NIL))))
    (PROGN (ERROR "comment returns nil"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (PROGN NIL 42) 42))))
    (PROGN (ERROR "comment prevents evaluation"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? TRUE)))
    (PROGN (ERROR "simple true assertion"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= 1 1))))
    (PROGN (ERROR "equality assertion"))
    NIL)

(DEFVAR MACRO-COMP-RESULT (ATOM (VECTOR)))

(BLOCK LOOP-BLOCK-7
  (LET ((#1=#:SEQ-271 (SEQ (VECTOR 1 2 3))))
    (TAGBODY
     LOOP-7
      (LET ((RESULT-7
             (PROGN
              (IF (TRUTHY? #1#)
                  (PROGN
                   (LET ((X (FIRST #1#)))
                     (PROGN
                      (IF (TRUTHY? (> X 1))
                          (PROGN
                           (SWAP! MACRO-COMP-RESULT (LAMBDA (A) (CONJ A X))))
                          NIL)
                      (PROGN (PSETQ #1# (REST #1#)) (GO LOOP-7)))))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-7 RESULT-7)))))

(IF (TRUTHY?
     (COMMON-LISP:NOT (TRUTHY? (= (DEREF MACRO-COMP-RESULT) (VECTOR 2 3)))))
    (PROGN (ERROR "when inside doseq filters elements"))
    NIL)

(DEFVAR IF-LET-FOR
  (LET ((X 5))
    (IF (TRUTHY? X)
        (LET ((#1=#:RESULT-272 (VECTOR)))
          (BLOCK LOOP-BLOCK-8
            (LET ((#2=#:SEQ-273 (SEQ (VECTOR 1 2 3))) (#1# #1#))
              (TAGBODY
               LOOP-8
                (LET ((RESULT-8
                       (PROGN
                        (IF (TRUTHY? (TRUTHY? #2#))
                            (PROGN
                             (LET ((#3=#:ITEM-274 (FIRST #2#)))
                               (LET ((I #3#))
                                 (PROGN
                                  (PSETQ #2# (REST #2#)
                                         #1# (CONJ #1# (PROGN (+ X I))))
                                  (GO LOOP-8)))))
                            #1#))))
                  (RETURN-FROM LOOP-BLOCK-8 RESULT-8))))))
        (VECTOR))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (FIRST IF-LET-FOR) 6))))
    (PROGN (ERROR "if-let with for first element"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-277
               (LET ((#2=#:EXPR-276
                      (LET ((#3=#:EXPR-275 10))
                        (IF (TRUTHY? TRUE)
                            (+ #3# 5)
                            #3#))))
                 (IF (TRUTHY? TRUE)
                     (* #2# 2)
                     #2#))))
          (IF (TRUTHY? TRUE)
              (- #1# 5)
              #1#))
        25))))
    (PROGN (ERROR "cond-> multiple threading"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:PRED-278 #'=))
          (LET ((#2=#:EXPR-279 1))
            (IF (TRUTHY?
                 (LET ((#3=#:OP288 #1#))
                   (COND ((FUNCTIONP #3#) (FUNCALL #3# . #4=(1 #2#)))
                         ((TYPEP #3# . #5=('<DICT>)) (GET #3# . #4#))
                         ((TYPEP #3# . #6=('<VECTOR>)) (NTH #3# . #4#))
                         ((TYPEP #3# . #7=('<SET>)) (GET #3# . #4#))
                         (T
                          (ERROR #8="Value ~S is not callable or a collection"
                                 #3#)))))
                "one"
                (IF (TRUTHY?
                     (LET ((#9=#:OP289 #1#))
                       (COND ((FUNCTIONP #9#) (FUNCALL #9# . #10=(2 #2#)))
                             ((TYPEP #9# . #5#) (GET #9# . #10#))
                             ((TYPEP #9# . #6#) (NTH #9# . #10#))
                             ((TYPEP #9# . #7#) (GET #9# . #10#))
                             (T (ERROR #8# #9#)))))
                    "two"
                    (IF (TRUTHY?
                         (LET ((#11=#:OP290 #1#))
                           (COND
                            ((FUNCTIONP #11#) (FUNCALL #11# . #12=(3 #2#)))
                            ((TYPEP #11# . #5#) (GET #11# . #12#))
                            ((TYPEP #11# . #6#) (NTH #11# . #12#))
                            ((TYPEP #11# . #7#) (GET #11# . #12#))
                            (T (ERROR #8# #11#)))))
                        "three"
                        NIL)))))
        "one"))))
    (PROGN (ERROR "condp matches first clause"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:PRED-280 #'=))
          (LET ((#2=#:EXPR-281 2))
            (IF (TRUTHY?
                 (LET ((#3=#:OP291 #1#))
                   (COND ((FUNCTIONP #3#) (FUNCALL #3# . #4=(1 #2#)))
                         ((TYPEP #3# . #5=('<DICT>)) (GET #3# . #4#))
                         ((TYPEP #3# . #6=('<VECTOR>)) (NTH #3# . #4#))
                         ((TYPEP #3# . #7=('<SET>)) (GET #3# . #4#))
                         (T
                          (ERROR #8="Value ~S is not callable or a collection"
                                 #3#)))))
                "one"
                (IF (TRUTHY?
                     (LET ((#9=#:OP292 #1#))
                       (COND ((FUNCTIONP #9#) (FUNCALL #9# . #10=(2 #2#)))
                             ((TYPEP #9# . #5#) (GET #9# . #10#))
                             ((TYPEP #9# . #6#) (NTH #9# . #10#))
                             ((TYPEP #9# . #7#) (GET #9# . #10#))
                             (T (ERROR #8# #9#)))))
                    "two"
                    (IF (TRUTHY?
                         (LET ((#11=#:OP293 #1#))
                           (COND
                            ((FUNCTIONP #11#) (FUNCALL #11# . #12=(3 #2#)))
                            ((TYPEP #11# . #5#) (GET #11# . #12#))
                            ((TYPEP #11# . #6#) (NTH #11# . #12#))
                            ((TYPEP #11# . #7#) (GET #11# . #12#))
                            (T (ERROR #8# #11#)))))
                        "three"
                        NIL)))))
        "two"))))
    (PROGN (ERROR "condp matches middle clause"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:PRED-282 #'=))
          (LET ((#2=#:EXPR-283 3))
            (IF (TRUTHY?
                 (LET ((#3=#:OP294 #1#))
                   (COND ((FUNCTIONP #3#) (FUNCALL #3# . #4=(1 #2#)))
                         ((TYPEP #3# . #5=('<DICT>)) (GET #3# . #4#))
                         ((TYPEP #3# . #6=('<VECTOR>)) (NTH #3# . #4#))
                         ((TYPEP #3# . #7=('<SET>)) (GET #3# . #4#))
                         (T
                          (ERROR #8="Value ~S is not callable or a collection"
                                 #3#)))))
                "one"
                (IF (TRUTHY?
                     (LET ((#9=#:OP295 #1#))
                       (COND ((FUNCTIONP #9#) (FUNCALL #9# . #10=(2 #2#)))
                             ((TYPEP #9# . #5#) (GET #9# . #10#))
                             ((TYPEP #9# . #6#) (NTH #9# . #10#))
                             ((TYPEP #9# . #7#) (GET #9# . #10#))
                             (T (ERROR #8# #9#)))))
                    "two"
                    (IF (TRUTHY?
                         (LET ((#11=#:OP296 #1#))
                           (COND
                            ((FUNCTIONP #11#) (FUNCALL #11# . #12=(3 #2#)))
                            ((TYPEP #11# . #5#) (GET #11# . #12#))
                            ((TYPEP #11# . #6#) (NTH #11# . #12#))
                            ((TYPEP #11# . #7#) (GET #11# . #12#))
                            (T (ERROR #8# #11#)))))
                        "three"
                        NIL)))))
        "three"))))
    (PROGN (ERROR "condp matches last clause"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:PRED-284 #'=))
          (LET ((#2=#:EXPR-285 5))
            (IF (TRUTHY?
                 (LET ((#3=#:OP297 #1#))
                   (COND ((FUNCTIONP #3#) (FUNCALL #3# . #4=(1 #2#)))
                         ((TYPEP #3# . #5=('<DICT>)) (GET #3# . #4#))
                         ((TYPEP #3# . #6=('<VECTOR>)) (NTH #3# . #4#))
                         ((TYPEP #3# . #7=('<SET>)) (GET #3# . #4#))
                         (T
                          (ERROR #8="Value ~S is not callable or a collection"
                                 #3#)))))
                "one"
                (IF (TRUTHY?
                     (LET ((#9=#:OP298 #1#))
                       (COND ((FUNCTIONP #9#) (FUNCALL #9# . #10=(2 #2#)))
                             ((TYPEP #9# . #5#) (GET #9# . #10#))
                             ((TYPEP #9# . #6#) (NTH #9# . #10#))
                             ((TYPEP #9# . #7#) (GET #9# . #10#))
                             (T (ERROR #8# #9#)))))
                    "two"
                    "default"))))
        "default"))))
    (PROGN (ERROR "condp falls through to default"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:PRED-286 #'<))
          (LET ((#2=#:EXPR-287 5))
            (IF (TRUTHY?
                 (LET ((#3=#:OP299 #1#))
                   (COND ((FUNCTIONP #3#) (FUNCALL #3# . #4=(3 #2#)))
                         ((TYPEP #3# . #5=('<DICT>)) (GET #3# . #4#))
                         ((TYPEP #3# . #6=('<VECTOR>)) (NTH #3# . #4#))
                         ((TYPEP #3# . #7=('<SET>)) (GET #3# . #4#))
                         (T
                          (ERROR #8="Value ~S is not callable or a collection"
                                 #3#)))))
                "lt-5"
                (IF (TRUTHY?
                     (LET ((#9=#:OP300 #1#))
                       (COND ((FUNCTIONP #9#) (FUNCALL #9# . #10=(10 #2#)))
                             ((TYPEP #9# . #5#) (GET #9# . #10#))
                             ((TYPEP #9# . #6#) (NTH #9# . #10#))
                             ((TYPEP #9# . #7#) (GET #9# . #10#))
                             (T (ERROR #8# #9#)))))
                    "lt-10"
                    "large"))))
        "lt-5"))))
    (PROGN (ERROR "condp with < predicate"))
    NIL)

(DEFVAR WHILE-COUNTER (ATOM 0))

(BLOCK LOOP-BLOCK-9
  (LET ((#1=#:WHILE-301 NIL))
    (TAGBODY
     LOOP-9
      (LET ((RESULT-9
             (PROGN
              (IF (TRUTHY? (< (DEREF WHILE-COUNTER) 3))
                  (PROGN
                   (SWAP! WHILE-COUNTER #'INC)
                   (PROGN (PSETQ #1# NIL) (GO LOOP-9)))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-9 RESULT-9)))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF WHILE-COUNTER) 3))))
    (PROGN (ERROR "while loops until condition false"))
    NIL)

(DEFVAR WHILE-ZERO (ATOM 0))

(BLOCK LOOP-BLOCK-10
  (LET ((#1=#:WHILE-302 NIL))
    (TAGBODY
     LOOP-10
      (LET ((RESULT-10
             (PROGN
              (IF (TRUTHY? FALSE)
                  (PROGN
                   (SWAP! WHILE-ZERO #'INC)
                   (PROGN (PSETQ #1# NIL) (GO LOOP-10)))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-10 RESULT-10)))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF WHILE-ZERO) 0))))
    (PROGN (ERROR "while with false condition does not execute body"))
    NIL)

(DEFVAR WHILE-SUM (ATOM 0))

(DEFVAR WHILE-I (ATOM 1))

(BLOCK LOOP-BLOCK-11
  (LET ((#1=#:WHILE-303 NIL))
    (TAGBODY
     LOOP-11
      (LET ((RESULT-11
             (PROGN
              (IF (TRUTHY? (<= (DEREF WHILE-I) 4))
                  (PROGN
                   (SWAP! WHILE-SUM
                          (LAMBDA (S)
                            (DECLARE (SPECIAL WHILE-I))
                            (+ S (DEREF WHILE-I))))
                   (SWAP! WHILE-I #'INC)
                   (PROGN (PSETQ #1# NIL) (GO LOOP-11)))
                  NIL))))
        (RETURN-FROM LOOP-BLOCK-11 RESULT-11)))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (DEREF WHILE-SUM) 10))))
    (PROGN (ERROR "while accumulates 1+2+3+4=10"))
    NIL)

(DEFUN NIL-FN (X) NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-304
               (LET ((#1# 5))
                 (IF (TRUTHY? (SOME? #1#))
                     (PROGN (INC #1#))
                     NIL))))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (* #1# 2))
              NIL))
        12))))
    (PROGN (ERROR "some-> chains non-nil values"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-305
               (LET ((#1# NIL))
                 (IF (TRUTHY? (SOME? #1#))
                     (PROGN (INC #1#))
                     NIL))))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (* #1# 2))
              NIL))
        NIL))))
    (PROGN (ERROR "some-> short-circuits on nil input"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-306
               (LET ((#1# 5))
                 (IF (TRUTHY? (SOME? #1#))
                     (PROGN (NIL-FN #1#))
                     NIL))))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (* #1# 2))
              NIL))
        NIL))))
    (PROGN (ERROR "some-> short-circuits when step returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-307 10))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (INC #1#))
              NIL))
        11))))
    (PROGN (ERROR "some-> with single form"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= 42 42))))
    (PROGN (ERROR "some-> with no forms returns value"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-308
               (LET ((#1# 5))
                 (IF (TRUTHY? (SOME? #1#))
                     (PROGN (* 2 #1#))
                     NIL))))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (+ 1 #1#))
              NIL))
        11))))
    (PROGN (ERROR "some->> threads as last arg"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-309
               (LET ((#1# NIL))
                 (IF (TRUTHY? (SOME? #1#))
                     (PROGN (* 2 #1#))
                     NIL))))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (+ 1 #1#))
              NIL))
        NIL))))
    (PROGN (ERROR "some->> short-circuits on nil input"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-310
               (LET ((#1# 5))
                 (IF (TRUTHY? (SOME? #1#))
                     (PROGN (NIL-FN #1#))
                     NIL))))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (* 2 #1#))
              NIL))
        NIL))))
    (PROGN (ERROR "some->> short-circuits when step returns nil"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:EXPR-311 3))
          (IF (TRUTHY? (SOME? #1#))
              (PROGN (* 4 #1#))
              NIL))
        12))))
    (PROGN (ERROR "some->> with single form"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (PROGN (+ 1 2)) 3))))
    (PROGN (ERROR "with-precision evaluates body"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= (PROGN (* 6 7)) 42))))
    (PROGN (ERROR "with-precision returns body value"))
    NIL)

(DEFVAR LOCAL-VARS-RESULT
  (LET ((X (ATOM 10)))
    (LET ((Y (ATOM 20)))
      (PROGN (RESET! X (+ (DEREF X) (DEREF Y))) (DEREF X)))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= LOCAL-VARS-RESULT 30))))
    (PROGN (ERROR "with-local-vars creates mutable atom bindings"))
    NIL)

(DEFVAR LOCAL-VARS-RESULT2
  (LET ((A (ATOM 5)))
    (LET ((B (ATOM 3)))
      (PROGN (SWAP! A (LAMBDA (V) (* V (DEREF B)))) (DEREF A)))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= LOCAL-VARS-RESULT2 15))))
    (PROGN (ERROR "with-local-vars independent bindings multiply correctly"))
    NIL)

(DEFVAR CAPTURED
  (LET ((#1=#:STREAM-312 (STRING-OUTPUT-STREAM)))
    (LET ((*OUT* #1#))
      (PRINT "hello")
      (GET-OUTPUT-STRING #1#))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (NOT (NIL? CAPTURED)))))
    (PROGN (ERROR "with-out-str returns a non-nil string"))
    NIL)

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (INCLUDES? CAPTURED "hello"))))
    (PROGN (ERROR "with-out-str captures print output"))
    NIL)

(DEFVAR CAPTURED2
  (LET ((#1=#:STREAM-313 (STRING-OUTPUT-STREAM)))
    (LET ((*OUT* #1#))
      (PRINTLN "world")
      (GET-OUTPUT-STRING #1#))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (INCLUDES? CAPTURED2 "world"))))
    (PROGN (ERROR "with-out-str captures println output"))
    NIL)

(DEFVAR CAPTURED-EMPTY
  (LET ((#1=#:STREAM-314 (STRING-OUTPUT-STREAM)))
    (LET ((*OUT* #1#))
      NIL
      (GET-OUTPUT-STRING #1#))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= CAPTURED-EMPTY ""))))
    (PROGN (ERROR "with-out-str returns empty string for no output"))
    NIL)

(DEFVAR LINE-FROM-STR
  (LET ((#1=#:STREAM-315 (STRING-INPUT-STREAM "hello world")))
    (LET ((*IN* #1#))
      (READ-LINE))))

(IF (TRUTHY? (COMMON-LISP:NOT (TRUTHY? (= LINE-FROM-STR "hello world"))))
    (PROGN (ERROR "with-in-str binds *in* to string input"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:START-316 (GET-INTERNAL-REAL-TIME)))
          (LET ((#2=#:RESULT-318 (PROGN (+ 1 2))))
            (LET ((#3=#:END-317 (GET-INTERNAL-REAL-TIME)))
              (PROGN
               (COMMON-LISP:FORMAT T "Elapsed time: ~,3F msecs~%"
                                   (COMMON-LISP:*
                                    (COMMON-LISP:/
                                     (COERCE (COMMON-LISP:- #3# #1#) 'FLOAT)
                                     (COERCE INTERNAL-TIME-UNITS-PER-SECOND
                                             'FLOAT))
                                    1000.0))
               #2#))))
        3))))
    (PROGN (ERROR "time returns body result"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (=
        (LET ((#1=#:START-319 (GET-INTERNAL-REAL-TIME)))
          (LET ((#2=#:RESULT-321 (PROGN (* 6 7))))
            (LET ((#3=#:END-320 (GET-INTERNAL-REAL-TIME)))
              (PROGN
               (COMMON-LISP:FORMAT T "Elapsed time: ~,3F msecs~%"
                                   (COMMON-LISP:*
                                    (COMMON-LISP:/
                                     (COERCE (COMMON-LISP:- #3# #1#) 'FLOAT)
                                     (COERCE INTERNAL-TIME-UNITS-PER-SECOND
                                             'FLOAT))
                                    1000.0))
               #2#))))
        42))))
    (PROGN (ERROR "time returns correct arithmetic result"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY? (= (COUNT (CONCAT (VECTOR 1 2) (VECTOR 3 4))) 4))))
    (PROGN (ERROR "lazy-cat concatenates two vectors"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY? (= (FIRST (CONCAT (VECTOR 1 2) (VECTOR 3 4))) 1))))
    (PROGN (ERROR "lazy-cat first element"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY? (= (NTH (CONCAT (VECTOR 1 2) (VECTOR 3 4)) 2) 3))))
    (PROGN (ERROR "lazy-cat crosses boundary correctly"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY? (= (COUNT (CONCAT (VECTOR) (VECTOR 1 2 3))) 3))))
    (PROGN (ERROR "lazy-cat with empty first collection"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT (TRUTHY? (= (COUNT (CONCAT (VECTOR 1 2) (VECTOR))) 2))))
    (PROGN (ERROR "lazy-cat with empty second collection"))
    NIL)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY? (= (COUNT (CONCAT (VECTOR 1) (VECTOR 2) (VECTOR 3))) 3))))
    (PROGN (ERROR "lazy-cat with three collections"))
    NIL)

(DEFVAR UNDOC-SYM 42)

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY? (= (FUNCALL 'FOL.COMPILER.METADATA:DOC 'UNDOC-SYM) NIL))))
    (PROGN (ERROR "doc returns nil for symbol without metadata"))
    NIL)

(ALTER-META! 'DOC-TEST-SYM (LAMBDA (M) (DICT :DOC "a test symbol")))

(IF (TRUTHY?
     (COMMON-LISP:NOT
      (TRUTHY?
       (= (FUNCALL 'FOL.COMPILER.METADATA:DOC 'DOC-TEST-SYM)
          "a test symbol"))))
    (PROGN (ERROR "doc retrieves :doc from metadata"))
    NIL)
