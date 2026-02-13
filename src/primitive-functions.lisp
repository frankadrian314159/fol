;;; FOL Compiler - Primitive Functions
;;;
;;; Standard library predicates and utility functions for FOL programs.
;;; These functions provide common predicates modeled after Clojure.

(in-package :fol.compiler.primitive-functions)

;;; ---------------------------------------------------------------------------
;;; Nil and Boolean Predicates
;;; ---------------------------------------------------------------------------

(defun nil? (obj)
  "Returns true if OBJ is nil, false otherwise.

   Examples:
     (nil? nil)    => T
     (nil? false)  => T  ; nil and false are the same
     (nil? 0)      => NIL
     (nil? \"\")    => NIL"
  (null obj))

(defun some? (obj)
  "Returns true if OBJ is not nil, false otherwise.
   Opposite of nil?.

   Examples:
     (some? 42)     => T
     (some? \"\")     => T
     (some? nil)    => NIL
     (some? false)  => NIL"
  (not (null obj)))

(defun boolean? (obj)
  "Returns true if OBJ is a boolean (T or NIL).

   Examples:
     (boolean? t)      => T
     (boolean? nil)    => T
     (boolean? 1)      => NIL
     (boolean? \"yes\") => NIL"
  (typep obj 'boolean))

(defun true? (obj)
  "Returns true if OBJ is exactly T (true).
   Does not use generalized boolean semantics.

   Examples:
     (true? t)    => T
     (true? 1)    => NIL
     (true? nil)  => NIL"
  (eq obj t))

(defun false? (obj)
  "Returns true if OBJ is NIL (false).

   Examples:
     (false? nil)    => T
     (false? false)  => T  ; nil and false are the same
     (false? 0)      => NIL
     (false? \"\")     => NIL"
  (null obj))

;;; ---------------------------------------------------------------------------
;;; Collection Predicates
;;; ---------------------------------------------------------------------------

(defun seq? (obj)
  "Returns true if OBJ is a sequence (list, vector, string).

   Examples:
     (seq? '(1 2 3))     => T
     (seq? #(1 2 3))     => T
     (seq? \"hello\")     => T
     (seq? 42)           => NIL"
  (typep obj 'sequence))

(defun coll? (obj)
  "Returns true if OBJ is a collection (sequence or hash-table).

   Examples:
     (coll? '(1 2 3))          => T
     (coll? #(1 2 3))          => T
     (coll? (make-hash-table)) => T
     (coll? 42)                => NIL"
  (or (typep obj 'sequence)
      (typep obj 'hash-table)))

(defun map? (obj)
  "Returns true if OBJ is a map/dictionary (hash-table).

   Examples:
     (map? (make-hash-table))  => T
     (map? '((a . 1) (b . 2))) => NIL
     (map? #(1 2 3))           => NIL"
  (typep obj 'hash-table))

(defun vector? (obj)
  "Returns true if OBJ is a vector.

   Examples:
     (vector? #(1 2 3))  => T
     (vector? '(1 2 3))  => NIL"
  (typep obj 'vector))

(defun list? (obj)
  "Returns true if OBJ is a list (cons or nil).

   Examples:
     (list? '(1 2 3))  => T
     (list? nil)       => T
     (list? #(1 2 3))  => NIL"
  (listp obj))

;;; ---------------------------------------------------------------------------
;;; Type Checking Functions
;;; ---------------------------------------------------------------------------

(defun keyword? (obj)
  "Returns true if OBJ is a keyword.

   Examples:
     (keyword? :foo)  => T
     (keyword? 'foo)  => NIL"
  (keywordp obj))

(defun symbol? (obj)
  "Returns true if OBJ is a symbol.

   Examples:
     (symbol? 'foo)   => T
     (symbol? :foo)   => T  ; keywords are symbols
     (symbol? \"foo\")  => NIL"
  (symbolp obj))

(defun symbol (name)
  "Create a symbol from a string name. Interns in the current package.

   Examples:
     (symbol \"foo\")  => FOO
     (symbol \"BAR\")  => BAR"
  (intern (string name)))

(defun string? (obj)
  "Returns true if OBJ is a string.

   Examples:
     (string? \"hello\")  => T
     (string? 'hello)    => NIL"
  (stringp obj))

(defun char? (obj)
  "Returns true if OBJ is a character.

   Examples:
     (char? #\\a)      => T
     (char? \"a\")      => NIL"
  (characterp obj))

(defun number? (obj)
  "Returns true if OBJ is a number.

   Examples:
     (number? 42)      => T
     (number? 3.14)    => T
     (number? \"42\")    => NIL"
  (numberp obj))

(defun integer? (obj)
  "Returns true if OBJ is an integer.

   Examples:
     (integer? 42)    => T
     (integer? 3.14)  => NIL"
  (integerp obj))

(defun float? (obj)
  "Returns true if OBJ is a floating-point number.

   Examples:
     (float? 3.14)  => T
     (float? 42)    => NIL"
  (floatp obj))

(defun rational? (obj)
  "Returns true if OBJ is a rational number.

   Examples:
     (rational? 42)      => T
     (rational? 1/2)     => T
     (rational? 3.14)    => NIL"
  (rationalp obj))

(defun fn? (obj)
  "Returns true if OBJ is a function.

   Examples:
     (fn? #'car)           => T
     (fn? (lambda (x) x))  => T
     (fn? 'car)            => NIL"
  (functionp obj))

;;; ---------------------------------------------------------------------------
;;; Equality Functions
;;; ---------------------------------------------------------------------------

(defun identical? (x y)
  "Returns true if X and Y are the same object (pointer equality).
   Uses EQ for comparison.

   Examples:
     (identical? :foo :foo)  => T
     (let ((x '(1 2)))
       (identical? x x))     => T
     (identical? '(1 2) '(1 2))  => NIL  ; different cons cells"
  (eq x y))

(defun =? (x y)
  "Returns true if X and Y are equal in value.
   Uses EQUAL for comparison (works for strings, lists, etc.).

   Examples:
     (=? \"hello\" \"hello\")    => T
     (=? '(1 2) '(1 2))       => T
     (=? 42 42)               => T"
  (equal x y))
