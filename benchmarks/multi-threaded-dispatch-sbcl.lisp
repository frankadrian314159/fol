;;;; Multi-threaded dispatch caching benchmark for SBCL
;;;; Tests how lock contention affects dispatch cache performance
;;;;
;;;; Usage: sbcl --non-interactive --load multi-threaded-dispatch-sbcl.lisp

(ql:quickload '(:bordeaux-threads) :silent t)

(deftype test-type () '(member :int :string :list :other))

(defun make-test-type (n) (aref #(:int :string :list :other) (mod n 4)))

(defvar *call-count* 100000)
(defvar *cache* (make-hash-table :test 'equal))
(defvar *cache-lock* (bt:make-lock))

;;; Dispatch functions (minimal work)
(defun dispatch-int (x) (values :int (mod x 256)))
(defun dispatch-string (s) (values :string (length s)))
(defun dispatch-list (lst) (values :list (length lst)))
(defun dispatch-other () (values :other 0))

;;; Uncached dispatch
(defun dispatch-uncached (typ)
  (case typ
    (:int (dispatch-int 42))
    (:string (dispatch-string "test"))
    (:list (dispatch-list '(1 2 3)))
    (:other (dispatch-other))))

;;; Cached dispatch with lock
(defun dispatch-cached (typ)
  (bt:with-lock-held (*cache-lock*)
    (multiple-value-bind (cached-fn hit-p) (gethash typ *cache*)
      (if hit-p
          (funcall cached-fn)
          (let ((fn (case typ
                      (:int (lambda () (dispatch-int 42)))
                      (:string (lambda () (dispatch-string "test")))
                      (:list (lambda () (dispatch-list '(1 2 3))))
                      (:other #'dispatch-other))))
            (setf (gethash typ *cache*) fn)
            (funcall fn))))))

;;; Worker thread
(defun worker-thread (uncached-p)
  (let ((fn (if uncached-p #'dispatch-uncached #'dispatch-cached)))
    (dotimes (i *call-count*)
      (funcall fn (make-test-type i)))))

;;; Benchmark runner
(defun run-benchmark (num-threads uncached-p)
  (clrhash *cache*)
  (let ((threads nil)
        (start (get-internal-real-time)))
    (dotimes (i num-threads)
      (push (bt:make-thread (lambda () (worker-thread uncached-p))) threads))
    (dolist (th threads)
      (bt:join-thread th))
    (/ (* (- (get-internal-real-time) start) 1000.0) internal-time-units-per-second)))

;;; Main benchmark
(format t "================================~%")
(format t "SBCL Multi-Threaded Dispatch Caching~%")
(format t "================================~%~%")
(format t "Test parameters:~%")
(format t "  Calls per thread: ~:D~%" *call-count*)
(format t "  Thread counts: 1, 2, 4, 8~%")
(format t "  Workload: 4-type repeating cycle~%~%")

;; Warmup
(format t "Warming up...~%")
(dotimes (i 2)
  (run-benchmark 2 nil)
  (run-benchmark 2 t))
(format t "Warmup complete.~%~%")

;; Uncached
(format t "=== Uncached Dispatch ===~%")
(let ((uncached-times '()))
  (dolist (nt '(1 2 4 8))
    (let ((time (run-benchmark nt t)))
      (push (cons nt time) uncached-times)
      (format t "  ~D thread~:P: ~7,2F ms (~7,2F µs/call/thread)~%"
              nt time (/ time *call-count* nt 1000.0))))

  ;; Cached
  (format t "~%=== Cached Dispatch ===~%")
  (let ((cached-times '()))
    (dolist (nt '(1 2 4 8))
      (let ((time (run-benchmark nt nil)))
        (push (cons nt time) cached-times)
        (format t "  ~D thread~:P: ~7,2F ms (~7,2F µs/call/thread)~%"
                nt time (/ time *call-count* nt 1000.0))))

    ;; Summary
    (format t "~%=== Slowdown Scaling ===~%")
    (dolist (nt '(1 2 4 8))
      (let ((ratio (/ (cdr (assoc nt cached-times)) (cdr (assoc nt uncached-times)))))
        (format t "  ~D thread~:P: ~5,2Fx slowdown~%" nt ratio)))))

(format t "~%================================~%")
(quit)
