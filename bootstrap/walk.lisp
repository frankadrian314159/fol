(in-package :fol.walk)

;;; ============================================================================
;;; FOL Walk - Tree Traversal and Transformation
;;; ============================================================================
;;;
;;; This module provides functions for walking and transforming tree structures
;;; (nested collections). Based on Clojure's clojure.walk namespace.

(defun %call-fn (fn &rest args)
  "Call FN with ARGS, handling both CL functions and FOL <FUNCTION> objects."
  (etypecase fn
    (function (apply fn args))
    (symbol (apply fn args))
    (fol.eval:<function> (fol.eval:apply-function fn args))))

(defun %walk-collection (form inner make-fn)
  "Helper to walk a collection with inner function and rebuild with make-fn."
  (let ((result '())
        (iter (fol.collection:iterator form)))
    (loop until (fol.collection:done? iter)
          do (push (%call-fn inner (fol.collection:current iter)) result)
             (fol.collection:next iter))
    (apply make-fn (nreverse result))))

(defun %walk-set (form inner make-fn)
  "Helper to walk a set with inner function and rebuild with make-fn.
   Set iterators return (value . T) cons cells, so we extract the car."
  (let ((result '())
        (iter (fol.collection:iterator form)))
    (loop until (fol.collection:done? iter)
          do (let ((entry (fol.collection:current iter)))
               ;; Extract value from (value . T) cons cell
               (push (%call-fn inner (car entry)) result))
             (fol.collection:next iter))
    (apply make-fn (nreverse result))))

(defun walk (inner outer form)
  "Walk a data structure, applying inner to each element, then outer to the result.
   The inner function is applied to each element of the form, and outer is applied
   to the result. This is the fundamental building block for all other walk functions."
  (cond
    ;; Lists - walk each element with inner, then apply outer
    ((fol.collection:<list>? form)
     (%call-fn outer (%walk-collection form inner #'fol.collection:make-list)))

    ;; Vectors - walk each element with inner, then apply outer
    ((fol.collection:<vector>? form)
     (%call-fn outer (%walk-collection form inner #'fol.collection:make-vector)))

    ;; Dicts - walk each key-value pair with inner, then apply outer
    ((fol.collection:<dict>? form)
     (let ((pairs '())
           (iter (fol.collection:iterator form)))
       (loop until (fol.collection:done? iter)
             do (let* ((entry (fol.collection:current iter))
                       (k (car entry))
                       (v (cdr entry))
                       (new-entry (%call-fn inner (fol.collection:make-vector k v))))
                  (push (fol.seqop:first new-entry) pairs)
                  (push (fol.collection:second new-entry) pairs))
                (fol.collection:next iter))
       (%call-fn outer (apply #'fol.collection:make-dict (nreverse pairs)))))

    ;; Sets - walk each element with inner, then apply outer
    ((fol.collection:<set>? form)
     (%call-fn outer (%walk-set form inner #'fol.collection:make-set)))

    ;; Anything else - just apply outer
    (t (%call-fn outer form))))

(defun prewalk (f form)
  "Perform a depth-first, pre-order traversal of form. Calls f on each sub-form,
   then uses walk to do the same for its children."
  (walk (lambda (x) (prewalk f x))
        #'identity
        (%call-fn f form)))

(defun prewalk-demo (form)
  "Demonstrate the order of a depth-first pre-order walk by printing each form."
  (prewalk (lambda (x)
             (print x)
             x)
           form))

(defun prewalk-replace (smap form)
  "Replace values in form using the replacements in smap (a dict).
   Replacement happens in pre-order, so parent replacements affect children."
  (prewalk (lambda (x)
             (if (fol.seqop:contains? smap x)
                 (fol.seqop:get smap x)
                 x))
           form))

(defun postwalk (f form)
  "Perform a depth-first, post-order traversal of form. Walks the children first,
   then calls f on the result."
  (walk (lambda (x) (postwalk f x))
        f
        form))

(defun postwalk-demo (form)
  "Demonstrate the order of a depth-first post-order walk by printing each form."
  (postwalk (lambda (x)
              (print x)
              x)
            form))

(defun postwalk-replace (smap form)
  "Replace values in form using the replacements in smap (a dict).
   Replacement happens in post-order, so children are replaced before parents."
  (postwalk (lambda (x)
              (if (fol.seqop:contains? smap x)
                  (fol.seqop:get smap x)
                  x))
            form))
