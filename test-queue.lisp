;;; Test queue operations

(in-package :cl-user)

;; Load FOL compiler
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create a package for the FOL code
(defpackage :queue-test
  (:use :cl)
  (:shadow list)
  (:import-from :fol.compiler.collections
                make collection-conj collection-seq storage-items
                <vector> <dict> <set> <bag> <priority-dict>
                priority-dict-peek-min priority-dict-pop-min)
  (:shadowing-import-from :fol.compiler.collection-functions
                vector dict set bag
                first rest get assoc dissoc conj size empty? count)
  (:shadowing-import-from :fol.compiler.primitive-functions
                zero? odd? even? symbol keyword)
  (:import-from :fol.compiler.primitives
                truthy? falsy?)
  (:import-from :fol.compiler.string-functions
                str))

(in-package :queue-test)
(defparameter true t)
(defparameter false nil)

(in-package :cl-user)

(defun compile-and-eval-fol-expr (expr-str)
  "Compile and evaluate a single FOL expression in :queue-test package."
  (let* ((*package* (find-package :queue-test))
         (*readtable* fol.compiler.reader:*fol-readtable*)
         (form (read-from-string expr-str))
         (result (fol.compiler:compile-form form)))
    (when (fol.compiler:compilation-result-errors result)
      (format t "~%COMPILATION ERRORS:~%")
      (dolist (err (fol.compiler:compilation-result-errors result))
        (format t "  ~A~%" err))
      (error "FOL compilation failed"))
    (let ((code (fol.compiler:compilation-result-code result)))
      (format t "Compiled to: ~S~%" code)
      (eval code))))

(format t "~%Test 1: Create empty queue~%")
(let ((q (compile-and-eval-fol-expr "{:pdict (make '<priority-dict>) :counter 0 :events {}}")))
  (format t "Queue: ~A~%" q)
  (format t "Queue type: ~A~%"  (type-of q)))

(format t "~%Test 2: Access :pdict from queue~%")
(let ((q (compile-and-eval-fol-expr "{:pdict (make '<priority-dict>) :counter 0 :events {}}")))
  (format t "Calling (:pdict q)...~%")
  (handler-case
      (let ((pd (compile-and-eval-fol-expr "(:pdict {:pdict (make '<priority-dict>) :counter 0 :events {}})")))
        (format t "Pdict: ~A~%" pd))
    (error (e)
      (format t "ERROR: ~A~%" e))))

(format t "~%Test 3: Simple bind with dict~%")
(handler-case
    (compile-and-eval-fol-expr "(bind [q {:a 1}] q)")
  (error (e)
    (format t "ERROR: ~A~%" e)))

(format t "~%Done!~%")
(sb-ext:quit)
