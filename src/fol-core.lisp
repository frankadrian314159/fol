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
           (excluded-packages '("FOL.COMPILER.AST" "FOL.COMPILER.TESTS" "FOL.COMPILER.DESTRUCTURE" "FOL.CORE"))
           (seen-syms (cl:make-hash-table :test #'cl:eq))
           (type-syms 0)
           (other-syms 0))
    (cl:dolist (pkg (cl:list-all-packages))
      (cl:let ((pkg-name (cl:package-name pkg)))
        (cl:when (cl:and (cl:search "FOL." pkg-name)
                   (cl:not (cl:member pkg-name excluded-packages :test #'cl:string=)))
          (cl:do-external-symbols (sym pkg)
            (cl:let ((accessible-sym (cl:find-symbol (cl:symbol-name sym) core-pkg)))
              (cl:when (cl:eq sym accessible-sym)
                (cl:export sym core-pkg)
                (cl:unless (cl:gethash sym seen-syms)
                  (cl:setf (cl:gethash sym seen-syms) cl:t)
                  (cl:let ((name (cl:symbol-name sym)))
                    (cl:if (cl:and (cl:> (cl:length name) 1)
                             (cl:char= (cl:char name 0) #\<)
                             (cl:char= (cl:char name (cl:1- (cl:length name))) #\>))
                           (cl:incf type-syms)
                           (cl:incf other-syms))))))))))
    (cl:format t "~%Exported ~A type symbols and ~A other symbols from ~A packages.~%" type-syms other-syms (cl:length (cl:remove-if-not (lambda (pkg) (cl:search "FOL." (cl:package-name pkg))) (cl:list-all-packages))))
    (cl:values type-syms other-syms)))
