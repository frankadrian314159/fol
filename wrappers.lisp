(in-package fol.wrappers)




(defmethod make-load-form ((obj <bool>) &optional environment)
  (declare (ignore environment))
  (cond ((eq obj *true-instance*)  '*true-instance*)
        ((eq obj *false-instance*) '*false-instance*)
        (t (error "Cannot dump an anonymous <bool> instance."))))

(defun wrap-bool (obj)
  "Maps native Lisp T to *true-instance* and NIL to *false-instance*."
  (if obj *true-instance* *false-instance*))

(defun unwrap-bool (obj)
  "Extracts the raw boolean value from a FOL <bool> instance."
  (if (typep obj '<bool>)
      (fol-value obj)
      (error "Expected a FOL <bool> instance, got ~A" obj)))





(defun wrap-char (obj)
  "Wraps a native Lisp character into a FOL <char> instance."
  (if (characterp obj)
      (make-instance '<char> :val obj)
      (error "Expected a native character, got ~A" obj)))

(defun unwrap-char (obj)
  "Extracts the raw character value from a FOL <char> instance."
  (if (typep obj '<char>)
      (fol-value obj)
      (error "Expected a FOL <char> instance, got ~A" obj)))




;;; --- String Logic ---

(defun wrap-string (obj)
  "Wraps a native Lisp string into a FOL <string> instance."
  (if (stringp obj)
      (make-instance '<string> :val obj)
      (error "Expected a native string, got ~A" obj)))

(defun unwrap-string (obj)
  "Extracts the raw string value from a FOL <string> instance."
  (if (typep obj '<string>)
      (fol-value obj)
      (error "Expected a FOL <string> instance, got ~A" obj)))




;;; --- Symbol Logic ---

(defun wrap-symbol (obj &optional module-name (value nil value-supplied-p))
  "Wraps a native Lisp symbol into a FOL <symbol> or <keyword> instance.
   Keywords are wrapped as <keyword>, other symbols as <symbol>.
   Optionally accepts a module-name (string) and value to associate with the symbol."
  (if (symbolp obj)
      (let ((class-name (if (keywordp obj) '<keyword> '<symbol>)))
        (if value-supplied-p
            (make-instance class-name :val obj :module-name module-name :value value)
            (make-instance class-name :val obj :module-name module-name)))
      (error "Expected a native symbol, got ~A" obj)))

(defun unwrap-symbol (obj)
  "Extracts the raw symbol value from a FOL <symbol> instance."
  (if (typep obj '<symbol>)
      (fol-value obj)
      (error "Expected a FOL <symbol> instance, got ~A" obj)))
      
      
      
      
(defun wrap-number (obj)
  (cond
    ((typep obj 'fixnum) (make-instance '<fixnum> :val obj))
    ((typep obj 'bignum) (make-instance '<bignum> :val obj))
    ;((typep obj 'integer) (make-instance '<integer> :val obj))
    ((typep obj 'single-float)   (make-instance '<single-float> :val obj))
    ((typep obj 'double-float)   (make-instance '<double-float> :val obj))
    ;((typep obj 'float)   (make-instance '<float> :val obj))
    ((typep obj 'ratio) (make-instance '<ratio> :val obj))
    ;((typep obj 'rational) (make-instance '<rational> :val obj))
    ;((typep obj 'real) (make-instance '<real> :val obj))
    ((typep obj 'complex) (make-instance '<complex> :val obj))
    ((typep obj 'number) (make-instance '<number> :val obj))
    (t (error "Invalid native number type: ~A" obj))))

(defun unwrap-number (obj)
  "Extracts the raw value from a FOL number instance."
  (if (typep obj '<number>)
      (fol-value obj)
      (error "Expected a FOL <number> instance, got ~A" obj)))






(defun unwrap (obj)
  (cond
    ((typep obj '<bool>) (fol.classes:fol-value obj))
    ((typep obj '<char>)   (fol-value obj))
    ((typep obj '<string>) (fol-value obj))
    ((typep obj '<symbol>) (fol-value obj))
    ((typep obj '<number>) (fol-value obj))
    ((or (typep obj 'boolean)
         (characterp obj)
         (stringp obj)
         (symbolp obj)
         (numberp obj)) obj) ; Return native values as-is
    (t (error "Object ~A cannot be unwrapped." obj))))

(defun wrap (obj)
  (cond
    ((typep obj 'boolean) (wrap-bool obj))
    ((characterp obj)     (wrap-char obj))
    ((stringp obj)        (wrap-string obj))
    ((symbolp obj)        (wrap-symbol obj))
    ((numberp obj)        (wrap-number obj))
    ; Already wrapped objects
    ((typep obj '<bool>)   obj)
    ((typep obj '<char>)   obj)
    ((typep obj '<string>) obj)
    ((typep obj '<symbol>) obj) 
    ((typep obj '<number>) obj)
    (t (error "Object ~A cannot be wrapped." obj))))