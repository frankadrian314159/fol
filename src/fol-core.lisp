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
            (cl:export sym core-pkg)))))))
