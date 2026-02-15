;;; Test thread pool-based pmap and pmapcat

(push (truename ".") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :cl-user)

(format t "~%=== Testing Thread Pool-Based pmap and pmapcat ===~%~%")

;; Test 1: Basic pmap
(format t "Test 1: Basic pmap with simple function~%")
(let* ((input (fol.compiler.collection-functions:vector 1 2 3 4 5))
       (result (fol.compiler.seq-functions:pmap
                (lambda (x) (* x 2))
                input)))
  (format t "  Input:  ~A~%" input)
  (format t "  Result: ~A~%" result)
  (assert (equal (fol.compiler.collections:collection-seq result)
                 '(2 4 6 8 10))
          ()
          "pmap result mismatch"))

;; Test 2: pmap with multiple collections
(format t "~%Test 2: pmap with multiple collections~%")
(let* ((input1 (fol.compiler.collection-functions:vector 1 2 3))
       (input2 (fol.compiler.collection-functions:vector 10 20 30))
       (result (fol.compiler.seq-functions:pmap
                (lambda (x y) (+ x y))
                input1
                input2)))
  (format t "  Input1: ~A~%" input1)
  (format t "  Input2: ~A~%" input2)
  (format t "  Result: ~A~%" result)
  (assert (equal (fol.compiler.collections:collection-seq result)
                 '(11 22 33))
          ()
          "pmap multi-coll result mismatch"))

;; Test 3: pmapcat
(format t "~%Test 3: pmapcat~%")
(let* ((input (fol.compiler.collection-functions:vector 1 2 3))
       (result (fol.compiler.seq-functions:pmapcat
                (lambda (x)
                  (fol.compiler.collection-functions:vector x (* x 2)))
                input)))
  (format t "  Input:  ~A~%" input)
  (format t "  Result: ~A~%" result)
  (assert (equal (fol.compiler.collections:collection-seq result)
                 '(1 2 2 4 3 6))
          ()
          "pmapcat result mismatch"))

;; Test 4: pmap with expensive operation (verify parallelism)
(format t "~%Test 4: pmap with sleep to verify parallelism~%")
(let* ((input (fol.compiler.collection-functions:vector 1 2 3 4))
       (start-time (get-internal-real-time))
       (result (fol.compiler.seq-functions:pmap
                (lambda (x)
                  (sleep 0.1)  ; 100ms sleep
                  (* x 2))
                input))
       (end-time (get-internal-real-time))
       (elapsed (/ (- end-time start-time) internal-time-units-per-second)))
  (format t "  Elapsed time: ~,3F seconds~%" elapsed)
  (format t "  Result: ~A~%" result)
  ;; Should take ~100ms with parallelism, not 400ms sequential
  (assert (< elapsed 0.25)
          ()
          "pmap doesn't appear to be running in parallel (took ~A seconds)" elapsed)
  (assert (equal (fol.compiler.collections:collection-seq result)
                 '(2 4 6 8))
          ()
          "pmap result mismatch"))

;; Test 5: Thread pool reuse
(format t "~%Test 5: Verify thread pool is reused~%")
(let ((initial-threads fol.compiler.seq-functions::*worker-threads*))
  (fol.compiler.seq-functions:pmap #'identity
                                    (fol.compiler.collection-functions:vector 1 2 3))
  (assert (eq initial-threads fol.compiler.seq-functions::*worker-threads*)
          ()
          "Thread pool was recreated instead of reused"))

(format t "~%=== All thread pool tests passed! ===~%")
(sb-ext:quit)
