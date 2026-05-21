;;; Assembly-level dispatch comparison: COND vs Cached

(declaim (optimize (speed 3) (safety 0) (debug 1)))

;; ============================================================================
;; UNCACHED: Pure COND Dispatch
;; ============================================================================

(defun dispatch-uncached (x)
  "6-clause COND dispatcher - no caching"
  (declare (type fixnum x) (optimize (speed 3) (safety 0)))
  (cond
    ((< x -1000) (- (- x)))
    ((< x 0)     (- x))
    ((= x 0)     0)
    ((< x 1000)  (1+ x))
    ((< x 100000) (+ x 10))
    (t           (* x 2))))

;; ============================================================================
;; CACHED: Hash-table Cache + Funcall
;; ============================================================================

(defstruct (dispatch-cache (:constructor make-dispatch-cache ()) (:copier nil))
  (table (make-hash-table :test 'equal) :type hash-table))

(defun %-clause-0 (x) (declare (optimize (speed 3) (safety 0))) (- (- x)))
(defun %-clause-1 (x) (declare (optimize (speed 3) (safety 0))) (- x))
(defun %-clause-2 (x) (declare (optimize (speed 3) (safety 0))) 0)
(defun %-clause-3 (x) (declare (optimize (speed 3) (safety 0))) (1+ x))
(defun %-clause-4 (x) (declare (optimize (speed 3) (safety 0))) (+ x 10))
(defun %-clause-5 (x) (declare (optimize (speed 3) (safety 0))) (* x 2))

(defvar %-cache (make-dispatch-cache))

(defun dispatch-cached (x)
  "6-clause dispatcher WITH caching"
  (declare (type fixnum x) (optimize (speed 3) (safety 0)))
  (let* ((key (list (type-of x)))
         (hit (gethash key (dispatch-cache-table %-cache))))
    (if hit
        (funcall hit x)
        (cond
          ((< x -1000)
           (setf (gethash key (dispatch-cache-table %-cache)) #'%-clause-0)
           (%-clause-0 x))
          ((< x 0)
           (setf (gethash key (dispatch-cache-table %-cache)) #'%-clause-1)
           (%-clause-1 x))
          ((= x 0)
           (setf (gethash key (dispatch-cache-table %-cache)) #'%-clause-2)
           (%-clause-2 x))
          ((< x 1000)
           (setf (gethash key (dispatch-cache-table %-cache)) #'%-clause-3)
           (%-clause-3 x))
          ((< x 100000)
           (setf (gethash key (dispatch-cache-table %-cache)) #'%-clause-4)
           (%-clause-4 x))
          (t
           (setf (gethash key (dispatch-cache-table %-cache)) #'%-clause-5)
           (%-clause-5 x))))))

;; ============================================================================
;; Disassembly and Analysis
;; ============================================================================

(format t "~&==================================================~%")
(format t "ASSEMBLY-LEVEL DISPATCH COMPARISON~%")
(format t "==================================================~%~%")

(format t "UNCACHED DISPATCH (COND-based):~%")
(format t "--------------------------------------------------~%")
(disassemble 'dispatch-uncached)

(format t "~%~%CACHED DISPATCH (Hash-table + Funcall):~%")
(format t "--------------------------------------------------~%")
(disassemble 'dispatch-cached)

(format t "~%~%KEY OBSERVATIONS:~%")
(format t "--------------------------------------------------~%")
(format t "1. UNCACHED should show tight sequence of branch instructions~%")
(format t "   - CMP/JL/JEQ instructions for type tests~%")
(format t "   - Direct arithmetic for clauses~%")
(format t "   - Minimal stack usage~%~%")

(format t "2. CACHED should show:~%")
(format t "   - LIST construction (allocation)~%")
(format t "   - GETHASH call (function call overhead)~%")
(format t "   - Conditional branch on cache hit~%")
(format t "   - FUNCALL on hit (indirect call)~%")
(format t "   - Full COND on miss (same as uncached)~%~%")

(format t "3. Code size difference illustrates the overhead~%")
(format t "   - Cached version should be significantly larger~%")

(format t "~%~%CONTROL FLOW:~%")
(format t "--------------------------------------------------~%")
(format t "Uncached: x -> CMP -> branch to clause -> return~%")
(format t "Cached:   x -> LIST -> GETHASH -> branch -> FUNCALL/COND -> return~%~%")

(sb-ext:quit :unix-status 0)
