;;; FOL Core Package - Unified namespace
;;;
;;; Re-exports all FOL symbols so that downstream packages can
;;; (:use fol.core) to get the full FOL standard library.

(cl:in-package :fol.core)

;;; ---------------------------------------------------------------------------
;;; Programmatic re-export of all FOL symbols
;;;
;;; Iterates over all packages starting with "FOL.".
;;; Exports all external symbols from those packages (except excluded ones)
;;; from the FOL.CORE package.
;;; ---------------------------------------------------------------------------

(cl:eval-when (:compile-toplevel :load-toplevel :execute)
  (cl:let ((core-pkg (cl:find-package :fol.core))
           (excluded-packages '("FOL.COMPILER.AST" "FOL.COMPILER.TESTS" "FOL.COMPILER.DESTRUCTURE" "FOL.CORE")))
    (cl:dolist (pkg (cl:list-all-packages))
      (cl:let ((pkg-name (cl:package-name pkg)))
        (cl:when (cl:and (cl:search "FOL." pkg-name)
                   (cl:not (cl:member pkg-name excluded-packages :test #'cl:string=)))
          (cl:do-external-symbols (sym pkg)
            (cl:multiple-value-bind (accessible-sym status) (cl:find-symbol (cl:symbol-name sym) core-pkg)
              (cl:let ((target-sym (cl:cond
                                     ((cl:and status (cl:eq sym accessible-sym))
                                      (cl:export sym core-pkg)
                                      sym)
                                     ((cl:null status)
                                      (cl:import sym core-pkg)
                                      (cl:export sym core-pkg)
                                      sym)
                                     (cl:t cl:nil))))
                ;; For Lisp-1 compatibility: if it's a function, also set its symbol-value.
                ;; Skip symbols from the CL package to avoid violating package locks.
                (cl:when (cl:and target-sym
                           (cl:not (cl:eq (cl:symbol-package target-sym) (cl:find-package :cl)))
                           (cl:fboundp target-sym)
                           (cl:not (cl:constantp target-sym)))
                  (cl:setf (cl:symbol-value target-sym) (cl:symbol-function target-sym)))))))))
    cl:t))
