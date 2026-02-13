;;; FOL Compiler - Reader
;;;
;;; Defines *fol-readtable*, a CL readtable extended with FOL reader macros.
;;; Copies the standard CL readtable and adds support for:
;;;   [...]     - vector literal
;;;   {...}     - dict literal
;;;   #{...}    - set literal
;;;   #M{...}   - bag (multiset) literal
;;;   #"..."    - regex pattern literal
;;;   #_        - ignore next form
;;;   @expr     - deref (expands to (deref expr))
;;;
;;; Usage:
;;;   (let ((*readtable* fol.compiler.reader:*fol-readtable*))
;;;     (read-from-string "[1 2 3]"))
;;;   => <vector> of 1, 2, 3

(in-package :fol.compiler.reader)

;;; ============================================================================
;;; FOL Readtable
;;; ============================================================================

(defvar *fol-readtable* (copy-readtable nil)
  "The FOL readtable, based on the standard CL readtable with FOL extensions.")

;;; ============================================================================
;;; Reader Macro Functions
;;; ============================================================================

(defun read-fol-vector (stream char)
  "Read a FOL vector literal: [e1 e2 ...]"
  (declare (ignore char))
  (let ((elements (read-delimited-list #\] stream t)))
    (apply #'fol.compiler.collections:vector elements)))

(defun read-fol-dict (stream char)
  "Read a FOL dict literal: {k1 v1 k2 v2 ...}"
  (declare (ignore char))
  (let ((pairs (read-delimited-list #\} stream t)))
    (unless (evenp (length pairs))
      (error "Dict literal must contain an even number of forms"))
    (apply #'fol.compiler.collections:dict pairs)))

(defun read-fol-close-bracket (stream char)
  "Signal an error for unmatched ] or }."
  (declare (ignore stream))
  (error "Unmatched closing ~C" char))

;;; --- Dispatch macro functions (called via #) ---

(defun read-fol-set (stream sub-char arg)
  "Read a FOL set literal: #{e1 e2 ...}"
  (declare (ignore sub-char arg))
  (let ((elements (read-delimited-list #\} stream t)))
    (apply #'fol.compiler.collections:set elements)))

(defun read-fol-bag (stream sub-char arg)
  "Read a FOL bag (multiset) literal: #M{e1 e2 ...}"
  (declare (ignore sub-char arg))
  (let ((next (read-char stream t nil t)))
    (unless (char= next #\{)
      (error "Expected { after #M, got ~C" next))
    (let ((elements (read-delimited-list #\} stream t)))
      (apply #'fol.compiler.collections:bag elements))))

(defun read-fol-regex (stream sub-char arg)
  "Read a FOL regex pattern: #\"pattern\"
   Returns the pattern as a string (re-pattern is a type descriptor)."
  (declare (ignore sub-char arg))
  (let ((result (make-array 0 :element-type 'character
                              :fill-pointer 0 :adjustable t)))
    (loop
      (let ((c (read-char stream t nil t)))
        (cond
          ((char= c #\")
           (return (copy-seq result)))
          ((char= c #\\)
           (let ((next (read-char stream t nil t)))
             (vector-push-extend
              (case next
                (#\n #\Newline)
                (#\t #\Tab)
                (#\r #\Return)
                (t next))
              result)))
          (t
           (vector-push-extend c result)))))))

(defun read-fol-ignore (stream sub-char arg)
  "Read and discard the next form: #_form"
  (declare (ignore sub-char arg))
  (read stream t nil t)
  (values))

(defun read-fol-deref (stream char)
  "Read a FOL deref: @expr => (fol.compiler.mutable:deref expr)"
  (declare (ignore char))
  (list 'fol.compiler.mutable:deref (read stream t nil t)))

;;; ============================================================================
;;; Install Reader Macros
;;; ============================================================================

;;; [ and ] for vectors
(set-macro-character #\[ #'read-fol-vector nil *fol-readtable*)
(set-macro-character #\] #'read-fol-close-bracket nil *fol-readtable*)

;;; { and } for dicts
(set-macro-character #\{ #'read-fol-dict nil *fol-readtable*)
(set-macro-character #\} #'read-fol-close-bracket nil *fol-readtable*)

;;; #{ for sets
(set-dispatch-macro-character #\# #\{ #'read-fol-set *fol-readtable*)

;;; #M for bags (multisets)
(set-dispatch-macro-character #\# #\M #'read-fol-bag *fol-readtable*)

;;; #" for regex patterns
(set-dispatch-macro-character #\# #\" #'read-fol-regex *fol-readtable*)

;;; #_ for ignore-next-form
(set-dispatch-macro-character #\# #\_ #'read-fol-ignore *fol-readtable*)

;;; @ for deref
(set-macro-character #\@ #'read-fol-deref nil *fol-readtable*)

;;; ============================================================================
;;; Reader Entry Points
;;; ============================================================================

(defun fol-read (&optional (stream *standard-input*) (eof-error-p t) eof-value recursive-p)
  "Read one FOL expression from STREAM using *fol-readtable*."
  (let ((*readtable* *fol-readtable*))
    (read stream eof-error-p eof-value recursive-p)))

(defun fol-read-from-string (string &optional (eof-error-p t) eof-value)
  "Read one FOL expression from STRING using *fol-readtable*.
   Returns two values: the expression and the position after reading."
  (let ((*readtable* *fol-readtable*))
    (read-from-string string eof-error-p eof-value)))
