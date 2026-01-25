# Macros

FOL supports hygienic macros that receive unevaluated forms and return code to be evaluated.

---

## defmacro

```
;; Single-pattern form
(defmacro name [params] body...)

;; Multi-pattern form
(defmacro name
  ([params1] body1...)
  ([params2] body2...)
  ...)
```

Defines a macro. Macros receive unevaluated forms and return a new form to evaluate.

### Single-Pattern Examples

```fol
;; Simple macro
(defmacro unless [test & body]
  `(if (not ~test) (do ~@body)))

(unless false (print "executed"))  ; prints "executed"

;; With destructuring
(defmacro with-point [[x y] & body]
  `(bind [x ~x y ~y] ~@body))

(with-point [3 4]
  (+ x y))                ; => 7
```

### Multi-Pattern Examples

Multi-pattern macros dispatch based on arity (number of arguments) and pattern
structure. This allows a single macro to handle different numbers of arguments
or different argument types.

```fol
;; Dispatch by arity
(defmacro my-when
  ([test]                           ; 1 arg - just return nil
   nil)
  ([test form]                      ; 2 args - simple if
   `(if ~test ~form nil))
  ([test form & more]               ; 3+ args - wrap body in do
   `(if ~test (do ~form ~@more) nil)))

(my-when t)                         ; => nil
(my-when t 42)                      ; => 42
(my-when t 1 2 3)                   ; => 3

;; Dispatch by pattern structure (more specific patterns tried first)
(defmacro process
  ([x]                              ; matches any single arg
   `(quote ~x))
  ([[a b]]                          ; matches 2-element sequence
   `(+ ~a ~b)))

(process foo)                       ; => 'foo
(process (3 4))                     ; => 7

;; With rest parameters in some clauses
(defmacro make-items
  ([a]                              ; 1 item
   `(list ~a))
  ([a b]                            ; 2 items
   `(list ~a ~b))
  ([a b & more]                     ; 3+ items
   `(list ~a ~b ~@more)))

(make-items 1)                      ; => (1)
(make-items 1 2)                    ; => (1 2)
(make-items 1 2 3 4)                ; => (1 2 3 4)
```

### Pattern Dispatch Rules

1. **Arity matching**: Clauses are first filtered by the number of arguments
2. **Specificity**: Among same-arity clauses, more specific patterns are tried first:
   - `[[a b]]` (expects 2-element sequence) is more specific than `[x]` (matches anything)
   - Nested destructuring patterns are more specific than simple parameters
3. **Rest parameters**: Clauses with `& rest` match the specified arity and above

---

## quote

```
(quote form)
'form
```

Returns the form unevaluated. The reader macro `'` is shorthand for `quote`.

### Examples

```fol
(quote (+ 1 2))           ; => (+ 1 2) - the list, not 3
'(+ 1 2)                  ; => (+ 1 2) - same as above

(quote x)                 ; => x - the symbol
'x                        ; => x

'[1 2 3]                  ; => [1 2 3] - quoted vector
'{:a 1 :b 2}              ; => {:a 1 :b 2} - quoted map
```

---

## syntax-quote

```
`form
(syntax-quote form)
```

Quasiquote syntax for building code templates. Unlike `quote`, allows selective evaluation
using `~` (unquote) and `~@` (unquote-splicing). Also supports auto-gensym with `#` suffix.

### Unquote (~)

Evaluates the form and inserts the result:

```fol
(def x 42)
`(a ~x c)                 ; => (a 42 c)

(def name 'foo)
`(def ~name 10)           ; => (def foo 10)
```

### Unquote-splicing (~@)

Evaluates the form (must return a sequence) and splices elements into the list:

```fol
(def xs [1 2 3])
`(a ~@xs b)               ; => (a 1 2 3 b)

(def args ['x 'y])
`(fn ~args body)          ; => (fn [x y] body)
```

### Auto-gensym (#)

Symbols ending with `#` generate unique symbols, consistent within the same syntax-quote:

```fol
`(bind [x# 1] x#)         ; => (bind [G123 1] G123) - same gensym for both x#

;; Useful for hygienic macros
(defmacro with-temp [& body]
  `(bind [temp# (create-temp)]
     (try
       ~@body
       (finally (cleanup temp#)))))
```

### Complete Example

```fol
;; Macro using all features
(defmacro when-let [[var expr] & body]
  `(bind [result# ~expr]
     (when result#
       (bind [~var result#]
         ~@body))))

(when-let [x (get-value)]
  (print x)
  (* x 2))
```

---

## macroexpand-1

```
(macroexpand-1 form env)
```

Expands a macro call once. If `form` is a macro call, returns the expanded form.
Otherwise returns the form unchanged.

### Examples

```fol
;; Define a simple macro
(defmacro double [x]
  `(* 2 ~x))

;; Expand once
(macroexpand-1 '(double 5) env)   ; => (* 2 5)

;; Non-macro forms are unchanged
(macroexpand-1 '(+ 1 2) env)      ; => (+ 1 2)
```

---

## macroexpand

```
(macroexpand form env)
```

Repeatedly expands a form until it is no longer a macro call.

### Examples

```fol
;; Nested macros
(defmacro inner [x]
  `(+ ~x 1))

(defmacro outer [x]
  `(inner ~x))

;; macroexpand-1 expands one level
(macroexpand-1 '(outer 5) env)    ; => (inner 5)

;; macroexpand expands fully
(macroexpand '(outer 5) env)      ; => (+ 5 1)
```
