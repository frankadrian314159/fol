;;; FOL Compiler - Metadata Tests
;;;
;;; Tests for the metadata system: meta, with-meta, vary-meta,
;;; alter-meta!, reset-meta!, doc, find-doc, test, and ^ reader macro.

(in-package :fol.compiler.tests)
(in-suite metadata-tests)

;;; ===========================================================================
;;; meta - Retrieve metadata
;;; ===========================================================================

(test meta-symbol-no-metadata
  "meta returns NIL for a symbol with no metadata."
  (let ((sym (cl:gensym "META-TEST-")))
    (is (null (fol.compiler.metadata:meta sym)))))

(test meta-nil-value
  "meta returns NIL for non-metadata-bearing objects."
  (is (null (fol.compiler.metadata:meta 42)))
  (is (null (fol.compiler.metadata:meta "hello")))
  (is (null (fol.compiler.metadata:meta nil))))

(test meta-collection-no-metadata
  "meta returns NIL for a collection with no metadata."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.metadata:meta v)))))

;;; ===========================================================================
;;; with-meta / meta round-trip on symbols
;;; ===========================================================================

(test with-meta-symbol
  "with-meta sets metadata on a symbol."
  (let ((sym (cl:gensym "WM-SYM-")))
    (fol.compiler.metadata:with-meta sym '(:doc "test doc"))
    (is (equal '(:doc "test doc") (fol.compiler.metadata:meta sym)))
    ;; Clean up plist
    (remprop sym :%metadata)))

(test with-meta-symbol-overwrites
  "with-meta replaces existing metadata on a symbol."
  (let ((sym (cl:gensym "WM-OVR-")))
    (fol.compiler.metadata:with-meta sym '(:a 1))
    (fol.compiler.metadata:with-meta sym '(:b 2))
    (is (equal '(:b 2) (fol.compiler.metadata:meta sym)))
    (remprop sym :%metadata)))

;;; ===========================================================================
;;; with-meta on collections
;;; ===========================================================================

(test with-meta-vector
  "with-meta returns a new vector with metadata."
  (let* ((v (fol.compiler.collection-functions:vector 1 2 3))
         (v2 (fol.compiler.metadata:with-meta v '(:source "test"))))
    ;; New vector has metadata
    (is (equal '(:source "test") (fol.compiler.metadata:meta v2)))
    ;; Original unchanged
    (is (null (fol.compiler.metadata:meta v)))
    ;; Values preserved
    (is (eql 3 (fol.compiler.collections:collection-size v2)))))

(test with-meta-dict
  "with-meta returns a new dict with metadata."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (d2 (fol.compiler.metadata:with-meta d '(:tag "config"))))
    (is (equal '(:tag "config") (fol.compiler.metadata:meta d2)))
    (is (null (fol.compiler.metadata:meta d)))
    (is (eql 2 (fol.compiler.collections:collection-size d2)))))

(test with-meta-set
  "with-meta returns a new set with metadata."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3))
         (s2 (fol.compiler.metadata:with-meta s '(:unique t))))
    (is (equal '(:unique t) (fol.compiler.metadata:meta s2)))
    (is (null (fol.compiler.metadata:meta s)))))

;;; ===========================================================================
;;; with-meta on persistent objects
;;; ===========================================================================

(test with-meta-persistent-object
  "with-meta returns a new persistent object with metadata."
  (eval '(defclass <test-meta-point> (fol.compiler.persistent:<persistent-object>)
           ((x :initarg :x)
            (y :initarg :y))
           (:metaclass fol.compiler.persistent:persistent-class)))
  (let* ((p (make-instance '<test-meta-point> :x 1 :y 2))
         (p2 (fol.compiler.metadata:with-meta p '(:label "origin"))))
    (is (equal '(:label "origin") (fol.compiler.metadata:meta p2)))
    (is (null (fol.compiler.metadata:meta p)))
    ;; Slot values preserved
    (is (eql 1 (slot-value p2 'x)))
    (is (eql 2 (slot-value p2 'y)))))

;;; ===========================================================================
;;; vary-meta
;;; ===========================================================================

(test vary-meta-symbol
  "vary-meta applies function to symbol metadata."
  (let ((sym (cl:gensym "VM-")))
    (fol.compiler.metadata:with-meta sym '(:count 0))
    (let ((result (fol.compiler.metadata:vary-meta
                   sym (lambda (m) (list :count (1+ (getf m :count)))))))
      (is (equal '(:count 1) (fol.compiler.metadata:meta result))))
    (remprop sym :%metadata)))

(test vary-meta-collection
  "vary-meta applies function to collection metadata."
  (let* ((v (fol.compiler.metadata:with-meta
             (fol.compiler.collection-functions:vector 1 2)
             '(:version 1)))
         (v2 (fol.compiler.metadata:vary-meta
              v (lambda (m) (list :version (1+ (getf m :version)))))))
    (is (equal '(:version 2) (fol.compiler.metadata:meta v2)))
    (is (equal '(:version 1) (fol.compiler.metadata:meta v)))))

;;; ===========================================================================
;;; alter-meta! / reset-meta!
;;; ===========================================================================

(test alter-meta!-symbol
  "alter-meta! atomically modifies symbol metadata."
  (let ((sym (cl:gensym "AM-")))
    (fol.compiler.metadata:with-meta sym '(:hits 0))
    (fol.compiler.metadata:alter-meta!
     sym (lambda (m) (list :hits (1+ (getf m :hits)))))
    (is (equal '(:hits 1) (fol.compiler.metadata:meta sym)))
    (remprop sym :%metadata)))

(test reset-meta!-symbol
  "reset-meta! replaces symbol metadata."
  (let ((sym (cl:gensym "RM-")))
    (fol.compiler.metadata:with-meta sym '(:old t))
    (fol.compiler.metadata:reset-meta! sym '(:new t))
    (is (equal '(:new t) (fol.compiler.metadata:meta sym)))
    (remprop sym :%metadata)))

;;; ===========================================================================
;;; doc and test
;;; ===========================================================================

(test doc-from-plist
  "doc retrieves :doc from symbol metadata (plist form)."
  (let ((sym (cl:gensym "DOC-")))
    (fol.compiler.metadata:with-meta sym '(:doc "A test function"))
    (is (equal "A test function" (fol.compiler.metadata:doc sym)))
    (remprop sym :%metadata)))

(test doc-nil-when-missing
  "doc returns NIL when no :doc in metadata."
  (let ((sym (cl:gensym "NDOC-")))
    (fol.compiler.metadata:with-meta sym '(:tag "x"))
    (is (null (fol.compiler.metadata:doc sym)))
    (remprop sym :%metadata)))

(test doc-nil-when-no-metadata
  "doc returns NIL when symbol has no metadata."
  (let ((sym (cl:gensym "NMD-")))
    (is (null (fol.compiler.metadata:doc sym)))))

(test test-from-plist
  "test retrieves :test from symbol metadata (plist form)."
  (let ((sym (cl:gensym "TST-")))
    (fol.compiler.metadata:with-meta sym (list :test #'identity))
    (is (eq #'identity (fol.compiler.metadata:test sym)))
    (remprop sym :%metadata)))

;;; ===========================================================================
;;; doc with FOL dict metadata
;;; ===========================================================================

(test doc-from-dict
  "doc retrieves :doc from FOL dict metadata."
  (let* ((sym (cl:gensym "DDOC-"))
         (meta-dict (fol.compiler.collection-functions:dict :doc "Dict doc")))
    (fol.compiler.metadata:with-meta sym meta-dict)
    (is (equal "Dict doc" (fol.compiler.metadata:doc sym)))
    (remprop sym :%metadata)))

(test test-from-dict
  "test retrieves :test from FOL dict metadata."
  (let* ((sym (cl:gensym "DTST-"))
         (meta-dict (fol.compiler.collection-functions:dict :test #'identity)))
    (fol.compiler.metadata:with-meta sym meta-dict)
    (is (eq #'identity (fol.compiler.metadata:test sym)))
    (remprop sym :%metadata)))

;;; ===========================================================================
;;; ^ Reader Macro
;;; ===========================================================================

(test reader-meta-dict
  "^{k v} form reads as (with-meta form {k v})."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (result (read-from-string "^{:doc \"hello\"} foo")))
    ;; Should be (with-meta foo {dict ...})
    (is (eq 'fol.compiler.metadata:with-meta (first result)))
    (is (eq 'foo (second result)))))

(test reader-meta-keyword
  "^:kw form reads as (with-meta form (dict :kw t))."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (result (read-from-string "^:private foo")))
    (is (eq 'fol.compiler.metadata:with-meta (first result)))
    (is (eq 'foo (second result)))
    ;; Third element should be (dict :private t)
    (let ((meta-form (third result)))
      (is (eq 'fol.compiler.collection-functions:dict (first meta-form)))
      (is (eq :private (second meta-form)))
      (is (eq t (third meta-form))))))

(test reader-meta-type
  "^Type form reads as (with-meta form (dict :type Type))."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (result (read-from-string "^String foo")))
    (is (eq 'fol.compiler.metadata:with-meta (first result)))
    (is (eq 'foo (second result)))
    (let ((meta-form (third result)))
      (is (eq 'fol.compiler.collection-functions:dict (first meta-form)))
      (is (eq :type (second meta-form))))))

;;; ===========================================================================
;;; find-doc
;;; ===========================================================================

(test find-doc-returns-matches
  "find-doc finds symbols with matching :doc metadata."
  (let ((sym1 (intern "FOL-FIND-DOC-TEST-SYM1" :fol.compiler.tests))
        (sym2 (intern "FOL-FIND-DOC-TEST-SYM2" :fol.compiler.tests))
        (sym3 (intern "FOL-FIND-DOC-TEST-SYM3" :fol.compiler.tests)))
    (fol.compiler.metadata:with-meta sym1 '(:doc "Calculates the sum of two numbers"))
    (fol.compiler.metadata:with-meta sym2 '(:doc "Multiplies two numbers"))
    (fol.compiler.metadata:with-meta sym3 '(:tag "no doc here"))
    (let ((results (fol.compiler.metadata:find-doc "Calculates the sum")))
      (is (cl:find sym1 results :key #'car)))
    (remprop sym1 :%metadata)
    (remprop sym2 :%metadata)
    (remprop sym3 :%metadata)))

(test find-doc-case-insensitive
  "find-doc searches case-insensitively."
  (let ((sym (intern "FOL-FIND-DOC-CASE-TEST" :fol.compiler.tests)))
    (fol.compiler.metadata:with-meta sym '(:doc "UPPERCASE-XYZZY doc"))
    (let ((results (fol.compiler.metadata:find-doc "uppercase-xyzzy")))
      (is (cl:find sym results :key #'car)))
    (remprop sym :%metadata)))
