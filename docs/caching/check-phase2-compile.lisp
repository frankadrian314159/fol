;;; Check if Phase 2 implementation compiles

(push (truename "src/") asdf:*central-registry*)

;; Load only the core compiler, not tests
(asdf:load-system :fol-compiler)

;; Test a simple dispatch caching scenario
(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
  (format t "Created cache: ~A~%" cache)
  (format t "Cache generation: ~A~%" (fol.compiler.dispatch:dispatch-cache-generation cache))

  ;; Test cache operations
  (fol.compiler.dispatch:cache-insert! cache '(standard-object standard-object) #'(lambda (x y) (+ x y)))
  (let ((hit (fol.compiler.dispatch:cache-lookup cache '(standard-object standard-object))))
    (format t "Cache hit: ~A~%" (if hit "SUCCESS" "FAIL")))

  ;; Test flush
  (fol.compiler.dispatch:cache-flush! cache)
  (format t "Cache generation after flush: ~A~%" (fol.compiler.dispatch:dispatch-cache-generation cache))

  ;; Test pred-key
  (format t "pred-key for fixnum: ~A~%" (fol.compiler.dispatch:pred-key 42))
  (format t "pred-key for symbol: ~A~%" (fol.compiler.dispatch:pred-key 'foo))
  (format t "pred-key for object: ~A~%" (class-of (fol.compiler.dispatch:pred-key (make-instance 'standard-object))))

  (format t "~%Phase 2 dispatch caching implementation compiles successfully!~%"))

(quit)
