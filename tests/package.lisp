(in-package :cl-user)

;; Delete package to ensure a clean slate
(eval-when (:compile-toplevel :load-toplevel :execute)
  (when (find-package :fol.integration-tests)
    (delete-package :fol.integration-tests)))

(defpackage :fol.integration-tests
  (:use :cl :fiveam)
  (:import-from :fol.eval :make-standard-module :fol-eval)
  (:import-from :fol.collection :<vector> :<list> :<dict> :<set>)
  (:export :run-integration-tests))

(in-package :fol.integration-tests)

(def-suite integration-suite
  :description "Integration tests for FOL using %test%.")

(defun run-integration-tests ()
  "Run all FOL integration tests."
  (run! 'integration-suite))

;;; Get the %test% function from the standard environment
(defun %test% (form-string &optional env)
  "Evaluate FORM-STRING using the %test% function from the standard environment.
   This mirrors how %test% would be called from FOL code."
  (let* ((std-env (or env (make-standard-module)))
         (test-fn (fol-eval '%test% std-env)))
    (funcall test-fn form-string std-env)))

;;; Helper function to convert FOL values to CL values for comparison
(defun fol-to-cl (value)
  "Convert a FOL value to a comparable Common Lisp value."
  (typecase value
    ;; FOL vectors become CL lists
    (fol.collection:<vector>
     (let ((items (fol.persistent:pslot-value value 'fol.collection::items)))
       (mapcar #'fol-to-cl (fset:convert 'cl:list items))))
    ;; FOL lists become CL lists
    (fol.collection:<list>
     (let ((items (fol.persistent:pslot-value value 'fol.collection::items)))
       (mapcar #'fol-to-cl (fset:convert 'cl:list items))))
    ;; FOL sets become sorted lists
    (fol.collection:<set>
     (let ((items (fol.persistent:pslot-value value 'fol.collection::items)))
       (mapcar #'fol-to-cl (fset:convert 'cl:list items))))
    ;; FOL dicts - just return as-is for now (comparison is tricky)
    (fol.collection:<dict>
     value)
    ;; Double floats: convert to single float for comparison
    (double-float
     (coerce value 'single-float))
    ;; Everything else passes through
    (t value)))

;;; Helper macro for FOL assertions
(defmacro fol-is (expected fol-string &optional description)
  "Assert that FOL-STRING evaluates to EXPECTED using %test%."
  `(is (equal ,expected (fol-to-cl (%test% ,fol-string)))
       ,@(when description (list description))))

(defmacro fol-is-true (fol-string &optional description)
  "Assert that FOL-STRING evaluates to a truthy value using %test%."
  `(is-true (%test% ,fol-string)
            ,@(when description (list description))))

(defmacro fol-is-false (fol-string &optional description)
  "Assert that FOL-STRING evaluates to nil/false using %test%."
  `(is-false (%test% ,fol-string)
             ,@(when description (list description))))

(defmacro fol-signals (condition fol-string &optional description)
  "Assert that FOL-STRING signals CONDITION using %test%."
  `(signals ,condition
     (%test% ,fol-string)
     ,@(when description (list description))))
