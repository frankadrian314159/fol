;;; FOL Compiler - Transducers
;;;
;;; Implementation of Clojure-style transducers for FOL.

(in-package :fol.compiler.transducers)

;;; ===========================================================================
;;; Reduced (Early Termination)
;;; ===========================================================================

(defstruct reduced
  val)

(defun reduced (val)
  (make-reduced :val val))

(defun reduced? (x)
  (typep x 'reduced))

(defun deref (x)
  (if (reduced? x) (reduced-val x) x))

(defun unreduced (x)
  (if (reduced? x) (reduced-val x) x))

(defun ensure-reduced (x)
  (if (reduced? x) x (reduced x)))

;;; ===========================================================================
;;; Core Transducers
;;; ===========================================================================

(defun map (f)
  "Returns a transducer that applies f to every input."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (funcall rf acc (funcall f input)))))))

(defun mapcat (f)
  "Returns a transducer that applies f to every input and concatenates the results."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (let ((coll (funcall f input)))
             (let ((iter (fol.compiler.collections:collection-seq coll))
                   (current-acc acc))
               (loop for item in iter
                     do (let ((res (funcall rf current-acc item)))
                          (if (reduced? res)
                              (return res)
                              (setf current-acc res)))
                     finally (return current-acc)))))))))

(defun filter (pred)
  "Returns a transducer that keeps inputs for which pred returns logical true."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (if (fol.compiler.primitives:truthy? (funcall pred input))
               (funcall rf acc input)
               acc))))))

(defun remove (pred)
  "Returns a transducer that removes inputs for which pred returns logical true."
  (filter (cl:complement pred)))

(defun take (n)
  "Returns a transducer that takes the first n inputs."
  (lambda (rf)
    (let ((counter 0))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (if (< counter n)
                 (let ((result (funcall rf acc input)))
                   (incf counter)
                   (if (>= counter n)
                       (ensure-reduced result)
                       result))
                 (ensure-reduced acc))))))))

(defun take-while (pred)
  "Returns a transducer that takes inputs as long as pred returns true."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (if (fol.compiler.primitives:truthy? (funcall pred input))
               (funcall rf acc input)
               (ensure-reduced acc)))))))

(defun take-nth (n)
  "Returns a transducer that takes every nth input."
  (lambda (rf)
    (let ((counter -1)) 
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (incf counter)
             (if (zerop (mod counter n))
                 (funcall rf acc input)
                 acc)))))))

(defun drop (n)
  "Returns a transducer that drops the first n inputs."
  (lambda (rf)
    (let ((counter 0))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (if (< counter n)
                 (progn
                   (incf counter)
                   acc)
                 (funcall rf acc input))))))))

(defun drop-while (pred)
  "Returns a transducer that drops inputs as long as pred returns true."
  (lambda (rf)
    (let ((dropping t))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (if dropping
                 (if (fol.compiler.primitives:truthy? (funcall pred input))
                     acc
                     (progn
                       (setf dropping nil)
                       (funcall rf acc input)))
                 (funcall rf acc input))))))))

(defun replace (smap)
  "Returns a transducer that replaces keys in smap with their values."
  (map (lambda (x)
         (or (fol.compiler.collections:get smap x) x))))

(defun keep (f)
  "Returns a transducer that applies f and keeps non-nil results."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (let ((result (funcall f input)))
             (if result
                 (funcall rf acc result)
                 acc)))))))

(defun keep-indexed (f)
  "Returns a transducer that applies f to (index, input) and keeps non-nil results."
  (lambda (rf)
    (let ((idx -1))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (incf idx)
             (let ((result (funcall f idx input)))
               (if result
                   (funcall rf acc result)
                   acc))))))))

(defun map-indexed (f)
  "Returns a transducer that applies f to (index, input)."
  (lambda (rf)
    (let ((idx -1))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (incf idx)
             (funcall rf acc (funcall f idx input))))))))

(defun distinct ()
  "Returns a transducer that filters out duplicates."
  (lambda (rf)
    (let ((seen (fol.compiler.collection-functions:set)))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (if (fol.compiler.collection-functions:contains? seen input)
                 acc
                 (progn
                   (setf seen (fol.compiler.collection-functions:conj seen input))
                   (funcall rf acc input)))))))))

(defun interpose (sep)
  "Returns a transducer that separates inputs with sep."
  (lambda (rf)
    (let ((started nil))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (if started
                 (let ((result (funcall rf acc sep)))
                   (if (reduced? result)
                       result
                       (funcall rf result input)))
                 (progn
                   (setf started t)
                   (funcall rf acc input)))))))))

(defun dedupe ()
  "Returns a transducer that filters out consecutive duplicates."
  (lambda (rf)
    (let ((prior :none-yet))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) (funcall rf acc))
          (t (if (equal prior input)
                 acc
                 (progn
                   (setf prior input)
                   (funcall rf acc input)))))))))

(defun random-sample (prob)
  "Returns a transducer that returns items with probability prob."
  (filter (lambda (_) 
            (declare (ignore _))
            (< (random 1.0) prob))))

