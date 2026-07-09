;;; FOL Compiler - Version Information
;;;
;;; Semantic versioning for the FOL project.
;;; Format: MAJOR.MINOR.PATCH

(defpackage :fol.compiler.version
  (:use :common-lisp)
  (:export :*version*
           :version))

(in-package :fol.compiler.version)

(defparameter *version* "0.4.14"
  "The semantic version of FOL compiler.
   MAJOR: Incompatible API changes
   MINOR: Backwards-compatible new features
   PATCH: Backwards-compatible bug fixes")

(defun version ()
  "Return the FOL compiler version as a string."
  *version*)
