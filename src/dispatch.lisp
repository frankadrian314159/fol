;;;; FOL Dispatch Caching - Polymorphic Inline Cache for Multi-Clause Functions
;;;;
;;;; Implements hash-table caching keyed by (class-of arg0 class-of arg1 ...)
;;;; for fast dispatch of multi-clause defn/defmethod/fn with type or value predicates.

(in-package #:fol.compiler.dispatch)

;;; Cache Data Structure

(defstruct (dispatch-cache (:constructor make-dispatch-cache ()) (:copier nil))
  "Hash-table cache for polymorphic inline caching.
   table: hash table (key → function) where key is a list of class objects.
           synchronized for thread-safe concurrent access.
   generation: incremented on flush, used to invalidate outer scopes.
   hits: count of cache lookups that found an entry (atomic updates).
   misses: count of cache lookups that missed (atomic updates)."
  (table      (make-hash-table :test 'equal :synchronized t) :type hash-table)
  (generation 0 :type (unsigned-byte 64))
  (hits       0 :type (unsigned-byte 64))
  (misses     0 :type (unsigned-byte 64)))

;;; Cache Operations

(defun cache-lookup (cache key)
  "Lookup KEY in the cache and return the cached function, or NIL if not found.
   KEY should be comparable by EQUAL (list of classes or mixed atoms).
   Atomically increments hits/misses counters for cache statistics."
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (let ((hit (gethash key (dispatch-cache-table cache))))
    (if hit
        (progn (sb-ext:atomic-incf (dispatch-cache-hits cache)) hit)
        (progn (sb-ext:atomic-incf (dispatch-cache-misses cache)) nil))))

(defun cache-insert! (cache key fn)
  "Insert KEY → FN into the cache."
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (setf (gethash key (dispatch-cache-table cache)) fn))

(defun cache-flush! (cache)
  "Clear all cached entries and bump the generation counter.
   Also resets hit/miss counters to zero.

   Note: clrhash is not atomic with concurrent cache-lookup calls in other threads.
   A lookup racing with clrhash may miss the cache (harmless; falls through to COND).
   Correctness is preserved: individual gethash operations are atomic per-entry,
   and generation increments are atomic, preventing stale-entry re-entries."
  (declare (type dispatch-cache cache))
  (clrhash (dispatch-cache-table cache))
  (setf (dispatch-cache-hits cache) 0
        (dispatch-cache-misses cache) 0)
  (sb-ext:atomic-incf (dispatch-cache-generation cache)))

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

;;; Cache Statistics and Observability

(defun cache-stats (cache)
  "Return (values hits misses generation table-size) for a dispatch-cache.
   Useful for profiling and validating cache behavior."
  (declare (type dispatch-cache cache))
  (values (dispatch-cache-hits cache)
          (dispatch-cache-misses cache)
          (dispatch-cache-generation cache)
          (hash-table-count (dispatch-cache-table cache))))

(defun inspect-fn-cache (fn-name)
  "Return (values hits misses generation table-size) for FN-NAME's dispatch cache.
   Returns NIL if FN-NAME is not a cached function.

   FN-NAME must be the exact symbol used in the defn/fn form (case-sensitive).
   Example: (inspect-fn-cache 'my-type-dispatch-fn)"
  (declare (type symbol fn-name))
  (let* ((pkg (or (symbol-package fn-name) *package*))
         (cache-sym (intern (format nil "%-~A-DISPATCH-CACHE" (symbol-name fn-name)) pkg)))
    (when (boundp cache-sym)
      (cache-stats (symbol-value cache-sym)))))

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
