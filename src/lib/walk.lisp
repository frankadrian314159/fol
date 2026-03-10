;;; FOL Walk - Tree Traversal and Transformation
;;;
;;; Provides functions for walking and transforming tree structures
;;; (nested FOL collections). Based on Clojure's clojure.walk namespace.

(defpackage fol.walk
  (:use cl)
  (:import-from fol.compiler.collections
                <collection> <vector> <dict> <set> <list>
                collection-seq storage-items make)
  (:shadowing-import-from fol.compiler.collections get)
  (:export
   walk prewalk postwalk
   prewalk-demo prewalk-replace
   postwalk-demo postwalk-replace))

(in-package :fol.walk)

;;; ---------------------------------------------------------------------------
;;; walk - Core tree traversal function
;;; ---------------------------------------------------------------------------

(defun walk (inner outer form)
  "Walk a data structure, applying INNER to each element, then OUTER to the result.

   For each collection type, INNER is applied to each element (or entry for
   dicts), and OUTER is applied to the rebuilt collection. Non-collection values
   are passed directly to OUTER.

   Examples:
     (walk #'1+ #'identity vec)  ; increment each element of a vector
     (walk #'identity #'reverse vec)  ; walk elements unchanged, reverse result"
  (cond
   ;; FOL <list>
   ((typep form '<list>)
     (funcall outer
       (apply #'make '<list>
         (mapcar inner (collection-seq form)))))

   ;; FOL <vector>
   ((typep form '<vector>)
     (funcall outer
       (fol.compiler.collection-functions::%make-vec
         (mapcar inner (collection-seq form)))))

   ;; FOL <dict> - entries are (key . value) pairs; wrap as 2-element vectors
   ((typep form '<dict>)
     (funcall outer
       (let* ((pairs (collection-seq form))
              (new-args
               (loop for pair in pairs
                     for entry = (make '<vector> (car pair) (cdr pair))
                     for walked = (funcall inner entry)
                     for walked-seq = (collection-seq walked)
                       append (cl:list (cl:first walked-seq)
                                (cl:second walked-seq)))))
         (apply #'make '<dict> new-args))))

   ;; FOL <set>
   ((typep form '<set>)
     (funcall outer
       (apply #'make '<set>
         (mapcar inner (collection-seq form)))))

   ;; Non-collection: just apply outer
   (t (funcall outer form))))

;;; ---------------------------------------------------------------------------
;;; prewalk - Pre-order traversal
;;; ---------------------------------------------------------------------------

(defun prewalk (f form)
  "Perform a depth-first, pre-order traversal of FORM. Calls F on each
   sub-form before walking into its children.

   Examples:
     (prewalk (lambda (x) (if (numberp x) (1+ x) x)) [1 [2 3] 4])
     ; => [2 [3 4] 5]"
  (walk (lambda (x) (prewalk f x))
        #'identity
        (funcall f form)))

;;; ---------------------------------------------------------------------------
;;; prewalk-demo - Demonstration of pre-order walk
;;; ---------------------------------------------------------------------------

(defun prewalk-demo (form)
  "Demonstrate the order of a depth-first pre-order walk by printing each form."
  (prewalk (lambda (x)
             (print x)
             x)
           form))

;;; ---------------------------------------------------------------------------
;;; prewalk-replace - Pre-order substitution via dict lookup
;;; ---------------------------------------------------------------------------

(defun prewalk-replace (smap form)
  "Replace values in FORM using the replacements in SMAP (a <dict>).
   Replacement happens in pre-order, so parent replacements affect children.

   Examples:
     (prewalk-replace {a 1 b 2} [a b [a b]])  ; => [1 2 [1 2]]"
  (prewalk (lambda (x)
             (multiple-value-bind (val found)
                 (get smap x)
               (if found val x)))
           form))

;;; ---------------------------------------------------------------------------
;;; postwalk - Post-order traversal
;;; ---------------------------------------------------------------------------

(defun postwalk (f form)
  "Perform a depth-first, post-order traversal of FORM. Walks the children
   first, then calls F on the result.

   Examples:
     (postwalk (lambda (x) (if (numberp x) (1+ x) x)) [1 [2 3] 4])
     ; => [2 [3 4] 5]"
  (walk (lambda (x) (postwalk f x))
        f
        form))

;;; ---------------------------------------------------------------------------
;;; postwalk-demo - Demonstration of post-order walk
;;; ---------------------------------------------------------------------------

(defun postwalk-demo (form)
  "Demonstrate the order of a depth-first post-order walk by printing each form."
  (postwalk (lambda (x)
              (print x)
              x)
            form))

;;; ---------------------------------------------------------------------------
;;; postwalk-replace - Post-order substitution via dict lookup
;;; ---------------------------------------------------------------------------

(defun postwalk-replace (smap form)
  "Replace values in FORM using the replacements in SMAP (a <dict>).
   Replacement happens in post-order, so children are replaced before parents.

   Examples:
     (postwalk-replace {a 1 b 2} [a b [a b]])  ; => [1 2 [1 2]]"
  (postwalk (lambda (x)
              (multiple-value-bind (val found)
                  (get smap x)
                (if found val x)))
            form))
