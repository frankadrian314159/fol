(in-package :cl-user)

(defpackage :fol.benchmarks.map
  (:use :cl)
  (:export :run-map-benchmarks))

(in-package :fol.benchmarks.map)

(defun run-map-benchmarks ()
  (format t "~&Map Microbenchmarks (Size: 65, Iterations: 1M)~%")
  (format t "=========================================================~%")

  (let ((n 1000000)
        (cl-map (make-hash-table :test 'equal))
        (fol-map (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))

    ;; Populate initially
    (dotimes (i 65)
      (let ((k (format nil "key-~D" i))
            (v i))
        (setf (gethash k cl-map) v)
        (setf fol-map (fol.compiler.collections:collection-assoc fol-map k v))))

    (let* ((new-key "key-66")
           (new-val 66))

      (format t "~&Add Key-Value Pair:~%")
      (let ((t1 (get-internal-real-time))
            (b1 (fol.benchmarks::get-bytes-consed)))
        (dotimes (i n)
          (setf (gethash new-key cl-map) new-val))
        (let ((t2 (get-internal-real-time))
              (b2 (fol.benchmarks::get-bytes-consed)))
          (format t "  Common Lisp (SETF GETHASH) - In place: ~,4F seconds, ~,2F MB~%"
            (/ (- t2 t1) internal-time-units-per-second)
            (/ (- b2 b1) 1024.0 1024.0))))

      (let ((t1 (get-internal-real-time))
            (b1 (fol.benchmarks::get-bytes-consed)))
        (dotimes (i n)
          (fol.compiler.collections:collection-assoc fol-map new-key new-val))
        (let ((t2 (get-internal-real-time))
              (b2 (fol.benchmarks::get-bytes-consed)))
          (format t "  FOL (COLLECTION-ASSOC) - Persistent  : ~,4F seconds, ~,2F MB~%"
            (/ (- t2 t1) internal-time-units-per-second)
            (/ (- b2 b1) 1024.0 1024.0))))

      ;; Create the resulting map for removal test
      (setf (gethash new-key cl-map) new-val)
      (let ((fol-map-with-key (fol.compiler.collections:collection-assoc fol-map new-key new-val)))

        (format t "~&Remove Key-Value Pair:~%")
        (let ((t1 (get-internal-real-time))
              (b1 (fol.benchmarks::get-bytes-consed)))
          (dotimes (i n)
            ;; Re-add so remhash actually has something to remove and modify buckets.
            ;; Not doing this would just profile 1M missing key lookups!
            (setf (gethash new-key cl-map) new-val)
            (remhash new-key cl-map))
          (let ((t2 (get-internal-real-time))
                (b2 (fol.benchmarks::get-bytes-consed)))
            (format t "  Common Lisp (REMHASH) - In place     : ~,4F seconds, ~,2F MB~%"
              (/ (- t2 t1) internal-time-units-per-second)
              (/ (- b2 b1) 1024.0 1024.0))))

        (let ((t1 (get-internal-real-time))
              (b1 (fol.benchmarks::get-bytes-consed)))
          (dotimes (i n)
            (fol.compiler.collections:collection-dissoc fol-map-with-key new-key))
          (let ((t2 (get-internal-real-time))
                (b2 (fol.benchmarks::get-bytes-consed)))
            (format t "  FOL (COLLECTION-DISSOC) - Persistent : ~,4F seconds, ~,2F MB~%"
              (/ (- t2 t1) internal-time-units-per-second)
              (/ (- b2 b1) 1024.0 1024.0))))

        (format t "~&Lookup Existing Element:~%")
        (let ((t1 (get-internal-real-time))
              (b1 (fol.benchmarks::get-bytes-consed))
              (lkey "key-3"))
          (dotimes (i n)
            (gethash lkey cl-map))
          (let ((t2 (get-internal-real-time))
                (b2 (fol.benchmarks::get-bytes-consed)))
            (format t "  Common Lisp (GETHASH) - Native       : ~,4F seconds, ~,2F MB~%"
              (/ (- t2 t1) internal-time-units-per-second)
              (/ (- b2 b1) 1024.0 1024.0))))

        (let ((t1 (get-internal-real-time))
              (b1 (fol.benchmarks::get-bytes-consed))
              (lkey "key-3"))
          (dotimes (i n)
            (fol.compiler.collections:collection-ref fol-map-with-key lkey))
          (let ((t2 (get-internal-real-time))
                (b2 (fol.benchmarks::get-bytes-consed)))
            (format t "  FOL (COLLECTION-REF) - Persistent    : ~,4F seconds, ~,2F MB~%"
              (/ (- t2 t1) internal-time-units-per-second)
              (/ (- b2 b1) 1024.0 1024.0))))

        (format t "~&Lookup Missing Element:~%")
        (let ((t1 (get-internal-real-time))
              (b1 (fol.benchmarks::get-bytes-consed))
              (missing-key "missing-key-999"))
          (dotimes (i n)
            (gethash missing-key cl-map))
          (let ((t2 (get-internal-real-time))
                (b2 (fol.benchmarks::get-bytes-consed)))
            (format t "  Common Lisp (GETHASH) - Native       : ~,4F seconds, ~,2F MB~%"
              (/ (- t2 t1) internal-time-units-per-second)
              (/ (- b2 b1) 1024.0 1024.0))))

        (let ((t1 (get-internal-real-time))
              (b1 (fol.benchmarks::get-bytes-consed))
              (missing-key "missing-key-999"))
          (dotimes (i n)
            (fol.compiler.collections:collection-ref fol-map-with-key missing-key))
          (let ((t2 (get-internal-real-time))
                (b2 (fol.benchmarks::get-bytes-consed)))
            (format t "  FOL (COLLECTION-REF) - Persistent    : ~,4F seconds, ~,2F MB~%"
              (/ (- t2 t1) internal-time-units-per-second)
              (/ (- b2 b1) 1024.0 1024.0))))))))

(run-map-benchmarks)
