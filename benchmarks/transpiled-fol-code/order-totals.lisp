;;; Transpiled from order-totals.fol
(in-package :fol.core)

(DEFCLASS <ORDER> (<PERSISTENT-OBJECT>)
          ((SUBTOTAL :INITARG :SUBTOTAL) (TAX :INITARG :TAX)
           (SHIPPING :INITARG :SHIPPING))
          (:METACLASS PERSISTENT-CLASS))

(DEFUN MAKE-<ORDER> (&KEY (SUBTOTAL . #1=(NIL)) (TAX . #1#) (SHIPPING . #1#))
  (LET ((FOL.COMPILER::OBJ
         (ALLOCATE-INSTANCE (LOAD-TIME-VALUE (FIND-CLASS '<ORDER>)))))
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

'<ORDER>

(DEFUN BUILD-ORDER (I)
  (DECLARE (SPECIAL MAKE-<ORDER>))
  (IF (FBOUNDP 'MAKE-<ORDER>)
      (MAKE-<ORDER> . #1=(:SUBTOTAL (* I 3) :TAX (* I 1) :SHIPPING 5))
      (LET ((#2=#:VAL237 MAKE-<ORDER>))
        (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'MAKE-<ORDER>))))))

(DEFUN ORDER-TOTAL (O)
  (+
   (IF (CAR
        (LOAD-TIME-VALUE (FOL.COMPILER.WORLD:REGISTER-REGION '(#1="<ORDER>"))
                         . #2=(T)))
       (SLOT-VALUE O 'SUBTOTAL)
       (GET O :SUBTOTAL))
   (+
    (IF (CAR
         (LOAD-TIME-VALUE (FOL.COMPILER.WORLD:REGISTER-REGION '(#1#)) . #2#))
        (SLOT-VALUE O 'TAX)
        (GET O :TAX))
    (IF (CAR
         (LOAD-TIME-VALUE (FOL.COMPILER.WORLD:REGISTER-REGION '(#1#)) . #2#))
        (SLOT-VALUE O 'SHIPPING)
        (GET O :SHIPPING)))))

(DEFUN SUM-ORDERS (N)
  (BLOCK LOOP-BLOCK-1
    (LET ((I 0) (TOTAL 0))
      (TAGBODY
       LOOP-1
        (LET ((RESULT-1
               (PROGN
                (IF (TRUTHY? (< I N))
                    (PROGN
                     (PSETQ I (INC I)
                            TOTAL (+ TOTAL (ORDER-TOTAL (BUILD-ORDER I))))
                     (GO LOOP-1))
                    TOTAL))))
          (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))
