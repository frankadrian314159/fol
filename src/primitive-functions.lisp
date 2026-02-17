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

(defun <bool>? (obj)
  "Returns true if OBJ is a boolean (T or NIL).

   Examples:
     (<bool>? t)      => T
     (<bool>? nil)    => T
     (<bool>? 1)      => NIL
     (<bool>? \"yes\") => NIL"
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
     (false? 0)      => NIL
     (false? \"\")     => NIL"
  (null obj))

(defun instance? (class obj)
  "Returns true if OBJ is an instance of CLASS.
   CLASS may be a class object or a type specifier symbol.

   Examples:
     (instance? 'number 42)                                    => T
     (instance? 'string \"hello\")                             => T
     (instance? 'fol.compiler.collections:<vector>
                (vector 1 2 3))                                => T
     (instance? 'number \"hello\")                             => NIL"
  (typep obj class))

;;; ---------------------------------------------------------------------------
;;; Collection Predicates
;;; ---------------------------------------------------------------------------

(defun <seq>? (obj)
  "Returns true if OBJ is a FOL collection.

   Examples:
     (<seq>? (vector 1 2 3))     => T
     (<seq>? (dict :a 1))        => T
     (<seq>? (set 1 2 3))        => T
     (<seq>? 42)                 => NIL"
  (typep obj 'fol.compiler.collections:<collection>))

(defun <collection>? (obj)
  "Returns true if OBJ is a FOL collection.

   Examples:
     (<collection>? (vector 1 2 3))     => T
     (<collection>? (dict :a 1))        => T
     (<collection>? (set 1 2 3))        => T
     (<collection>? 42)                 => NIL"
  (typep obj 'fol.compiler.collections:<collection>))

(defun <dict>? (obj)
  "Returns true if OBJ is a FOL dict.

   Examples:
     (<dict>? (dict :a 1 :b 2))     => T
     (<dict>? (ordered-dict :a 1))  => T
     (<dict>? (vector 1 2 3))       => NIL
     (<dict>? 42)                   => NIL"
  (typep obj 'fol.compiler.collections:<dict>))

(defun <vector>? (obj)
  "Returns true if OBJ is a FOL vector.

   Examples:
     (<vector>? (vector 1 2 3))     => T
     (<vector>? (dict :a 1))        => NIL
     (<vector>? '(1 2 3))           => NIL"
  (typep obj 'fol.compiler.collections:<vector>))

(defun <list>? (obj)
  "Returns true if OBJ is a FOL list.

   Examples:
     (<list>? (make 'fol.compiler.collections:<list> 1 2 3))     => T
     (<list>? (vector 1 2 3))                                     => NIL
     (<list>? '(1 2 3))                                           => NIL"
  (typep obj 'fol.compiler.collections:<list>))

(defun <lazy-seq>? (obj)
  "Returns true if OBJ is a FOL lazy sequence.

   Examples:
     (<lazy-seq>? (make 'fol.compiler.collections:<lazy-seq>))   => T
     (<lazy-seq>? (vector 1 2 3))                                 => NIL"
  (typep obj 'fol.compiler.collections:<lazy-seq>))

(defun <deque>? (obj)
  "Returns true if OBJ is a FOL deque.

   Examples:
     (<deque>? (make 'fol.compiler.collections:<deque>))         => T
     (<deque>? (vector 1 2 3))                                    => NIL"
  (typep obj 'fol.compiler.collections:<deque>))

(defun <unordered-collection>? (obj)
  "Returns true if OBJ is a FOL unordered collection.

   Examples:
     (<unordered-collection>? (set 1 2 3))      => T
     (<unordered-collection>? (dict :a 1))      => T
     (<unordered-collection>? (vector 1 2 3))   => NIL"
  (typep obj 'fol.compiler.collections:<unordered-collection>))

(defun <ordered-collection>? (obj)
  "Returns true if OBJ is a FOL ordered collection.

   Examples:
     (<ordered-collection>? (vector 1 2 3))     => T
     (<ordered-collection>? (dict :a 1))        => NIL"
  (typep obj 'fol.compiler.collections:<ordered-collection>))

(defun <ordered-dict>? (obj)
  "Returns true if OBJ is a FOL ordered-dict.

   Examples:
     (<ordered-dict>? (ordered-dict :a 1 :b 2))   => T
     (<ordered-dict>? (dict :a 1))                => NIL"
  (typep obj 'fol.compiler.collections:<ordered-dict>))

(defun <array-dict>? (obj)
  "Returns true if OBJ is a FOL array-dict.

   Examples:
     (<array-dict>? (array-dict :a 1 :b 2))     => T
     (<array-dict>? (dict :a 1))                => NIL"
  (typep obj 'fol.compiler.collections:<array-dict>))

(defun <sorted-dict>? (obj)
  "Returns true if OBJ is a FOL sorted-dict.

   Examples:
     (<sorted-dict>? (sorted-dict nil :a 1))    => T
     (<sorted-dict>? (dict :a 1))               => NIL"
  (typep obj 'fol.compiler.collections:<sorted-dict>))

(defun <int-dict>? (obj)
  "Returns true if OBJ is a FOL int-dict.

   Examples:
     (<int-dict>? (int-dict 1 :a 2 :b))         => T
     (<int-dict>? (dict :a 1))                  => NIL"
  (typep obj 'fol.compiler.collections:<int-dict>))

(defun <priority-dict>? (obj)
  "Returns true if OBJ is a FOL priority-dict.

   Examples:
     (<priority-dict>? (priority-dict :a 10 :b 20))   => T
     (<priority-dict>? (dict :a 1))                   => NIL"
  (typep obj 'fol.compiler.collections:<priority-dict>))

(defun <set>? (obj)
  "Returns true if OBJ is a FOL set.

   Examples:
     (<set>? (set 1 2 3))          => T
     (<set>? (vector 1 2 3))       => NIL"
  (typep obj 'fol.compiler.collections:<set>))

(defun <ordered-set>? (obj)
  "Returns true if OBJ is a FOL ordered-set.

   Examples:
     (<ordered-set>? (ordered-set 1 2 3))     => T
     (<ordered-set>? (set 1 2 3))             => NIL"
  (typep obj 'fol.compiler.collections:<ordered-set>))

(defun <sorted-set>? (obj)
  "Returns true if OBJ is a FOL sorted-set.

   Examples:
     (<sorted-set>? (sorted-set nil 1 2 3))   => T
     (<sorted-set>? (set 1 2 3))              => NIL"
  (typep obj 'fol.compiler.collections:<sorted-set>))

(defun <int-set>? (obj)
  "Returns true if OBJ is a FOL int-set.

   Examples:
     (<int-set>? (int-set 1 2 3))             => T
     (<int-set>? (set 1 2 3))                 => NIL"
  (typep obj 'fol.compiler.collections:<int-set>))

(defun <dense-int-set>? (obj)
  "Returns true if OBJ is a FOL dense-int-set.

   Examples:
     (<dense-int-set>? (dense-int-set 1 2 3))   => T
     (<dense-int-set>? (set 1 2 3))             => NIL"
  (typep obj 'fol.compiler.collections:<dense-int-set>))

(defun <bag>? (obj)
  "Returns true if OBJ is a FOL bag (multiset).

   Examples:
     (<bag>? (bag 1 1 2 3))        => T
     (<bag>? (set 1 2 3))          => NIL"
  (typep obj 'fol.compiler.collections:<bag>))

(defun map-entry? (obj)
  "Returns true if OBJ is a map entry (a cons cell representing a key-value pair).
   In FOL, dict entries from collection-seq are cons pairs (key . value).

   Examples:
     (map-entry? (cons :a 1))           => T
     (map-entry? (cons \"name\" 42))    => T
     (map-entry? [1 2])                 => NIL
     (map-entry? 42)                    => NIL
     (map-entry? nil)                   => NIL"
  (consp obj))

;;; ---------------------------------------------------------------------------
;;; Collection Category Predicates
;;; ---------------------------------------------------------------------------

(defun sequential? (obj)
  "Returns true if OBJ is a sequential collection (list, vector, deque,
   or lazy-seq, including subtypes such as array).

   Examples:
     (sequential? (vector 1 2 3))                       => T
     (sequential? (make 'fol.compiler.collections:<list> 1 2))  => T
     (sequential? (make 'fol.compiler.collections:<deque> 1))   => T
     (sequential? (dict :a 1))                           => NIL
     (sequential? (set 1 2 3))                           => NIL"
  (or (typep obj 'fol.compiler.collections:<vector>)
      (typep obj 'fol.compiler.collections:<list>)
      (typep obj 'fol.compiler.collections:<deque>)
      (typep obj 'fol.compiler.collections:<lazy-seq>)))

(defun associative? (obj)
  "Returns true if OBJ is an associative collection (vector or dict,
   including all subtypes such as array, ordered-dict, sorted-dict, etc.).

   Examples:
     (associative? (vector 1 2 3))          => T
     (associative? (dict :a 1))             => T
     (associative? (sorted-dict nil :a 1))  => T
     (associative? (set 1 2 3))             => NIL"
  (or (typep obj 'fol.compiler.collections:<vector>)
      (typep obj 'fol.compiler.collections:<dict>)))

(defun sorted? (obj)
  "Returns true if OBJ is a sorted collection (sorted-dict or sorted-set,
   including subtypes such as int-dict and int-set).

   Examples:
     (sorted? (sorted-dict nil :a 1))       => T
     (sorted? (int-dict 1 :a 2 :b))        => T
     (sorted? (sorted-set nil 1 2 3))      => T
     (sorted? (int-set 1 2 3))             => T
     (sorted? (dict :a 1))                 => NIL
     (sorted? (set 1 2 3))                 => NIL"
  (or (typep obj 'fol.compiler.collections:<sorted-dict>)
      (typep obj 'fol.compiler.collections:<sorted-set>)))

(defun counted? (obj)
  "Returns true if OBJ is a counted collection (any subtype of <collection>).

   Examples:
     (counted? (vector 1 2 3))      => T
     (counted? (dict :a 1))         => T
     (counted? (set 1 2 3))         => T
     (counted? 42)                  => NIL
     (counted? nil)                 => NIL"
  (typep obj 'fol.compiler.collections:<collection>))

(defun reversible? (obj)
  "Returns true if OBJ is a reversible collection (vector, sorted-dict,
   or sorted-set, including subtypes such as array, int-dict, int-set).

   Examples:
     (reversible? (vector 1 2 3))          => T
     (reversible? (sorted-dict nil :a 1))  => T
     (reversible? (sorted-set nil 1 2 3))  => T
     (reversible? (dict :a 1))             => NIL
     (reversible? (set 1 2 3))             => NIL"
  (or (typep obj 'fol.compiler.collections:<vector>)
      (typep obj 'fol.compiler.collections:<sorted-dict>)
      (typep obj 'fol.compiler.collections:<sorted-set>)))

;;; ---------------------------------------------------------------------------
;;; Type Checking Functions
;;; ---------------------------------------------------------------------------

(defun <keyword>? (obj)
  "Returns true if OBJ is a keyword.

   Examples:
     (<keyword>? :foo)  => T
     (<keyword>? 'foo)  => NIL"
  (keywordp obj))

(defun <symbol>? (obj)
  "Returns true if OBJ is a symbol.

   Examples:
     (<symbol>? 'foo)   => T
     (<symbol>? :foo)   => T  ; keywords are symbols
     (<symbol>? \"foo\")  => NIL"
  (symbolp obj))

(defun symbol (name)
  "Create a symbol from a string name. Interns in the current package.

   Examples:
     (symbol \"foo\")  => FOO
     (symbol \"BAR\")  => BAR"
  (intern (string-upcase (string name))))

(defun keyword (name)
  "Create a keyword symbol from a string name.

   Examples:
     (keyword \"foo\")  => :FOO
     (keyword \"bar\")  => :BAR"
  (intern (string-upcase (string name)) :keyword))

(defun find-keyword (name)
  "Find or create a keyword from a string, symbol, or keyword.
   If given a keyword, returns it unchanged (idempotent).
   If given a symbol or string, converts to keyword.

   Examples:
     (find-keyword \"foo\")   => :FOO
     (find-keyword 'foo)     => :FOO
     (find-keyword :foo)     => :FOO"
  (etypecase name
    (cl:keyword name)
    ((or cl:symbol string) (intern (string-upcase (string name)) :keyword))))

(defun gensym (&optional (prefix "G"))
  "Generate a unique uninterned symbol with optional PREFIX.
   Each call returns a new symbol that is guaranteed to be unique.

   Examples:
     (gensym)        => #:G1234
     (gensym \"X\")   => #:X5678
     (gensym 'temp)  => #:TEMP9012"
  (cl:gensym (string prefix)))

(defun <string>? (obj)
  "Returns true if OBJ is a string.

   Examples:
     (<string>? \"hello\")  => T
     (<string>? 'hello)    => NIL"
  (stringp obj))

(defun <char>? (obj)
  "Returns true if OBJ is a character.

   Examples:
     (<char>? #\\a)      => T
     (<char>? \"a\")      => NIL"
  (characterp obj))

(defun <number>? (obj)
  "Returns true if OBJ is a number.

   Examples:
     (<number>? 42)      => T
     (<number>? 3.14)    => T
     (<number>? \"42\")    => NIL"
  (numberp obj))

(defun <integer>? (obj)
  "Returns true if OBJ is an integer.

   Examples:
     (<integer>? 42)    => T
     (<integer>? 3.14)  => NIL"
  (integerp obj))

(defun <float>? (obj)
  "Returns true if OBJ is a floating-point number.

   Examples:
     (<float>? 3.14)  => T
     (<float>? 42)    => NIL"
  (floatp obj))

(defun <rational>? (obj)
  "Returns true if OBJ is a rational number.

   Examples:
     (<rational>? 42)      => T
     (<rational>? 1/2)     => T
     (<rational>? 3.14)    => NIL"
  (rationalp obj))

(defun <real>? (obj)
  "Returns true if OBJ is a real number (rational or float).

   Examples:
     (<real>? 42)      => T
     (<real>? 1/2)     => T
     (<real>? 3.14)    => T
     (<real>? #C(1 2)) => NIL"
  (realp obj))

(defun <ratio>? (obj)
  "Returns true if OBJ is a ratio (non-integer rational).

   Examples:
     (<ratio>? 1/2)    => T
     (<ratio>? 3/4)    => T
     (<ratio>? 42)     => NIL
     (<ratio>? 3.14)   => NIL"
  (typep obj 'ratio))

(defun <complex>? (obj)
  "Returns true if OBJ is a complex number.

   Examples:
     (<complex>? #C(1 2))    => T
     (<complex>? #C(3.0 4.0)) => T
     (<complex>? 42)         => NIL
     (<complex>? 3.14)       => NIL"
  (complexp obj))

(defun <single-float>? (obj)
  "Returns true if OBJ is a single-precision floating-point number.

   Examples:
     (<single-float>? 3.14f0)  => T
     (<single-float>? 3.14d0)  => NIL
     (<single-float>? 42)      => NIL"
  (typep obj 'single-float))

(defun <double-float>? (obj)
  "Returns true if OBJ is a double-precision floating-point number.

   Examples:
     (<double-float>? 3.14d0)  => T
     (<double-float>? 3.14f0)  => NIL
     (<double-float>? 42)      => NIL"
  (typep obj 'double-float))

(defun <fixnum>? (obj)
  "Returns true if OBJ is a fixnum (small integer).

   Examples:
     (<fixnum>? 42)              => T (on most platforms)
     (<fixnum>? 1000000000000)   => NIL (bignum on most platforms)
     (<fixnum>? 3.14)            => NIL"
  (typep obj 'fixnum))

(defun <bignum>? (obj)
  "Returns true if OBJ is a bignum (large integer).

   Examples:
     (<bignum>? 1000000000000)   => T (on most platforms)
     (<bignum>? 42)              => NIL (fixnum on most platforms)
     (<bignum>? 3.14)            => NIL"
  (typep obj 'bignum))

(defun <fn>? (obj)
  "Returns true if OBJ is a function.

   Examples:
     (<fn>? #'car)           => T
     (<fn>? (lambda (x) x))  => T
     (<fn>? 'car)            => NIL"
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

(defgeneric equal? (a b)
  (:documentation "Returns true if A and B are equal in value.
  Supports custom equality for FOL collections."))

(defmethod equal? (a b)
  (equal a b))

(defmethod equal? ((a fol.compiler.collections:<collection>) (b fol.compiler.collections:<collection>))
  (and (= (fol.compiler.collections:collection-size a)
          (fol.compiler.collections:collection-size b))
       (equal? (fol.compiler.collections:collection-seq a)
               (fol.compiler.collections:collection-seq b))))
    
(defmethod equal? ((a cons) (b cons))
   (and (equal? (car a) (car b))
        (equal? (cdr a) (cdr b))))

(defun =? (x y)
  "Returns true if X and Y are equal in value.
   Uses equal? generic function for extensible equality.

   Examples:
     (=? \"hello\" \"hello\")    => T
     (=? '(1 2) '(1 2))       => T
     (=? 42 42)               => T"
  (equal? x y))

(defun zero? (x)
  "Returns true if X is zero.

   Examples:
     (zero? 0)       => T
     (zero? 1)       => NIL
     (zero? 0.0)     => T"
  (zerop x))

(defun odd? (x)
  "Returns true if X is an odd integer.

   Examples:
     (odd? 3)       => T
     (odd? 4)       => NIL
     (odd? -1)      => T"
  (oddp x))

(defun even? (x)
  "Returns true if X is an even integer.

   Examples:
     (even? 4)      => T
     (even? 3)      => NIL
     (even? 0)      => T"
  (evenp x))
