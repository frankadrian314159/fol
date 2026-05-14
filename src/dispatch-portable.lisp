;;;; FOL Dispatch Caching - Polymorphic Inline Cache (Portable Version)
;;;;
;;;; Portable implementation using bordeaux-threads for lock-protected cache.
;;;; Works on SBCL, Clozure CL, and other Common Lisp implementations.
;;;;
;;;; Implements hash-table caching keyed by (class-of arg0 class-of arg1 ...)
;;;; for fast dispatch of multi-clause defn/defmethod/fn with type or value predicates.

(in-package #:fol.compiler.dispatch)

;;; Cache Data Structure (Portable)

(defstruct (dispatch-cache (:constructor make-dispatch-cache ()) (:copier nil))
  "Hash-table cache for polymorphic inline caching (portable version).

   FIELDS:
   - table: hash table (key → function) where key is a list of class objects.
           NOT synchronized; synchronization via explicit lock.
   - lock: bordeaux-threads lock for concurrent access protection.
   - generation: incremented on flush, used to invalidate outer scopes.
   - hits: count of cache lookups that found an entry.
   - misses: count of cache lookups that missed.

   THREAD SAFETY:
   All cache operations (lookup, insert, flush) are protected by the lock.
   Statistics (hits, misses) are incremented atomically within locked sections."

  (table      (make-hash-table :test 'equal) :type hash-table)
  (lock       (bordeaux-threads:make-lock "dispatch-cache") :type bordeaux-threads:lock)
  (generation 0 :type (unsigned-byte 64))
  (hits       0 :type (unsigned-byte 64))
  (misses     0 :type (unsigned-byte 64)))

;;; Cache Operations (Portable)

(defun cache-lookup (cache key)
  "Lookup KEY in the cache and return the cached function, or NIL if not found.
   KEY should be comparable by EQUAL (list of classes or mixed atoms).
   Thread-safe: atomically increments hits/misses counters via lock.

   Args:
     cache: dispatch-cache struct
     key: list of class objects or mixed atoms

   Returns:
     cached function (if key found) or NIL (if key not found)"
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (let ((hit (gethash key (dispatch-cache-table cache))))
      (if hit
          (progn (incf (dispatch-cache-hits cache)) hit)
          (progn (incf (dispatch-cache-misses cache)) nil)))))

(defun cache-insert! (cache key fn)
  "Insert KEY → FN into the cache (thread-safe).

   Args:
     cache: dispatch-cache struct
     key: list of class objects or mixed atoms
     fn: function to cache"
  (declare (type dispatch-cache cache) (optimize (speed 3) (safety 0)))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (setf (gethash key (dispatch-cache-table cache)) fn)))

(defun cache-flush! (cache)
  "Clear all cached entries and bump the generation counter (thread-safe).
   Also resets hit/miss counters to zero.

   Args:
     cache: dispatch-cache struct

   Note: All operations within lock ensure consistency. No concurrent lookups
   can see partially-flushed state."
  (declare (type dispatch-cache cache))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (clrhash (dispatch-cache-table cache))
    (setf (dispatch-cache-hits cache) 0
          (dispatch-cache-misses cache) 0)
    (incf (dispatch-cache-generation cache))))

;;; Generic Function Cache Registry and Invalidation

