(in-package :fol.compiler.bitwise-operation-functions)

;;; ============================================================================
;;; Bitwise Operations
;;; ============================================================================
;;;
;;; Dedicated bitwise operations that work on integers only.
;;; All operations work transparently on both raw CL integers and wrapped
;;; FOL <integer> objects. Results are returned as raw CL integers.
;;;
;;; Functions:
;;; - bitnot: bitwise NOT (one's complement)
;;; - bitand: bitwise AND
;;; - bitor:  bitwise OR
;;; - bitxor: bitwise XOR
;;; - bit-nand: bitwise NAND
;;; - bit-nor:  bitwise NOR
;;; - bit-andc1: AND complement of first arg with second
;;; - bit-andc2: AND first arg with complement of second
;;; - bit-orc1: OR complement of first arg with second
;;; - bit-orc2: OR first arg with complement of second
;;; - bit-test: test if bit at position is set
;;; - bit-set:  set bit at position
;;; - bit-clear: clear bit at position
;;; - bit-flip: flip bit at position
;;; - bit-count: count 1 bits

;;; ============================================================================
;;; Unary NOT Operation
;;; ============================================================================

(defgeneric bitnot (x)
  (:documentation "Returns the bitwise NOT (one's complement) of integer x."))

(defmethod bitnot ((x integer))
  (cl:lognot x))

(defmethod bitnot ((x <integer>))
  (cl:lognot (fol-value x)))

(defmethod bitnot (x)
  (error "BITNOT requires an integer, got ~A" x))


;;; ============================================================================
;;; Binary/Variadic Bitwise Operations
;;; ============================================================================

(defgeneric bitand (&rest args)
  (:documentation "Returns the bitwise AND of all arguments. With no arguments, returns -1 (all bits set)."))

(defmethod bitand (&rest args)
  (cond
    ((null args) -1)  ; Identity for AND is all 1s
    ((null (cdr args)) (fol-value (car args)))
    (t (reduce #'cl:logand args :key #'fol-value))))


(defgeneric bitor (&rest args)
  (:documentation "Returns the bitwise OR of all arguments. With no arguments, returns 0."))

(defmethod bitor (&rest args)
  (cond
    ((null args) 0)  ; Identity for OR is 0
    ((null (cdr args)) (fol-value (car args)))
    (t (reduce #'cl:logior args :key #'fol-value))))


(defgeneric bitxor (&rest args)
  (:documentation "Returns the bitwise XOR of all arguments. With no arguments, returns 0."))

(defmethod bitxor (&rest args)
  (cond
    ((null args) 0)  ; Identity for XOR is 0
    ((null (cdr args)) (fol-value (car args)))
    (t (reduce #'cl:logxor args :key #'fol-value))))


;;; ============================================================================
;;; Derived Bitwise Operations
;;; ============================================================================

(defgeneric bit-nand (&rest args)
  (:documentation "Returns the bitwise NAND (NOT AND) of all arguments."))

(defmethod bit-nand (&rest args)
  (cl:lognot (apply #'bitand args)))


(defgeneric bit-nor (&rest args)
  (:documentation "Returns the bitwise NOR (NOT OR) of all arguments."))

(defmethod bit-nor (&rest args)
  (cl:lognot (apply #'bitor args)))


(defgeneric bit-andc1 (x y)
  (:documentation "Returns bitwise AND of (NOT x) with y."))

(defmethod bit-andc1 ((x integer) (y integer))
  (cl:logandc1 x y))

(defmethod bit-andc1 ((x <integer>) (y <integer>))
  (cl:logandc1 (fol-value x) (fol-value y)))

(defmethod bit-andc1 ((x <integer>) (y integer))
  (cl:logandc1 (fol-value x) y))

(defmethod bit-andc1 ((x integer) (y <integer>))
  (cl:logandc1 x (fol-value y)))


(defgeneric bit-andc2 (x y)
  (:documentation "Returns bitwise AND of x with (NOT y)."))

(defmethod bit-andc2 ((x integer) (y integer))
  (cl:logandc2 x y))

(defmethod bit-andc2 ((x <integer>) (y <integer>))
  (cl:logandc2 (fol-value x) (fol-value y)))

(defmethod bit-andc2 ((x <integer>) (y integer))
  (cl:logandc2 (fol-value x) y))

(defmethod bit-andc2 ((x integer) (y <integer>))
  (cl:logandc2 x (fol-value y)))


(defgeneric bit-orc1 (x y)
  (:documentation "Returns bitwise OR of (NOT x) with y."))

(defmethod bit-orc1 ((x integer) (y integer))
  (cl:logorc1 x y))

(defmethod bit-orc1 ((x <integer>) (y <integer>))
  (cl:logorc1 (fol-value x) (fol-value y)))

(defmethod bit-orc1 ((x <integer>) (y integer))
  (cl:logorc1 (fol-value x) y))

(defmethod bit-orc1 ((x integer) (y <integer>))
  (cl:logorc1 x (fol-value y)))


(defgeneric bit-orc2 (x y)
  (:documentation "Returns bitwise OR of x with (NOT y)."))

(defmethod bit-orc2 ((x integer) (y integer))
  (cl:logorc2 x y))

(defmethod bit-orc2 ((x <integer>) (y <integer>))
  (cl:logorc2 (fol-value x) (fol-value y)))

(defmethod bit-orc2 ((x <integer>) (y integer))
  (cl:logorc2 (fol-value x) y))

(defmethod bit-orc2 ((x integer) (y <integer>))
  (cl:logorc2 x (fol-value y)))


;;; ============================================================================
;;; Bit Testing and Manipulation
;;; ============================================================================

(defgeneric bit-test (integer position)
  (:documentation "Returns true if the bit at POSITION in INTEGER is set (1)."))

(defmethod bit-test ((integer integer) (position integer))
  (cl:logbitp position integer))

(defmethod bit-test ((integer <integer>) (position integer))
  (cl:logbitp position (fol-value integer)))

(defmethod bit-test ((integer integer) (position <integer>))
  (cl:logbitp (fol-value position) integer))

(defmethod bit-test ((integer <integer>) (position <integer>))
  (cl:logbitp (fol-value position) (fol-value integer)))


(defgeneric bit-set (integer position)
  (:documentation "Returns INTEGER with the bit at POSITION set to 1."))

(defmethod bit-set ((integer integer) (position integer))
  (cl:logior integer (cl:ash 1 position)))

(defmethod bit-set ((integer <integer>) (position integer))
  (cl:logior (fol-value integer) (cl:ash 1 position)))

(defmethod bit-set ((integer integer) (position <integer>))
  (cl:logior integer (cl:ash 1 (fol-value position))))

(defmethod bit-set ((integer <integer>) (position <integer>))
  (cl:logior (fol-value integer) (cl:ash 1 (fol-value position))))


(defgeneric bit-clear (integer position)
  (:documentation "Returns INTEGER with the bit at POSITION set to 0."))

(defmethod bit-clear ((integer integer) (position integer))
  (cl:logand integer (cl:lognot (cl:ash 1 position))))

(defmethod bit-clear ((integer <integer>) (position integer))
  (cl:logand (fol-value integer) (cl:lognot (cl:ash 1 position))))

(defmethod bit-clear ((integer integer) (position <integer>))
  (cl:logand integer (cl:lognot (cl:ash 1 (fol-value position)))))

(defmethod bit-clear ((integer <integer>) (position <integer>))
  (cl:logand (fol-value integer) (cl:lognot (cl:ash 1 (fol-value position)))))


(defgeneric bit-flip (integer position)
  (:documentation "Returns INTEGER with the bit at POSITION flipped (0->1 or 1->0)."))

(defmethod bit-flip ((integer integer) (position integer))
  (cl:logxor integer (cl:ash 1 position)))

(defmethod bit-flip ((integer <integer>) (position integer))
  (cl:logxor (fol-value integer) (cl:ash 1 position)))

(defmethod bit-flip ((integer integer) (position <integer>))
  (cl:logxor integer (cl:ash 1 (fol-value position))))

(defmethod bit-flip ((integer <integer>) (position <integer>))
  (cl:logxor (fol-value integer) (cl:ash 1 (fol-value position))))


(defgeneric bit-count (integer)
  (:documentation "Returns the number of 1 bits in the two's complement representation of INTEGER.
For positive integers, this is the number of set bits.
For negative integers, this is the number of zero bits."))

(defmethod bit-count ((integer integer))
  (cl:logcount integer))

(defmethod bit-count ((integer <integer>))
  (cl:logcount (fol-value integer)))


;;; ============================================================================
;;; Bit Shifting and Rotation
;;; ============================================================================

(defgeneric bit-shift (integer count)
  (:documentation "Shifts INTEGER by COUNT bit positions.
Positive COUNT shifts left, negative COUNT shifts right.
Right shift is arithmetic (sign-extending for negative numbers)."))

(defmethod bit-shift ((integer integer) (count integer))
  (cl:ash integer count))

(defmethod bit-shift ((integer <integer>) (count integer))
  (cl:ash (fol-value integer) count))

(defmethod bit-shift ((integer integer) (count <integer>))
  (cl:ash integer (fol-value count)))

(defmethod bit-shift ((integer <integer>) (count <integer>))
  (cl:ash (fol-value integer) (fol-value count)))


(defgeneric bit-rotate (integer count width)
  (:documentation "Rotates INTEGER by COUNT bit positions within a WIDTH-bit field.
Positive COUNT rotates left, negative COUNT rotates right.
The result is always a non-negative integer with at most WIDTH bits."))

(defun %bit-rotate (integer count width)
  "Internal rotation implementation."
  (let* ((count (cl:mod count width))  ; Normalize count to [0, width)
         (mask (cl:1- (cl:ash 1 width)))  ; Create mask of WIDTH 1-bits
         (val (cl:logand integer mask)))  ; Mask input to WIDTH bits
    (if (cl:zerop count)
        val
        ;; Rotate left by count: high bits wrap to low
        (cl:logand mask
                   (cl:logior (cl:ash val count)
                              (cl:ash val (cl:- count width)))))))

(defmethod bit-rotate ((integer integer) (count integer) (width integer))
  (unless (cl:plusp width)
    (error "BIT-ROTATE width must be positive, got ~A" width))
  (%bit-rotate integer count width))

(defmethod bit-rotate ((integer <integer>) (count integer) (width integer))
  (unless (cl:plusp width)
    (error "BIT-ROTATE width must be positive, got ~A" width))
  (%bit-rotate (fol-value integer) count width))

(defmethod bit-rotate ((integer integer) (count <integer>) (width integer))
  (unless (cl:plusp width)
    (error "BIT-ROTATE width must be positive, got ~A" width))
  (%bit-rotate integer (fol-value count) width))

(defmethod bit-rotate ((integer integer) (count integer) (width <integer>))
  (let ((w (fol-value width)))
    (unless (cl:plusp w)
      (error "BIT-ROTATE width must be positive, got ~A" w))
    (%bit-rotate integer count w)))

(defmethod bit-rotate ((integer <integer>) (count <integer>) (width integer))
  (unless (cl:plusp width)
    (error "BIT-ROTATE width must be positive, got ~A" width))
  (%bit-rotate (fol-value integer) (fol-value count) width))

(defmethod bit-rotate ((integer <integer>) (count integer) (width <integer>))
  (let ((w (fol-value width)))
    (unless (cl:plusp w)
      (error "BIT-ROTATE width must be positive, got ~A" w))
    (%bit-rotate (fol-value integer) count w)))

(defmethod bit-rotate ((integer integer) (count <integer>) (width <integer>))
  (let ((w (fol-value width)))
    (unless (cl:plusp w)
      (error "BIT-ROTATE width must be positive, got ~A" w))
    (%bit-rotate integer (fol-value count) w)))

(defmethod bit-rotate ((integer <integer>) (count <integer>) (width <integer>))
  (let ((w (fol-value width)))
    (unless (cl:plusp w)
      (error "BIT-ROTATE width must be positive, got ~A" w))
    (%bit-rotate (fol-value integer) (fol-value count) w)))
