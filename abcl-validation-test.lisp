;;;; ABCL Validation Test for Dispatch Caching
;;;; Run: java -jar abcl.jar --load abcl-validation-test.lisp

(format t "~%=== ABCL DISPATCH CACHING VALIDATION ===%~%")
(format t "ABCL Version: ~A~%" (lisp-implementation-version))

;; Load Quicklisp
(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-path)
      (load ql-path)
      (format t "WARNING: Quicklisp not found at ~A~%" ql-path)))

;; Setup ASDF registry
(push (truename "src") asdf:*central-registry*)

;; Load FOL compiler
(format t "~%Loading FOL compiler...~%")
(asdf:load-system :fol-compiler)

(format t "Dispatch module: ~A~%" (find-package :fol.compiler.dispatch))

;; Phase 1 Tests: Basic Compilation and Loading
(format t "~%=== PHASE 1: BASIC COMPILATION AND LOADING ===%~%")

;; Test 1.2: Create cache instance
(format t "~%Test 1.2: Create cache instance~%")
(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
  (format t "✅ Cache created: ~A~%" (type-of cache))
  (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
    (format t "Initial stats: hits=~D misses=~D gen=~D size=~D~%" h m g s)))

;; Test 1.3: Basic cache operations
(format t "~%Test 1.3: Basic cache operations~%")
(let ((cache (fol.compiler.dispatch:make-dispatch-cache)))
  (fol.compiler.dispatch:cache-insert! cache '(integer) #'identity)
  (let ((hit (fol.compiler.dispatch:cache-lookup cache '(integer))))
    (format t "Cache hit: ~A~%" (eq hit #'identity)))
  (let ((miss (fol.compiler.dispatch:cache-lookup cache '(string))))
    (format t "Cache miss: ~A~%" (null miss)))
  (multiple-value-bind (h m g s) (fol.compiler.dispatch:cache-stats cache)
    (format t "Final stats: hits=~D misses=~D size=~D~%" h m g s)))

(format t "~%✅ ABCL PHASE 1 VALIDATION COMPLETE~%")
(quit)
