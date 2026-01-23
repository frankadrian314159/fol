(in-package :fol.fol-mop)

;;; ============================================================================
;;; FOL MOP - Metaobject Protocol with Vector Syntax
;;; ============================================================================
;;; This module provides FOL-style versions of CLOS definition forms that use
;;; vectors instead of lists for structural elements:
;;;   - defgeneric* : lambda-list in a vector
;;;   - defclass*   : superclasses and slots in vectors
;;;   - defmethod*  : specialized lambda-list in a vector

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun vector-to-list (vec)
  "Convert a FOL <vector> to a CL list."
  (if (fol.collection:<vector>? vec)
      (let ((result nil))
        (fset:do-seq (item (slot-value vec 'fol.collection::items))
          (push item result))
        (nreverse result))
      vec))

(defun convert-slot-specifier (slot-spec)
  "Convert a FOL slot specifier to CL format.
   Handles both simple symbols and full slot specifications with vectors."
  (if (fol.collection:<vector>? slot-spec)
      (vector-to-list slot-spec)
      slot-spec))

(defun convert-specialized-param (param)
  "Convert a specialized parameter from FOL format to CL format.
   [var class-name] -> (var class-name)
   [var (eql form)] -> (var (eql form))
   var -> var"
  (if (fol.collection:<vector>? param)
      (vector-to-list param)
      param))

;;; ============================================================================
;;; Generic Constructor: make
;;; ============================================================================
;;; A universal constructor function that creates instances of FOL classes.
;;; Dispatches to appropriate constructors based on the class type.

(defun make (class &rest values)
  "Create an instance of CLASS with the given VALUES.

   For collection types (can be empty):
     (make <vector>)           => []
     (make <vector> 1 2 3)     => [1 2 3]
     (make <list>)             => ()
     (make <set> 1 2 3)        => #{1 2 3}
     (make <dict> :a 1 :b 2)   => {:a 1 :b 2}

   For wrapper types (require exactly one value):
     (make <string> \"hello\")  => #<STRING \"hello\">
     (make <bool> t)           => #<BOOL T>

   CLASS can be a class name symbol or a class object.
   Non-collection classes require at least one initial value."
  (let* ((class-name (etypecase class
                       (symbol class)
                       (class (class-name class))))
         (name-string (symbol-name class-name)))
    ;; Compare by symbol name to handle symbols from different packages
    (cond
      ;; Collection types - dispatch to their specific constructors (can be empty)
      ((string= name-string "<VECTOR>")
       (apply #'fol.collection:make-vector values))
      ((string= name-string "<LIST>")
       (apply #'fol.collection:make-list values))
      ((string= name-string "<SET>")
       (apply #'fol.collection:make-set values))
      ((string= name-string "<BAG>")
       (apply #'fol.collection:make-bag values))
      ((string= name-string "<DICT>")
       (apply #'fol.collection:make-dict values))
      ((string= name-string "<ARRAY>")
       (apply #'fol.collection:make-array values))
      ((string= name-string "<LAZY-SEQ>")
       (if (= (length values) 1)
           (fol.collection:make-lazy-seq (cl:first values))
           (error "make <lazy-seq> requires exactly one thunk argument")))
      ;; Wrapper types - use :val initarg (require exactly one value)
      ((member name-string '("<STRING>" "<BOOL>" "<CHAR>" "<SYMBOL>" "<KEYWORD>")
               :test #'string=)
       (if (= (length values) 1)
           (make-instance class-name :val (cl:first values))
           (error "make ~A requires exactly one value" class-name)))
      ;; Number wrapper types (require exactly one value)
      ((member name-string '("<NUMBER>" "<COMPLEX>" "<REAL>" "<FLOAT>"
                             "<SINGLE-FLOAT>" "<DOUBLE-FLOAT>" "<RATIONAL>"
                             "<RATIO>" "<INTEGER>" "<FIXNUM>" "<BIGNUM>")
               :test #'string=)
       (if (= (length values) 1)
           (make-instance class-name :val (cl:first values))
           (error "make ~A requires exactly one value" class-name)))
      ;; Stream types - require specific initialization
      ((string= name-string "<STRING-INPUT-STREAM>")
       (if (= (length values) 1)
           (fol.stream:make-string-input-stream (cl:first values))
           (error "make <string-input-stream> requires exactly one string")))
      ((string= name-string "<STRING-OUTPUT-STREAM>")
       (fol.stream:make-string-output-stream))
      ((string= name-string "<FILE-INPUT-STREAM>")
       (if (= (length values) 1)
           (fol.stream:make-file-input-stream (cl:first values))
           (error "make <file-input-stream> requires exactly one file path")))
      ((string= name-string "<FILE-OUTPUT-STREAM>")
       (if (= (length values) 1)
           (fol.stream:make-file-output-stream (cl:first values))
           (error "make <file-output-stream> requires exactly one file path")))
      ;; Default: require at least one value for non-collection types
      (t
       (when (null values)
         (error "make ~A requires at least one initial value" class-name))
       (if (and (= (length values) 1)
                (cl:not (keywordp (cl:first values))))
           ;; Single non-keyword value: try :val
           (make-instance class-name :val (cl:first values))
           ;; Multiple values or keyword args: pass as initargs
           (apply #'make-instance class-name values))))))

;;; ============================================================================
;;; defgeneric*
;;; ============================================================================

(defmacro defgeneric* (function-name lambda-list-vec &rest options)
  "Define a generic function with FOL syntax.
   Lambda list is specified as a vector: [arg1 arg2 ...]

   Syntax:
     (defgeneric* name [lambda-list] option*)

   Example:
     (defgeneric* distance [a b]
       (:documentation \"Calculate distance between two objects.\"))"
  (let ((lambda-list (if (fol.collection:<vector>? lambda-list-vec)
                         (vector-to-list lambda-list-vec)
                         lambda-list-vec)))
    `(defgeneric ,function-name ,lambda-list
       ,@options)))

;;; ============================================================================
;;; defclass*
;;; ============================================================================

(defmacro defclass* (class-name superclasses-vec slots-vec &rest class-options)
  "Define a class with FOL syntax.
   Superclasses and slots are specified as vectors.

   Syntax:
     (defclass* name [superclasses] [slots] class-option*)

   Slots can be:
     - Simple: symbol
     - Full: [slot-name :initarg :name :accessor accessor-name ...]

   Example:
     (defclass* <point> [<persistent-object>]
       [[x :initarg :x :accessor point-x :type real]
        [y :initarg :y :accessor point-y :type real]]
       (:documentation \"A 2D point.\"))"
  (let ((superclasses (if (fol.collection:<vector>? superclasses-vec)
                          (vector-to-list superclasses-vec)
                          superclasses-vec))
        (slots (if (fol.collection:<vector>? slots-vec)
                   (mapcar #'convert-slot-specifier (vector-to-list slots-vec))
                   slots-vec)))
    `(defclass ,class-name ,superclasses
       ,slots
       ,@class-options)))

;;; ============================================================================
;;; defmethod*
;;; ============================================================================

(defmacro defmethod* (function-name &rest args)
  "Define a method with FOL syntax.
   Specialized lambda list is specified as a vector.

   Syntax:
     (defmethod* name qualifier* [specialized-lambda-list] body*)

   Specialized parameters can be:
     - Simple: var
     - Specialized: [var class-name] or [var [eql form]]

   Example:
     (defmethod* distance [[a <point>] [b <point>]]
       (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
                (expt (- (point-y b) (point-y a)) 2))))

     (defmethod* distance :around [[a <point>] [b <point>]]
       (format t \"Computing distance...~%\")
       (call-next-method))"
  ;; Parse qualifiers and lambda-list from args
  ;; Qualifiers are non-list, non-vector atoms before the lambda-list
  (let ((qualifiers nil)
        (lambda-list-vec nil)
        (body nil)
        (remaining args))
    ;; Collect qualifiers (atoms that aren't the lambda list vector)
    (loop while (and remaining
                     (not (fol.collection:<vector>? (car remaining)))
                     (not (listp (car remaining))))
          do (push (pop remaining) qualifiers))
    (setf qualifiers (nreverse qualifiers))
    ;; Next should be the lambda list
    (when remaining
      (setf lambda-list-vec (pop remaining))
      (setf body remaining))
    ;; Convert lambda list
    (let ((lambda-list (if (fol.collection:<vector>? lambda-list-vec)
                           (mapcar #'convert-specialized-param
                                   (vector-to-list lambda-list-vec))
                           lambda-list-vec)))
      `(defmethod ,function-name ,@qualifiers ,lambda-list
         ,@body))))

;;; ============================================================================
;;; Evaluation Support for FOL
;;; ============================================================================
;;; These functions are called by the FOL evaluator to process the special forms.

(defun eval-defgeneric* (name lambda-list-vec options)
  "Evaluate a defgeneric* form at runtime."
  (let ((lambda-list (if (fol.collection:<vector>? lambda-list-vec)
                         (vector-to-list lambda-list-vec)
                         lambda-list-vec)))
    (eval `(defgeneric ,name ,lambda-list ,@options))))

(defun eval-defclass* (name superclasses-vec slots-vec class-options)
  "Evaluate a defclass* form at runtime."
  (let ((superclasses (if (fol.collection:<vector>? superclasses-vec)
                          (vector-to-list superclasses-vec)
                          superclasses-vec))
        (slots (if (fol.collection:<vector>? slots-vec)
                   (mapcar #'convert-slot-specifier (vector-to-list slots-vec))
                   slots-vec)))
    (eval `(defclass ,name ,superclasses ,slots ,@class-options))))

(defun eval-defmethod* (name qualifiers lambda-list-vec body)
  "Evaluate a defmethod* form at runtime."
  (let ((lambda-list (if (fol.collection:<vector>? lambda-list-vec)
                         (mapcar #'convert-specialized-param
                                 (vector-to-list lambda-list-vec))
                         lambda-list-vec)))
    (eval `(defmethod ,name ,@qualifiers ,lambda-list ,@body))))
