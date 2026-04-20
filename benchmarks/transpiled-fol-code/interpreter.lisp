;;; Transpiled from interpreter.fol
(in-package :fol.core)

(DEFPACKAGE "INTERP-FOL"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "*"
                          "TIME"
                          "BIT-NAND"
                          "UNION"
                          "MAX"
                          "LCM"
                          "SOME"
                          "DEFCLASS"
                          "SECOND"
                          "GCD"
                          "SORT"
                          ">"
                          "BUTLAST"
                          "<="
                          "DOTIMES"
                          "POP"
                          "SUBSEQ"
                          "NTH"
                          "COS"
                          "NOT"
                          "DENOMINATOR"
                          "IDENTITY"
                          "MERGE"
                          "THIRD"
                          "ABS"
                          "AND"
                          "REPLACE"
                          "/"
                          "<"
                          "NUMERATOR"
                          "BIT-NOR"
                          "DEFMACRO"
                          "READ"
                          "BIT-ANDC2"
                          "PUSH"
                          "BIT-ANDC1"
                          "/="
                          "TANH"
                          "READ-LINE"
                          "INTERSECTION"
                          "ASINH"
                          "GENSYM"
                          "VECTOR"
                          "EXPT"
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
                          "TAN"
                          "INTERN"
                          "EVERY"
                          "FIRST"
                          ">="
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
                          "="
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
                          "SYMBOL")
  (:EXPORT RUN-BENCH BUILD-CORPUS))

(IN-PACKAGE "INTERP-FOL")

(DEFCLASS <EXPR> (<PERSISTENT-OBJECT>) NIL (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT (LOAD-TIME-VALUE (FIND-CLASS '<EXPR>))
                     . #1#))

'<EXPR>

(DEFCLASS <NUM-EXPR> (<EXPR> <PERSISTENT-OBJECT>) ((VAL :INITARG :VAL))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<NUM-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<NUM-EXPR>)) . #1#))

'<NUM-EXPR>

(DEFCLASS <VAR-EXPR> (<EXPR> <PERSISTENT-OBJECT>) ((NAME :INITARG :NAME))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<VAR-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<VAR-EXPR>)) . #1#))

'<VAR-EXPR>

(DEFCLASS <ADD-EXPR> (<EXPR> <PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<ADD-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<ADD-EXPR>)) . #1#))

'<ADD-EXPR>

(DEFCLASS <MUL-EXPR> (<EXPR> <PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<MUL-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<MUL-EXPR>)) . #1#))

'<MUL-EXPR>

(DEFCLASS <LET-EXPR> (<EXPR> <PERSISTENT-OBJECT>)
          ((BVAR :INITARG :BVAR) (BVAL :INITARG :BVAL) (BODY :INITARG :BODY))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<LET-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<LET-EXPR>)) . #1#))

'<LET-EXPR>

(DEFCLASS <IF-EXPR> (<EXPR> <PERSISTENT-OBJECT>)
          ((TEST :INITARG :TEST) (CONSEQUENT :INITARG :CONSEQUENT)
           (ALTERNATE :INITARG :ALTERNATE))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<IF-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<IF-EXPR>)) . #1#))

'<IF-EXPR>

