;;;; Profile dispatch cache hit rates on real FOL code

(eval-when (:compile-toplevel :load-toplevel :execute)
  (push (truename ".") asdf:*central-registry*))

(asdf:load-system :fol-compiler/tests)

(defun profile-caching ()
  "Run FOL test suite and measure dispatch cache hit rates."
  (format t "~%=== Profiling Dispatch Cache on Real FOL Workload ===~%~%")

  ;; Clear any existing caches
  (fol.compiler.dispatch:flush-all-caches!)

  ;; Run the full test suite
  (format t "Running full FOL compiler test suite...~%")
  (let ((start-time (get-internal-real-time)))
    (fiveam:run! 'fol.compiler.tests:compiler-tests)
    (let ((elapsed (/ (- (get-internal-real-time) start-time)
                      internal-time-units-per-second)))
      (format t "Test suite completed in ~,2F seconds~%~%" elapsed)))

  ;; Collect cache statistics from all cached functions
  (format t "~%=== Cache Statistics Summary ===~%~%")
  (let ((total-hits 0)
        (total-misses 0)
        (cached-fns 0)
        (fn-stats nil))

    ;; Walk through all known cached function names
    ;; (This is a heuristic: look for symbols with %-...-DISPATCH-CACHE names)
    (do-all-symbols (sym *package*)
      (when (and (boundp sym)
                 (stringp (symbol-name sym))
                 (search "DISPATCH-CACHE" (symbol-name sym)))
        (let ((cache (symbol-value sym)))
          (when (typep cache 'fol.compiler.dispatch:dispatch-cache)
            (multiple-value-bind (hits misses gen size)
                (fol.compiler.dispatch:cache-stats cache)
              (incf total-hits hits)
              (incf total-misses misses)
              (incf cached-fns)
              (when (> (+ hits misses) 0)
                (let ((hit-rate (* 100.0 (/ hits (+ hits misses)))))
                  (push (list sym hits misses size hit-rate) fn-stats))))))))

    (if (zerop cached-fns)
        (format t "No cached functions found (cache stats not yet populated).~%")
        (progn
          (format t "Cached functions: ~D~%" cached-fns)
          (format t "Total hits: ~D~%" total-hits)
          (format t "Total misses: ~D~%" total-misses)
          (when (> (+ total-hits total-misses) 0)
            (let ((overall-hit-rate (* 100.0 (/ total-hits (+ total-hits total-misses)))))
              (format t "Overall hit rate: ~,1F%~%~%" overall-hit-rate)))

          (when fn-stats
            (format t "~%Per-function breakdown (hit-rate > 0):~%")
            (format t "~A ~20A ~10A ~10A ~10A~%"
                    "Function" "Hits" "Misses" "Entries" "Hit Rate")
            (format t "~A~%" (make-string 70 :initial-element #\-))
            (loop for (name hits misses size hit-rate) in (nreverse (sort fn-stats #'> :key #'fifth))
                  do (format t "~30A ~10D ~10D ~10D ~8,1F%~%"
                             (symbol-name name) hits misses size hit-rate))))))

  (format t "~%=== Profiling Complete ===~%"))

(defun main ()
  (profile-caching))

(main)
