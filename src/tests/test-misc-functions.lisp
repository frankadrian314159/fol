;;; FOL Compiler - Miscellaneous Functions Tests

(in-package :fol.compiler.tests)
(in-suite misc-functions-tests)

;;; ===========================================================================
;;; defonce tests
;;; ===========================================================================

(test defonce-defines-when-unbound
  "defonce sets VALUE when NAME is not yet bound."
  (let ((sym (gensym "DEFONCE-TEST-")))
    (eval `(fol.compiler.misc-functions:defonce ,sym :first-value))
    (is (boundp sym))
    (is (eq :first-value (symbol-value sym)))))

(test defonce-no-overwrite-when-bound
  "defonce does not change VALUE when NAME is already bound."
  (let ((sym (gensym "DEFONCE-TEST-")))
    (eval `(defparameter ,sym :original))
    (eval `(fol.compiler.misc-functions:defonce ,sym :new-value))
    (is (eq :original (symbol-value sym)))))

(test defonce-returns-symbol-name
  "defonce returns the quoted symbol name."
  (let ((sym (gensym "DEFONCE-TEST-")))
    (is (eq sym (eval `(fol.compiler.misc-functions:defonce ,sym :ignored))))))

(test defonce-declares-special
  "defonce declares NAME as a special variable."
  (let ((sym (gensym "DEFONCE-TEST-SPECIAL-")))
    (eval `(fol.compiler.misc-functions:defonce ,sym 99))
    ;; After defonce the var is special (proclaimed special by defvar)
    (is (boundp sym))
    (is (eql 99 (symbol-value sym)))))

(test defonce-with-nil-value
  "defonce with nil as value sets the var to nil."
  (let ((sym (gensym "DEFONCE-TEST-NIL-")))
    (eval `(fol.compiler.misc-functions:defonce ,sym nil))
    ;; boundp should be true even though value is nil
    (is (boundp sym))
    (is (null (symbol-value sym)))))

(test defonce-idempotent-multiple-calls
  "Multiple defonce calls with different values only use the first."
  (let ((sym (gensym "DEFONCE-TEST-IDEM-")))
    (eval `(fol.compiler.misc-functions:defonce ,sym 1))
    (eval `(fol.compiler.misc-functions:defonce ,sym 2))
    (eval `(fol.compiler.misc-functions:defonce ,sym 3))
    (is (eql 1 (symbol-value sym)))))

;;; ===========================================================================
;;; intern tests
;;; ===========================================================================

(test intern-string-returns-symbol
  "intern with a string returns a symbol."
  (let ((sym (fol.compiler.misc-functions:intern "INTERN-TEST-SYM")))
    (is (symbolp sym))
    (is (equal "INTERN-TEST-SYM" (symbol-name sym)))))

(test intern-string-upcases
  "intern uppercases lowercase string names."
  (let ((sym (fol.compiler.misc-functions:intern "lowercase")))
    (is (equal "LOWERCASE" (symbol-name sym)))))

(test intern-symbol-argument
  "intern with a symbol argument returns a symbol with the same name."
  (let ((sym (fol.compiler.misc-functions:intern 'my-test-symbol)))
    (is (symbolp sym))
    (is (equal "MY-TEST-SYMBOL" (symbol-name sym)))))

(test intern-with-keyword-package
  "intern with :keyword package returns a keyword."
  (let ((sym (fol.compiler.misc-functions:intern "MY-KEYWORD" :keyword)))
    (is (keywordp sym))
    (is (eq :my-keyword sym))))

(test intern-with-cl-user-package
  "intern with :cl-user package puts symbol in CL-USER."
  (let ((sym (fol.compiler.misc-functions:intern "FOL-MISC-INTERN-TEST" :cl-user)))
    (is (symbolp sym))
    (is (eq (find-package :cl-user) (symbol-package sym)))))

(test intern-with-package-object
  "intern with a package object directly."
  (let ((sym (fol.compiler.misc-functions:intern "INTERN-PKG-OBJ-TEST"
                                                  (find-package :cl-user))))
    (is (symbolp sym))
    (is (eq (find-package :cl-user) (symbol-package sym)))))

(test intern-default-package-is-current
  "intern with no package argument uses *package*."
  (let* ((pkg (find-package :fol.compiler.tests))
         (sym (let ((*package* pkg))
                (fol.compiler.misc-functions:intern "INTERN-DEFAULT-PKG-TEST"))))
    (is (eq pkg (symbol-package sym)))))

(test intern-idempotent
  "Interning the same name twice returns the same symbol."
  (let ((sym1 (fol.compiler.misc-functions:intern "INTERN-IDEMPOTENT" :cl-user))
        (sym2 (fol.compiler.misc-functions:intern "INTERN-IDEMPOTENT" :cl-user)))
    (is (eq sym1 sym2))))
