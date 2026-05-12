;;;; FOL Dispatch Caching - Polymorphic Inline Cache for Multi-Clause Functions
;;;;
;;;; Implements an 8-slot ring-buffer cache keyed by (class-of arg0 class-of arg1 ...)
;;;; for fast dispatch of multi-clause defn/defmethod/fn with type or value predicates.

(in-package #:fol.compiler.dispatch)

;;; Cache Constants and Data Structure

(defconstant +cache-size+ 8
  "Size of the ring buffer cache (number of slots).")

(defstruct (dispatch-cache (:constructor make-dispatch-cache ()) (:copier nil))
  "Ring-buffer cache for polymorphic inline caching.
   entries: vector of (key . fn) cons cells or nil
   next: current insertion point in ring
   generation: incremented on flush, used to invalidate outer scopes"
  (entries    (make-array +cache-size+ :initial-element nil) :type simple-vector)
  (next       0 :type fixnum)
  (generation 0 :type fixnum))

;;; Cache Operations

(defun cache-lookup (cache key)
  "Search the cache for KEY and return the cached function, or NIL if not found.
   KEY should be a list of class objects (from (class-of arg) for each arg)."
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (loop for entry across (dispatch-cache-entries cache)
        when (and entry (every #'eq (car entry) key))
          return (cdr entry)))

(defun cache-insert! (cache key fn)
  "Insert (KEY . FN) into the ring buffer, evicting the oldest entry if needed."
  (declare (type dispatch-cache cache) (type cons key) (optimize (speed 3) (safety 0)))
  (let ((pos (dispatch-cache-next cache))
        (entries (dispatch-cache-entries cache)))
    (setf (aref entries pos) (cons key fn))
    (setf (dispatch-cache-next cache) (mod (1+ pos) +cache-size+))))

(defun cache-flush! (cache)
  "Clear all cached entries and bump the generation counter."
  (declare (type dispatch-cache cache))
  (fill (dispatch-cache-entries cache) nil)
  (setf (dispatch-cache-next cache) 0)
  (incf (dispatch-cache-generation cache)))

;;; Generic Function Cache Registry and Invalidation

(defvar *gf-cache-registry* (make-hash-table :test 'equal)
  "Maps generic-function-name (symbol) to list of dispatch-cache objects
   owned by that GF, for coordinated cache flushing on method changes.")

(defun register-gf-cache! (gf-name cache)
  "Register a dispatch cache as owned by generic function GF-NAME."
  (declare (type symbol gf-name) (type dispatch-cache cache))
  (push cache (gethash gf-name *gf-cache-registry* nil)))

(defun flush-gf-caches! (gf-name)
  "Flush all caches for the given generic function name."
  (declare (type symbol gf-name))
  (dolist (cache (gethash gf-name *gf-cache-registry* nil))
    (cache-flush! cache)))

(defun flush-all-caches! ()
  "Flush all caches in the registry (conservative invalidation)."
  (maphash (lambda (k caches)
             (declare (ignore k))
             (dolist (c caches) (cache-flush! c)))
           *gf-cache-registry*))

;;; Value-Based Cache Keys

(defun pred-key (x)
  "Return a cache-key atom for X for use in value-predicate caching.
   EQL-comparable values (fixnum, character, symbol) return themselves.
   Reference types return (class-of x) for class-based grouping."
  (declare (optimize (speed 3) (safety 0)))
  (typecase x
    (fixnum    x)
    (character x)
    (symbol    x)
    (t         (cl:class-of x))))

;;; MOP Hooks for Automatic Cache Invalidation

;; Flush on method add: all cached methods for that GF are stale
(defmethod cl:add-method :after ((gf cl:standard-generic-function) method)
  (declare (ignore method))
  (flush-gf-caches! (closer-mop:generic-function-name gf)))

;; Flush on method remove: all cached methods for that GF are stale
(defmethod cl:remove-method :after ((gf cl:standard-generic-function) method)
  (declare (ignore method))
  (flush-gf-caches! (closer-mop:generic-function-name gf)))

;; Flush all on class hierarchy change (conservative): affects type hierarchy used in type dispatch
(defmethod closer-mop:finalize-inheritance :after ((class cl:standard-class))
  (flush-all-caches!))