(defun cat ()
  "Returns a transducer that flattens one level of nested collections."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (let ((iter (fol.compiler.collections:collection-seq input))
                 (current-acc acc))
             (loop for item in iter
                   do (let ((res (funcall rf current-acc item)))
                        (if (reduced? res)
                            (return res)
                            (setf current-acc res)))
                   finally (return current-acc))))))))

(defun partition-all (n)
  "Returns a transducer that partitions inputs into lists of size n."
  (lambda (rf)
    (let ((buffer (cl:make-array n :adjustable t :fill-pointer 0)))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) 
           (if (> (length buffer) 0)
               (let ((result (funcall rf acc (fol.compiler.collection-functions:vec buffer))))
                 (funcall rf result)) ;; Complete with buffer
               (funcall rf acc)))
          (t (vector-push-extend input buffer)
             (if (= (length buffer) n)
                 (let ((res (fol.compiler.collection-functions:vec (copy-seq buffer))))
                   (setf (fill-pointer buffer) 0)
                   (funcall rf acc res))
                 acc)))))))

(defun partition-by (f)
  "Returns a transducer that partitions inputs producing a new partition when (f input) changes."
  (lambda (rf)
    (let ((buffer (cl:make-array 0 :adjustable t :fill-pointer 0))
          (prior :none-yet))
      (lambda (&optional (acc nil acc-p) (input nil input-p))
        (cond
          ((not acc-p) (funcall rf))
          ((not input-p) 
           (if (> (length buffer) 0)
               (let ((result (funcall rf acc (fol.compiler.collection-functions:vec buffer))))
                 (funcall rf result))
               (funcall rf acc)))
          (t (let ((val (funcall f input)))
               (cond 
                 ((eq prior :none-yet)
                  (setf prior val)
                  (vector-push-extend input buffer)
                  acc)
                 ((equal val prior)
                  (vector-push-extend input buffer)
                  acc)
                 (t 
                  (let ((res (fol.compiler.collection-functions:vec (copy-seq buffer))))
                    (setf (fill-pointer buffer) 0)
                    (vector-push-extend input buffer)
                    (setf prior val)
                    (funcall rf acc res)))))))))))

(defun halt-when (pred &optional (retf nil))
  "Returns a transducer that ends reduction when pred returns true."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (let ((should-halt (funcall pred input)))
             (if should-halt
                 (ensure-reduced (if retf (funcall retf should-halt input) input))
                 (funcall rf acc input))))))))

;;; ===========================================================================
;;; Transduce
;;; ===========================================================================

(defun completing (rf)
  "Wraps a reducing function to support 0 and 1 arity."
  (lambda (&optional (acc nil acc-p) (input nil input-p))
    (cond
      ((not acc-p) (error "Completing RF requires init via reduce")) ;; 0-arity
      ((not input-p) acc) ;; 1-arity: completion, default return acc
      (t (funcall rf acc input)))))

(defun transduce (xform f init coll)
  "Reduce over coll with xform applied to f."
  ;; rf = (funcall xform (completing f))
  (let* ((rf (funcall xform (if (functionp f)
                                (completing f)
                                (completing (lambda (a b) (funcall f a b))))))
         (acc init)
         (iter (fol.compiler.collections:collection-seq coll)))
    (loop for x in iter
          do (let ((res (funcall rf acc x)))
               (if (reduced? res)
                   (return (unreduced res))
                   (setf acc res)))
          finally (return (funcall rf acc)))))

;;; ===========================================================================
;;; Eduction
;;; ===========================================================================

(defclass eduction (fol.compiler.collections:<collection>)
  ((xform :initarg :xform :reader eduction-xform)
   (coll :initarg :coll :reader eduction-coll)))

(defmethod fol.compiler.collections:collection-seq ((e eduction))
  (let ((v (transduce (eduction-xform e) #'fol.compiler.collection-functions:conj (fol.compiler.collection-functions:vector) (eduction-coll e))))
    (fol.compiler.collections:collection-seq v)))

(defun eduction (xform coll)
  (make-instance 'eduction :xform xform :coll coll))

(defmethod fol.compiler.collections:collection-size ((e eduction))
  (length (fol.compiler.collections:collection-seq e)))

;;; ===========================================================================
;;; Sequence
;;; ===========================================================================

(defun sequence (xform coll)
  "Returns a lazy sequence of the application of xform to coll.
   Note: Current implementation utilizes a lazy-seq that realizes eagerly upon access."
  (make-instance 'fol.compiler.collections:<lazy-seq>
    :thunk (lambda ()
             (transduce xform #'fol.compiler.collection-functions:conj (fol.compiler.collection-functions:vector) coll))))

;;; ===========================================================================
;;; Into
;;; ===========================================================================

(defun into (to xform &optional from)
  "Returns a new collection consisting of to with all of the items of from
   conjoined. If xform is supplied, from is transduced."
  (if from
      (transduce xform #'fol.compiler.collection-functions:conj to from)
      ;; 2-arity: (into to from) -> reduce conj over from (which is xform arg)
      (let ((iter (fol.compiler.collections:collection-seq xform)) ;; xform is the source
            (acc to))
        (dolist (item iter)
          (setf acc (fol.compiler.collection-functions:conj acc item)))
        acc)))
