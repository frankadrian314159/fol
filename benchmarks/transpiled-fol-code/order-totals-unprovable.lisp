;;; Transpiled from order-totals-unprovable.fol
(in-package :fol.core)

(DEFCLASS <ORDER2> (<PERSISTENT-OBJECT>)
          ((SUBTOTAL :INITARG :SUBTOTAL) (TAX :INITARG :TAX)
           (SHIPPING :INITARG :SHIPPING))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<ORDER2> (&KEY (SUBTOTAL . #1=(NIL)) (TAX . #1#) (SHIPPING . #1#))
  (LET ((FOL.COMPILER::OBJ
         (ALLOCATE-INSTANCE (LOAD-TIME-VALUE (FIND-CLASS '<ORDER2>)))))
    (LET ((FOL.COMPILER.PERSISTENT::*INITIALIZING-PERSISTENT-OBJECT* T))
      (SETF (SLOT-VALUE FOL.COMPILER::OBJ 'SUBTOTAL) SUBTOTAL)
      (SETF (SLOT-VALUE FOL.COMPILER::OBJ 'TAX) TAX)
      (SETF (SLOT-VALUE FOL.COMPILER::OBJ 'SHIPPING) SHIPPING)
      (SETF (FOL.COMPILER.PERSISTENT::%TRANSIENT-OWNER
             . #2=(FOL.COMPILER::OBJ))
              . #1#)
      (SETF (FOL.COMPILER.PERSISTENT::%SCHEMA-VERSION . #2#)
              (FOL.COMPILER.PERSISTENT::PERSISTENT-CLASS-VERSION-COUNTER
               (CLASS-OF . #2#))))
    . #2#))

'<ORDER2>

(DEFUN BUILD-ORDER2 (&REST ARGS)
  (DECLARE (SPECIAL MAKE-<ORDER2>))
  (COND
   ((COMMON-LISP:= (LENGTH ARGS) 1)
    (LET ((I (COMMON-LISP:NTH 0 ARGS)))
      (IF (FBOUNDP 'MAKE-<ORDER2>)
          (MAKE-<ORDER2> . #1=(:SUBTOTAL (* I 3) :TAX (* I 1) :SHIPPING 5))
          (LET ((#2=#:VAL237 MAKE-<ORDER2>))
            (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                  (T
                   (ERROR #3="~S is not a function or collection"
                          'MAKE-<ORDER2>)))))))
   ((COMMON-LISP:= (LENGTH ARGS) 2)
    (LET ((I (COMMON-LISP:NTH 0 ARGS)) (UNUSED (COMMON-LISP:NTH 1 ARGS)))
      (IF (FBOUNDP 'MAKE-<ORDER2>)
          (MAKE-<ORDER2> . #4=(:SUBTOTAL I :TAX I :SHIPPING I))
          (LET ((#5=#:VAL238 MAKE-<ORDER2>))
            (COND ((FUNCTIONP #5#) (FUNCALL #5# . #4#))
                  (T (ERROR #3# 'MAKE-<ORDER2>)))))))
   (T (ERROR "No matching fn clause for ~D arguments: ~S" (LENGTH ARGS) ARGS))))

(DEFUN ORDER2-TOTAL (O)
  (+ (GET O :SUBTOTAL) (+ (GET O :TAX) (GET O :SHIPPING))))

(DEFUN SUM-ORDERS2 (N)
  (BLOCK LOOP-BLOCK-1
    (LET ((I 0) (TOTAL 0))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (PROGN
                (IF (TRUTHY? (< I N))
                    (PROGN
                     (PSETQ I (INC I)
                            TOTAL (+ TOTAL (ORDER2-TOTAL (BUILD-ORDER2 I))))
                     (GO LOOP-1))
                    TOTAL))))
          (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))
