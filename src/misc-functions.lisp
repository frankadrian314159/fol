;;; FOL Compiler - Miscellaneous Functions
;;;
;;; Provides defonce and intern: definition-once semantics and symbol interning.

(in-package :fol.compiler.misc-functions)

;;; ===========================================================================
;;; defonce - define a var only if not already bound
;;; ===========================================================================

(defmacro defonce (name value)
  "Define NAME as a special variable with VALUE only if NAME is not already bound.
   If NAME is already bound, this is a no-op.
   NAME is always declared special (via defvar).

   This mirrors Clojure's defonce: subsequent evaluations of the same form
   during development or reloading do not overwrite an existing binding.

   Examples:
     (defonce *counter* 0)  ; sets *counter* to 0 if unbound
     (defonce *counter* 99) ; no-op if *counter* is already bound"
  `(progn
     (defvar ,name)
     (unless (boundp ',name)
       (setf ,name ,value))
     ',name))

;;; ===========================================================================
;;; intern - intern a symbol into a package
;;; ===========================================================================

(defun intern (name &optional (pkg *package*))
  "Intern NAME as a symbol in PKG (defaults to *package*).
   NAME may be a string or a symbol. String names are uppercased to follow
   CL conventions. PKG may be a package object, a string naming a package,
   or a keyword naming a package.

   Returns the interned symbol.

   Examples:
     (intern \"FOO\")          ; => FOO (in *package*)
     (intern \"bar\")          ; => BAR (uppercased)
     (intern 'my-sym)         ; => MY-SYM
     (intern \"FOO\" :keyword) ; => :FOO"
  (let ((name-str (if (stringp name)
                      (cl:string-upcase name)
                      (cl:symbol-name name)))
        (package (etypecase pkg
                   (cl:package pkg)
                   (cl:string  (or (cl:find-package (cl:string-upcase pkg))
                                   (error "No package named ~S" pkg)))
                   (cl:keyword (or (cl:find-package (cl:string pkg))
                                   (error "No package named ~S" pkg)))
                   (cl:symbol  (or (cl:find-package (cl:symbol-name pkg))
                                   (error "No package named ~S" pkg))))))
    (cl:intern name-str package)))
