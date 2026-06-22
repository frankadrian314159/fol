;;; FOL Compiler - Array Functions & Operators
;;;
;;; Implements generic functions for arithmetic, comparison, and logical operations.
;;; These are overloaded to work on scalars (numbers), vectors, and arrays with
;;; automatic type dispatch, broadcasting, and element-wise operations.
;;;
;;; Phase 1 Implementation: Generic Operators

(in-package :fol.compiler.array-functions)

;;; ============================================================================
;;; Arithmetic Operators (Generic Functions)
;;; ============================================================================

;;; Addition: +
(defgeneric + (a &optional b &rest rest)
  (:documentation "Addition supporting scalars, vectors, arrays."))

(defmethod + ((a number) &optional b &rest rest)
  (cond
    ((null b) a)
    ((numberp b)
     (apply #'+ (cl:+ a b) rest))
    ((typep b '<vector>)
     (apply #'+ (vector-broadcast #'(lambda (x) (cl:+ a x)) b) rest))
    (t (error "Type mismatch in + : ~A and ~A" (type-of a) (type-of b)))))

(defmethod + ((a <vector>) &optional b &rest rest)
  (cond
    ((null b) a)
    ((numberp b)
     (apply #'+ (vector-broadcast #'(lambda (x) (cl:+ x b)) a) rest))
    ((typep b '<vector>)
     (apply #'+ (vector-element-wise #'cl:+ a b) rest))
    (t (error "Type mismatch in + : ~A and ~A" (type-of a) (type-of b)))))

;;; Subtraction: -
(defgeneric - (a &optional b &rest rest)
  (:documentation "Subtraction supporting scalars, vectors, arrays."))

(defmethod - ((a number) &optional b &rest rest)
  (cond
    ((null b) (cl:- a))
    ((numberp b)
     (if (null rest)
         (cl:- a b)
         (apply #'- (cl:- a b) rest)))
    ((typep b '<vector>)
     (if (null rest)
         (vector-broadcast #'(lambda (x) (cl:- a x)) b)
         (apply #'- (vector-broadcast #'(lambda (x) (cl:- a x)) b) rest)))
    (t (error "Type mismatch in - : ~A and ~A" (type-of a) (type-of b)))))

(defmethod - ((a <vector>) &optional b &rest rest)
  (cond
    ((null b) a)
    ((numberp b)
     (apply #'- (vector-broadcast #'(lambda (x) (cl:- x b)) a) rest))
    ((typep b '<vector>)
     (apply #'- (vector-element-wise #'cl:- a b) rest))
    (t (error "Type mismatch in - : ~A and ~A" (type-of a) (type-of b)))))

;;; Multiplication: *
(defgeneric * (a &optional b &rest rest)
  (:documentation "Multiplication supporting scalars, vectors, arrays."))

(defmethod * ((a number) &optional b &rest rest)
  (if (null b)
      a
      (if (null rest)
          (cl:* a b)
          (apply #'* (cl:* a b) rest))))

(defmethod * ((a <vector>) &optional b &rest rest)
  (cond
    ((null b) a)
    ((numberp b)
     (if (null rest)
         (vector-broadcast #'(lambda (x) (cl:* x b)) a)
         (apply #'* (vector-broadcast #'(lambda (x) (cl:* x b)) a) rest)))
    ((typep b '<vector>)
     (if (null rest)
         (vector-element-wise #'cl:* a b)
         (apply #'* (vector-element-wise #'cl:* a b) rest)))
    (t (error "Type mismatch in * : ~A and ~A" (type-of a) (type-of b)))))

;;; Division: /
(defgeneric / (a &optional b &rest rest)
  (:documentation "Division supporting scalars, vectors, arrays."))

(defmethod / ((a number) &optional b &rest rest)
  (if (null b)
      (cl:/ 1 a)
      (if (null rest)
          (cl:float (cl:/ a b))
          (apply #'/ (cl:float (cl:/ a b)) rest))))

(defmethod / ((a <vector>) &optional b &rest rest)
  (cond
    ((null b) a)
    ((numberp b)
     (if (null rest)
         (vector-broadcast #'(lambda (x) (cl:/ x b)) a)
         (apply #'/ (vector-broadcast #'(lambda (x) (cl:/ x b)) a) rest)))
    ((typep b '<vector>)
     (if (null rest)
         (vector-element-wise #'cl:/ a b)
         (apply #'/ (vector-element-wise #'cl:/ a b) rest)))
    (t (error "Type mismatch in / : ~A and ~A" (type-of a) (type-of b)))))

;;; ============================================================================
;;; Comparison Operators (Generic Functions)
;;; ============================================================================

;;; Equality: =
(defgeneric = (a &optional b &rest rest)
  (:documentation "Equality test for scalars, vectors, arrays."))

(defmethod = ((a number) &optional b &rest rest)
  (if b
      (if (typep b '<vector>)
          (mapv #'(lambda (x) (cl:= a x)) b)
          (cl:and (cl:= a b) (if rest (apply #'= b rest) t)))
      t))

(defmethod = ((a <vector>) &optional b &rest rest)
  (declare (ignore rest))
  (cond
    ((null b) t)
    ((numberp b)
     (vector-element-wise #'(lambda (x) (cl:= x b)) a))
    ((typep b '<vector>)
     (vector-element-wise #'cl:= a b))
    (t (error "Type mismatch in = : ~A and ~A" (type-of a) (type-of b)))))

;;; Less Than: <
(defgeneric < (a &optional b &rest rest)
  (:documentation "Less-than test for scalars, vectors, arrays."))

(defmethod < ((a number) &optional b &rest rest)
  (if b
      (if (typep b '<vector>)
          (mapv #'(lambda (x) (cl:< a x)) b)
          (cl:and (cl:< a b) (if rest (apply #'< b rest) t)))
      t))

(defmethod < ((a <vector>) &optional b &rest rest)
  (declare (ignore rest))
  (cond
    ((null b) t)
    ((numberp b)
     (vector-element-wise #'(lambda (x) (cl:< x b)) a))
    ((typep b '<vector>)
     (vector-element-wise #'cl:< a b))
    (t (error "Type mismatch in < : ~A and ~A" (type-of a) (type-of b)))))

;;; Greater Than: >
(defgeneric > (a &optional b &rest rest)
  (:documentation "Greater-than test for scalars, vectors, arrays."))

(defmethod > ((a number) &optional b &rest rest)
  (if b
      (if (typep b '<vector>)
          (mapv #'(lambda (x) (cl:> a x)) b)
          (cl:and (cl:> a b) (if rest (apply #'> b rest) t)))
      t))

(defmethod > ((a <vector>) &optional b &rest rest)
  (declare (ignore rest))
  (cond
    ((null b) t)
    ((numberp b)
     (vector-element-wise #'(lambda (x) (cl:> x b)) a))
    ((typep b '<vector>)
     (vector-element-wise #'cl:> a b))
    (t (error "Type mismatch in > : ~A and ~A" (type-of a) (type-of b)))))

;;; Less or Equal: <=
(defgeneric <= (a &optional b &rest rest)
  (:documentation "Less-or-equal test for scalars, vectors, arrays."))

(defmethod <= ((a number) &optional b &rest rest)
  (if b
      (if (typep b '<vector>)
          (mapv #'(lambda (x) (cl:<= a x)) b)
          (cl:and (cl:<= a b) (if rest (apply #'<= b rest) t)))
      t))

(defmethod <= ((a <vector>) &optional b &rest rest)
  (declare (ignore rest))
  (cond
    ((null b) t)
    ((numberp b)
     (vector-element-wise #'(lambda (x) (cl:<= x b)) a))
    ((typep b '<vector>)
     (vector-element-wise #'cl:<= a b))
    (t (error "Type mismatch in <= : ~A and ~A" (type-of a) (type-of b)))))

;;; Greater or Equal: >=
(defgeneric >= (a &optional b &rest rest)
  (:documentation "Greater-or-equal test for scalars, vectors, arrays."))

(defmethod >= ((a number) &optional b &rest rest)
  (if b
      (if (typep b '<vector>)
          (mapv #'(lambda (x) (cl:>= a x)) b)
          (cl:and (cl:>= a b) (if rest (apply #'>= b rest) t)))
      t))

(defmethod >= ((a <vector>) &optional b &rest rest)
  (declare (ignore rest))
  (cond
    ((null b) t)
    ((numberp b)
     (vector-element-wise #'(lambda (x) (cl:>= x b)) a))
    ((typep b '<vector>)
     (vector-element-wise #'cl:>= a b))
    (t (error "Type mismatch in >= : ~A and ~A" (type-of a) (type-of b)))))

;;; Not Equal: not=
(defgeneric not= (a &optional b &rest rest)
  (:documentation "Inequality test for scalars, vectors, arrays."))

(defmethod not= ((a number) &optional b &rest rest)
  (if b
      (if (typep b '<vector>)
          (mapv #'(lambda (x) (cl:not (cl:= a x))) b)
          (cl:and (cl:not (cl:= a b)) (if rest (apply #'not= b rest) t)))
      t))

(defmethod not= ((a <vector>) &optional b &rest rest)
  (declare (ignore rest))
  (cond
    ((null b) t)
    ((numberp b)
     (vector-element-wise #'(lambda (x) (cl:not (cl:= x b))) a))
    ((typep b '<vector>)
     (vector-element-wise #'(lambda (x y) (cl:not (cl:= x y))) a b))
    (t (error "Type mismatch in not= : ~A and ~A" (type-of a) (type-of b)))))

;;; ============================================================================
;;; Logical Operators (Generic Functions)
;;; ============================================================================

;;; Logical AND: and
(defgeneric and (a &rest args)
  (:documentation "Logical AND for scalars and boolean vectors."))

(defmethod and ((a t) &rest args)
  (if (cl:not a)
      a
      (if args
          (apply #'and args)
          a)))

(defmethod and ((a <vector>) &rest args)
  (if (null args)
      a
      (let ((b (first args))
            (rest-args (rest args)))
        (cond
          ((typep b '<vector>)
           (let ((result (vector-element-wise #'(lambda (x y) (cl:and x y)) a b)))
             (if rest-args
                 (apply #'and (cons result rest-args))
                 result)))
          (t (error "Type mismatch in and : ~A and ~A" (type-of a) (type-of b)))))))

;;; Logical OR: or
(defgeneric or (a &rest args)
  (:documentation "Logical OR for scalars and boolean vectors."))

(defmethod or ((a t) &rest args)
  (if a
      a
      (if args
          (apply #'or args)
          a)))

(defmethod or ((a <vector>) &rest args)
  (if (null args)
      a
      (let ((b (first args))
            (rest-args (rest args)))
        (cond
          ((typep b '<vector>)
           (let ((result (vector-element-wise #'(lambda (x y) (cl:or x y)) a b)))
             (if rest-args
                 (apply #'or (cons result rest-args))
                 result)))
          (t (error "Type mismatch in or : ~A and ~A" (type-of a) (type-of b)))))))

;;; Logical NOT: not
(defgeneric not (a)
  (:documentation "Logical NOT for scalars and boolean vectors."))

(defmethod not ((a t))
  (cl:not a))

(defmethod not ((a <vector>))
  (vector-broadcast #'cl:not a))

;;; ============================================================================
;;; Helper Functions for Vector Operations
;;; ============================================================================

(defun vector-element-wise (fn v1 v2)
  "Apply binary function element-wise to two vectors.
   Requires same size."
  (declare (optimize (speed 3) (safety 0)))
  (let* ((size1 (count v1))
         (size2 (count v2)))
    (when (/= size1 size2)
      (error "Size mismatch: v1 has ~D elements, v2 has ~D elements" size1 size2))
    (mapv
     (lambda (e1 e2) (funcall fn e1 e2))
     v1 v2)))

(defun vector-broadcast (fn vec)
  "Apply unary function to every element of vector."
  (declare (optimize (speed 3) (safety 0)))
  (mapv fn vec))

;;; ============================================================================
;;; Phase 1: N-Dimensional Array Functions
;;; ============================================================================

(defun %strides-from-shape (shape-list)
  "Calculate row-major strides from shape dimensions.
   Example: (2 3 4) -> (12 4 1)"
  (declare (optimize (speed 3) (safety 0)))
  (let* ((rank (length shape-list))
         (strides (make-list rank :initial-element 1)))
    (when (> rank 0)
      (loop for i from (cl:- rank 2) downto 0 do
        (setf (nth i strides)
              (cl:* (nth (cl:+ i 1) strides) (nth (cl:+ i 1) shape-list)))))
    strides))

(defun %linear-idx (indices shape)
  "Convert multi-dimensional indices to linear index using row-major ordering."
  (declare (optimize (speed 3) (safety 0)))
  (let ((strides (%strides-from-shape shape)))
    (cl:reduce #'cl:+ (mapcar #'cl:* indices strides) :initial-value 0)))

(defun %shape-list (shape-arg)
  "Normalize shape argument (vector or list) to list of integers."
  (declare (optimize (speed 3) (safety 0)))
  (if (typep shape-arg '<vector>)
      (loop for i below (count shape-arg) collect (get shape-arg i))
      (if (listp shape-arg) shape-arg (list shape-arg))))

(defun create-nd-array (shape &key initial-element)
  "Create an n-dimensional array with given shape.
   If initial-element is provided, all elements are initialized to that value."
  (declare (optimize (speed 3) (safety 0)))
  (let* ((shape-list (%shape-list shape))
         (total-size (cl:reduce #'cl:* shape-list :initial-value 1)))
    (make-instance '<array>
      :dimension shape-list
      :storage (fol.compiler.collection-primitives::%make-filled-vec-t
                total-size (or initial-element 0)))))

(defun nd-shape (arr)
  "Get shape (dimensions) of array as a list."
  (declare (optimize (speed 3) (safety 0)))
  (if (typep arr '<array>)
      (cl:slot-value arr (cl:intern "DIMENSION" :fol.compiler.collections))
      (list (count arr))))

(defun nd-rank (arr)
  "Get rank (number of dimensions) of array."
  (declare (optimize (speed 3) (safety 0)))
  (if (typep arr '<array>)
      (length (cl:slot-value arr (cl:intern "DIMENSION" :fol.compiler.collections)))
      1))

(defun nd-size (arr)
  "Get total number of elements in array."
  (declare (optimize (speed 3) (safety 0)))
  (count arr))