(defvar *gf-cache-registry* (make-hash-table :test 'equal)
  "Maps generic-function-name (symbol) to list of dispatch-cache objects
   owned by that GF, for coordinated cache flushing on method changes.")

(defun register-gf-cache! (gf-name cache)
  "Register a dispatch cache as owned by generic function GF-NAME.

   Args:
     gf-name: symbol naming a generic function
     cache: dispatch-cache struct"
  (declare (type symbol gf-name) (type dispatch-cache cache))
  (push cache (gethash gf-name *gf-cache-registry* nil)))

(defun flush-gf-caches! (gf-name)
  "Flush all caches for the given generic function name.

   Args:
     gf-name: symbol naming a generic function"
  (declare (type symbol gf-name))
  (dolist (cache (gethash gf-name *gf-cache-registry* nil))
    (cache-flush! cache)))

(defun flush-all-caches! ()
  "Flush all caches in the registry (conservative invalidation).
   Used when method definitions change or class hierarchy changes."
  (maphash (lambda (k caches)
             (declare (ignore k))
             (dolist (c caches) (cache-flush! c)))
           *gf-cache-registry*))

;;; Value-Based Cache Keys

(defun pred-key (x)
  "Return a cache-key atom for X for use in value-predicate caching.
   EQL-comparable values (fixnum, character, symbol) return themselves.
   Reference types return (class-of x) for class-based grouping.

   Args:
     x: any value

   Returns:
     EQL-comparable cache key (fixnum, character, symbol, or class object)"
  (declare (optimize (speed 3) (safety 0)))
  (typecase x
    (fixnum    x)
    (character x)
    (symbol    x)
    (t         (cl:class-of x))))

;;; Cache Statistics and Observability

(defun cache-stats (cache)
  "Return statistics for a dispatch-cache.

   Args:
     cache: dispatch-cache struct

   Returns:
     (values hits misses generation table-size)

   Useful for profiling and validating cache behavior."
  (declare (type dispatch-cache cache))
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (values (dispatch-cache-hits cache)
            (dispatch-cache-misses cache)
            (dispatch-cache-generation cache)
            (hash-table-count (dispatch-cache-table cache)))))

(defun inspect-fn-cache (fn-name)
  "Return cache statistics for FN-NAME's dispatch cache.

   Args:
     fn-name: symbol naming a cached function

   Returns:
     (values hits misses generation table-size) or NIL if not cached

   Example:
     (inspect-fn-cache 'my-type-dispatch-fn)
     → 3574 673 1 8  ;; 3574 hits, 673 misses, generation 1, 8 cache entries"
  (declare (type symbol fn-name))
  (let* ((pkg (or (symbol-package fn-name) *package*))
         (cache-sym (intern (format nil "%-~A-DISPATCH-CACHE" (symbol-name fn-name)) pkg)))
    (when (boundp cache-sym)
      (cache-stats (symbol-value cache-sym)))))

;;; MOP Hooks for Automatic Cache Invalidation

;; INVALIDATION STRATEGY: Conservative (flush-all-caches!) is the DEFAULT
;;
;; Rationale: When a method is added/removed, we conservatively flush ALL caches
;; (not just the affected GF's caches) because a defn compiled earlier might
;; reference the GF via a predicate or guard clause. Example:
;;
;;   (defn check-value [x]         ; compiled and cached
;;     (if (valid-for-v1? x) :valid :invalid))
;;   (later...)
;;   (defmethod valid-for-v1? ((x custom-type)) t)  ; method added
;;   (check-value (make-custom-type))  ; returns :invalid (stale cache!)
;;
;; Without conservative flush, the defn's cache would hold stale dispatch results
;; until the defn is explicitly redefined. This is a silent correctness hazard.
;;
;; Trade-off: Conservative flush is safe but may invalidate unrelated caches.
;; For performance-critical code, use (flush-gf-caches! 'specific-gf) manually
;; after targeted method changes, or restructure to avoid cross-GF dependencies.

(defvar *aggressive-cache-invalidation* nil
  "If T, use fine-grained invalidation (flush only the affected GF's caches).
   If NIL (default), use conservative invalidation (flush all caches).

   Set to T only if you understand the closure-capture limitation and have
   verified that your code does not reference external GFs in predicates/guards.")

(defmethod cl:add-method :after ((gf cl:standard-generic-function) method)
  (declare (ignore method))
  (if *aggressive-cache-invalidation*
      ;; Fine-grained: flush only this GF's caches
      (flush-gf-caches! (closer-mop:generic-function-name gf))
      ;; Conservative (default): flush everything for correctness
      (flush-all-caches!)))

(defmethod cl:remove-method :after ((gf cl:standard-generic-function) method)
  (declare (ignore method))
  (if *aggressive-cache-invalidation*
      (flush-gf-caches! (closer-mop:generic-function-name gf))
      (flush-all-caches!)))

;; Flush all on class hierarchy change (conservative): affects type hierarchy used in type dispatch
(defmethod closer-mop:finalize-inheritance :after ((class cl:standard-class))
  (flush-all-caches!))

;;; EOF dispatch-portable.lisp
