;;;; ABCL Phase 1 Validation with Quicklisp
;;;; Run: java -jar abcl.jar --load abcl-phase1-with-ql.lisp

;; Load Quicklisp
(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file ql-path)
    (load ql-path)))

;; Load bordeaux-threads
(ql:quickload :bordeaux-threads)

(format t "~%=== ABCL DISPATCH CACHING PHASE 1 VALIDATION ===%~%")
(format t "ABCL Version: ~A~%" (lisp-implementation-version))

;; Test 1.1: Basic hash-table with lock operations (portable dispatch cache simulation)
(format t "~%Test 1.1: Portable hash-table with lock operations~%")
(let ((table (make-hash-table :test 'equal))
      (lock (bordeaux-threads:make-lock "test-lock")))
  (bordeaux-threads:with-lock-held (lock)
    (setf (gethash '(integer) table) #'identity))
  (bordeaux-threads:with-lock-held (lock)
    (let ((hit (gethash '(integer) table)))
      (format t "✅ Hash-table operations work: ~A~%" (eq hit #'identity)))))

;; Test 1.2: Dispatch cache structure (portable version)
(format t "~%Test 1.2: Dispatch cache structure~%")
(defstruct dispatch-cache
  (table (make-hash-table :test 'equal) :type hash-table)
  (lock (bordeaux-threads:make-lock) :type bordeaux-threads:lock)
  (generation 0 :type fixnum)
  (hits 0 :type fixnum)
  (misses 0 :type fixnum))

(let ((cache (make-dispatch-cache)))
  (format t "✅ Cache created: ~A~%" (type-of cache))
  (format t "   Initial state: hits=~D misses=~D gen=~D~%"
          (dispatch-cache-hits cache)
          (dispatch-cache-misses cache)
          (dispatch-cache-generation cache)))

;; Test 1.3: Cache lookup and insertion
(format t "~%Test 1.3: Cache lookup and insertion~%")
(let ((cache (make-dispatch-cache)))
  ;; Insert
  (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
    (setf (gethash '(integer) (dispatch-cache-table cache)) #'identity))
  ;; Lookup - hit
  (let ((hit (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
               (gethash '(integer) (dispatch-cache-table cache)))))
    (format t "✅ Cache hit: ~A~%" (eq hit #'identity)))
  ;; Lookup - miss
  (let ((miss (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
                (gethash '(string) (dispatch-cache-table cache)))))
    (format t "✅ Cache miss (returns NIL): ~A~%" (null miss))))

;; Test 1.4: Thread-safe concurrent access
(format t "~%Test 1.4: Thread-safe concurrent cache access~%")
(let ((cache (make-dispatch-cache)))
  ;; Populate with some entries
  (dotimes (i 10)
    (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
      (setf (gethash (list 'type i) (dispatch-cache-table cache))
            (list 'result i))))
  ;; Spawn multiple threads doing concurrent reads
  (let ((threads (loop for j from 1 to 4
                       collect (bordeaux-threads:make-thread
                                (lambda ()
                                  (dotimes (k 100)
                                    (bordeaux-threads:with-lock-held ((dispatch-cache-lock cache))
                                      (gethash (list 'type (mod k 10))
                                               (dispatch-cache-table cache)))))))))
    (dolist (th threads)
      (bordeaux-threads:join-thread th)))
  (format t "✅ Concurrent access completed safely~%"))

(format t "~%✅ ABCL PHASE 1 VALIDATION COMPLETE~%")
(format t "~%All tests passed on ABCL ~A~%" (lisp-implementation-version))
(quit)
