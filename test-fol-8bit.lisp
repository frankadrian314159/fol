;;; Test 8-bit register creation

(in-package :cl-user)

;; Load FOL compiler
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create a package for the FOL code
(defpackage :lsim-fol-test
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
                str)
  (:export make-nbit-register-from-gates make-test-events run-simulation))

;; Define true and false constants
(in-package :lsim-fol-test)
(defparameter true t)
(defparameter false nil)

;; Define bit-test function
(defun bit-test (integer index)
  "Test if bit at INDEX in INTEGER is set."
  (logbitp index integer))

(in-package :cl-user)

(defun compile-and-eval-fol-file (filepath)
  "Compile and evaluate a FOL file in the :lsim-fol-test package."
  (with-open-file (stream filepath :direction :input)
    (let ((*package* (find-package :lsim-fol-test)))
      (loop for form = (let ((*readtable* fol.compiler.reader:*fol-readtable*))
                        (read stream nil :eof))
            until (eq form :eof)
            do (let ((result (fol.compiler:compile-form form)))
                 (when (fol.compiler:compilation-result-errors result)
                   (format t "~%COMPILATION ERRORS:~%")
                   (dolist (err (fol.compiler:compilation-result-errors result))
                     (format t "  ~A~%" err))
                   (error "FOL compilation failed"))
                 (let ((code (fol.compiler:compilation-result-code result)))
                   (eval code)))))))

(format t "~%=== Loading lsim-fol-simple.fol ===~%")
(compile-and-eval-fol-file "lsim-fol-simple.fol")

(format t "~%=== Creating 8-bit register ===~%")
(let ((netlist (funcall (intern "MAKE-NBIT-REGISTER-FROM-GATES" :lsim-fol-test) 8)))
  (format t "Netlist type: ~A~%" (type-of netlist))
  (let ((netlist-size (fol.compiler.collection-functions:size netlist)))
    (format t "Netlist size: ~D~%"  netlist-size)))

(format t "~%=== Creating test events (8 bits, 300 time units) ===~%")
(let ((events (funcall (intern "MAKE-TEST-EVENTS" :lsim-fol-test) 8 300)))
  (format t "Events type: ~A~%" (type-of events))
  (format t "Calling size...~%")
  (handler-case
      (let ((events-size (fol.compiler.collection-functions:size events)))
        (format t "Events size: ~D~%" events-size))
    (error (e)
      (format t "ERROR calling size: ~A~%" e)
      (format t "Events object: ~A~%" events))))

(format t "~%Done!~%")
(sb-ext:quit)