(DEFCLASS <NEG-EXPR> (<EXPR> <PERSISTENT-OBJECT>) ((ARG :INITARG :ARG))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<NEG-EXPR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (COMMON-LISP:APPLY #'%MAKE-PERSISTENT
                     (LOAD-TIME-VALUE (FIND-CLASS '<NEG-EXPR>)) . #1#))

'<NEG-EXPR>

(DEFGENERIC EVAL-EXPR
    (EXPR ENV))

(DEFMETHOD EVAL-EXPR #1=(E ENV)
  (DECLARE (SPECIAL ENV E))
  (COND ((TYPEP E '<NUM-EXPR>) (GET E :VAL))
        ((TYPEP E '<VAR-EXPR>) (GET ENV (GET E :NAME) 0))
        ((TYPEP E '<ADD-EXPR>)
         (+ (EVAL-EXPR (GET E :LEFT) ENV) (EVAL-EXPR (GET E :RIGHT) ENV)))
        ((TYPEP E '<MUL-EXPR>)
         (* (EVAL-EXPR (GET E :LEFT) ENV) (EVAL-EXPR (GET E :RIGHT) ENV)))
        ((TYPEP E '<LET-EXPR>)
         (LET ((V (EVAL-EXPR (GET E :BVAL) ENV)))
           (LET ((NEW-ENV (ASSOC ENV (GET E :BVAR) V)))
             (EVAL-EXPR (GET E :BODY) NEW-ENV))))
        ((TYPEP E '<IF-EXPR>)
         (IF (TRUTHY? (= (EVAL-EXPR (GET E :TEST) ENV) 0))
             (EVAL-EXPR (GET E :ALTERNATE) ENV)
             (EVAL-EXPR (GET E :CONSEQUENT) ENV)))
        ((TYPEP E '<NEG-EXPR>) (- (EVAL-EXPR (GET E :ARG) ENV)))
        (T
         (ERROR "No matching method clause for ~A with arguments: ~S"
                'EVAL-EXPR (COMMON-LISP:LIST . #1#)))))

(DEFGENERIC PRETTY
    (EXPR))

(DEFMETHOD PRETTY #1=(E)
  (DECLARE (SPECIAL E))
  (COND ((TYPEP E '<NUM-EXPR>) (STR (GET E :VAL)))
        ((TYPEP E '<VAR-EXPR>) (STR (GET E :NAME)))
        ((TYPEP E '<ADD-EXPR>)
         (STR "(+ " (PRETTY (GET E :LEFT)) " " (PRETTY (GET E :RIGHT)) ")"))
        ((TYPEP E '<MUL-EXPR>)
         (STR "(* " (PRETTY (GET E :LEFT)) " " (PRETTY (GET E :RIGHT)) ")"))
        ((TYPEP E '<LET-EXPR>)
         (STR "(let [" (GET E :BVAR) " " (PRETTY (GET E :BVAL)) "] "
              (PRETTY (GET E :BODY)) ")"))
        ((TYPEP E '<IF-EXPR>)
         (STR "(if " (PRETTY (GET E :TEST)) " " (PRETTY (GET E :CONSEQUENT))
              " " (PRETTY (GET E :ALTERNATE)) ")"))
        ((TYPEP E '<NEG-EXPR>) (STR "(- " (PRETTY (GET E :ARG)) ")"))
        (T
         (ERROR "No matching method clause for ~A with arguments: ~S" 'PRETTY
                (COMMON-LISP:LIST . #1#)))))

(DEFGENERIC FREE-VARS
    (EXPR BOUND))

(DEFMETHOD FREE-VARS #1=(E BOUND)
  (DECLARE (SPECIAL E BOUND))
  (COND ((TYPEP E '<NUM-EXPR>) (SET))
        ((TYPEP E '<VAR-EXPR>)
         (IF (TRUTHY? (CONTAINS? BOUND (GET E :NAME)))
             (SET)
             (SET (GET E :NAME))))
        ((TYPEP E '<ADD-EXPR>)
         (UNION (FREE-VARS (GET E :LEFT) BOUND)
                (FREE-VARS (GET E :RIGHT) BOUND)))
        ((TYPEP E '<MUL-EXPR>)
         (UNION (FREE-VARS (GET E :LEFT) BOUND)
                (FREE-VARS (GET E :RIGHT) BOUND)))
        ((TYPEP E '<LET-EXPR>)
         (UNION (FREE-VARS (GET E :BVAL) BOUND)
                (FREE-VARS (GET E :BODY) (CONJ BOUND (GET E :BVAR)))))
        ((TYPEP E '<IF-EXPR>)
         (UNION (FREE-VARS (GET E :TEST) BOUND)
                (UNION (FREE-VARS (GET E :CONSEQUENT) BOUND)
                       (FREE-VARS (GET E :ALTERNATE) BOUND))))
        ((TYPEP E '<NEG-EXPR>) (FREE-VARS (GET E :ARG) BOUND))
        (T
         (ERROR "No matching method clause for ~A with arguments: ~S"
                'FREE-VARS (COMMON-LISP:LIST . #1#)))))

(DEFUN BUILD-EXPR (DEPTH IDX)
  (DECLARE
   (SPECIAL MAKE-<IF-EXPR> MAKE-<LET-EXPR> MAKE-<MUL-EXPR> MAKE-<ADD-EXPR>
    MAKE-<NEG-EXPR> BUILD-EXPR MAKE-<VAR-EXPR> TRUE MAKE-<NUM-EXPR>))
  (IF (TRUTHY? (<= DEPTH 0))
      (IF (TRUTHY? (= (MOD IDX 2) 0))
          (IF (FBOUNDP 'MAKE-<NUM-EXPR>)
              (MAKE-<NUM-EXPR> . #1=(:VAL (MOD IDX 5)))
              (LET ((#2=#:VAL271 MAKE-<NUM-EXPR>))
                (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                      ((TYPEP #2# . #3=('<DICT>)) (GET #2# . #1#))
                      ((TYPEP #2# . #4=('<VECTOR>)) (NTH #2# . #1#))
                      ((TYPEP #2# . #5=('<SET>)) (GET #2# . #1#))
                      (T
                       (ERROR #6="~S is not a function or collection"
                              'MAKE-<NUM-EXPR>)))))
          (IF (FBOUNDP 'MAKE-<VAR-EXPR>)
              (MAKE-<VAR-EXPR>
               . #7=(:NAME
                     (IF (TRUTHY? (= (MOD IDX 3) 0))
                         :X
                         (IF (TRUTHY? (= (MOD IDX 3) 1))
                             :Y
                             (IF (TRUTHY? TRUE)
                                 :Z
                                 NIL)))))
              (LET ((#8=#:VAL272 MAKE-<VAR-EXPR>))
                (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                      ((TYPEP #8# . #3#) (GET #8# . #7#))
                      ((TYPEP #8# . #4#) (NTH #8# . #7#))
                      ((TYPEP #8# . #5#) (GET #8# . #7#))
                      (T (ERROR #6# 'MAKE-<VAR-EXPR>))))))
      (LET ((M (MOD IDX 5)))
        (IF (TRUTHY? (= M 4))
            (IF (FBOUNDP 'MAKE-<NEG-EXPR>)
                (MAKE-<NEG-EXPR>
                 . #9=(:ARG
                       (IF (FBOUNDP 'BUILD-EXPR)
                           (BUILD-EXPR . #10=((- DEPTH 1) (* IDX 2)))
                           (LET ((#11=#:VAL273 BUILD-EXPR))
                             (COND ((FUNCTIONP #11#) (FUNCALL #11# . #10#))
                                   ((TYPEP #11# . #3#) (GET #11# . #10#))
                                   ((TYPEP #11# . #4#) (NTH #11# . #10#))
                                   ((TYPEP #11# . #5#) (GET #11# . #10#))
                                   (T (ERROR #6# 'BUILD-EXPR)))))))
                (LET ((#12=#:VAL274 MAKE-<NEG-EXPR>))
                  (COND ((FUNCTIONP #12#) (FUNCALL #12# . #9#))
                        ((TYPEP #12# . #3#) (GET #12# . #9#))
                        ((TYPEP #12# . #4#) (NTH #12# . #9#))
                        ((TYPEP #12# . #5#) (GET #12# . #9#))
                        (T (ERROR #6# 'MAKE-<NEG-EXPR>)))))
            (LET ((L
                   (IF (FBOUNDP 'BUILD-EXPR)
                       (BUILD-EXPR . #13=((- DEPTH 1) (* IDX 2)))
                       (LET ((#14=#:VAL275 BUILD-EXPR))
                         (COND ((FUNCTIONP #14#) (FUNCALL #14# . #13#))
                               ((TYPEP #14# . #3#) (GET #14# . #13#))
                               ((TYPEP #14# . #4#) (NTH #14# . #13#))
                               ((TYPEP #14# . #5#) (GET #14# . #13#))
                               (T (ERROR #6# 'BUILD-EXPR)))))))
              (LET ((R
                     (IF (FBOUNDP 'BUILD-EXPR)
                         (BUILD-EXPR . #15=((- DEPTH 1) (+ (* IDX 2) 1)))
                         (LET ((#16=#:VAL276 BUILD-EXPR))
                           (COND ((FUNCTIONP #16#) (FUNCALL #16# . #15#))
                                 ((TYPEP #16# . #3#) (GET #16# . #15#))
                                 ((TYPEP #16# . #4#) (NTH #16# . #15#))
                                 ((TYPEP #16# . #5#) (GET #16# . #15#))
                                 (T (ERROR #6# 'BUILD-EXPR)))))))
                (IF (TRUTHY? (= M 0))
                    (IF (FBOUNDP 'MAKE-<ADD-EXPR>)
                        (MAKE-<ADD-EXPR> . #17=(:LEFT L :RIGHT R))
                        (LET ((#18=#:VAL277 MAKE-<ADD-EXPR>))
                          (COND ((FUNCTIONP #18#) (FUNCALL #18# . #17#))
                                (T (ERROR #6# 'MAKE-<ADD-EXPR>)))))
                    (IF (TRUTHY? (= M 1))
                        (IF (FBOUNDP 'MAKE-<MUL-EXPR>)
                            (MAKE-<MUL-EXPR> . #19=(:LEFT L :RIGHT R))
                            (LET ((#20=#:VAL278 MAKE-<MUL-EXPR>))
                              (COND ((FUNCTIONP #20#) (FUNCALL #20# . #19#))
                                    (T (ERROR #6# 'MAKE-<MUL-EXPR>)))))
                        (IF (TRUTHY? (= M 2))
                            (IF (FBOUNDP 'MAKE-<LET-EXPR>)
                                (MAKE-<LET-EXPR>
                                 . #21=(:BVAR :X :BVAL L :BODY R))
                                (LET ((#22=#:VAL279 MAKE-<LET-EXPR>))
                                  (COND
                                   ((FUNCTIONP #22#) (FUNCALL #22# . #21#))
                                   (T (ERROR #6# 'MAKE-<LET-EXPR>)))))
                            (IF (TRUTHY? TRUE)
                                (IF (FBOUNDP 'MAKE-<IF-EXPR>)
                                    (MAKE-<IF-EXPR>
                                     . #23=(:TEST
                                            (IF (FBOUNDP 'MAKE-<VAR-EXPR>)
                                                (MAKE-<VAR-EXPR>
                                                 . #24=(:NAME :X))
                                                (LET ((#25=#:VAL280
                                                       MAKE-<VAR-EXPR>))
                                                  (COND
                                                   ((FUNCTIONP #25#)
                                                    (FUNCALL #25# . #24#))
                                                   ((TYPEP #25# . #3#)
                                                    (GET #25# . #24#))
                                                   ((TYPEP #25# . #4#)
                                                    (NTH #25# . #24#))
                                                   ((TYPEP #25# . #5#)
                                                    (GET #25# . #24#))
                                                   (T
                                                    (ERROR #6#
                                                           'MAKE-<VAR-EXPR>)))))
                                            :CONSEQUENT L :ALTERNATE R))
                                    (LET ((#26=#:VAL281 MAKE-<IF-EXPR>))
                                      (COND
                                       ((FUNCTIONP #26#) (FUNCALL #26# . #23#))
                                       (T (ERROR #6# 'MAKE-<IF-EXPR>)))))
                                NIL))))))))))

(DEFUN BUILD-CORPUS (CORPUS-SIZE DEPTH)
  (MAPV (LAMBDA (I) (BUILD-EXPR DEPTH I)) (RANGE CORPUS-SIZE)))

(DEFUN RUN-BENCH (N)
  (LET ((CORPUS (BUILD-CORPUS 50 5)))
    (LET ((ENV (DICT :X 3 :Y 5 :Z 2)))
      (LET ((#1=#:MAX-282 N))
        (BLOCK LOOP-BLOCK-1
          (LET ((#2=#:I-283 0))
            (TAGBODY
             LOOP-1
              (LET ((RESULT-1
                     (PROGN
                      (IF (TRUTHY? (COMMON-LISP:< #2# #1#))
                          (PROGN
                           (LET ((I #2#))
                             (PROGN
                              (LET ((#3=#:MAX-284 (SIZE CORPUS)))
                                (BLOCK LOOP-BLOCK-2
                                  (LET ((#4=#:I-285 0))
                                    (TAGBODY
                                     LOOP-2
                                      (LET ((RESULT-2
                                             (PROGN
                                              (IF (TRUTHY?
                                                   (COMMON-LISP:< #4# #3#))
                                                  (PROGN
                                                   (LET ((J #4#))
                                                     (PROGN
                                                      (LET ((EXPR
                                                             (NTH CORPUS J)))
                                                        (PROGN
                                                         (EVAL-EXPR EXPR ENV)
                                                         (PRETTY EXPR)
                                                         (FREE-VARS EXPR
                                                          (SET))))
                                                      (PROGN
                                                       (PSETQ #4# (INC #4#))
                                                       (GO LOOP-2)))))
                                                  NIL))))
                                        (RETURN-FROM LOOP-BLOCK-2
                                          RESULT-2))))))
                              (PROGN (PSETQ #2# (INC #2#)) (GO LOOP-1)))))
                          NIL))))
                (RETURN-FROM LOOP-BLOCK-1 RESULT-1)))))))))
