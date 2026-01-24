# Control Flow

## if

```
(if test then)
(if test then else)
```

Evaluates `test`. If truthy, evaluates and returns `then`.
Otherwise, evaluates and returns `else` (or nil if not provided).

### Examples

```fol
(if true "yes" "no")      ; => "yes"
(if false "yes" "no")     ; => "no"
(if (> 5 3) "bigger")     ; => "bigger"
(if (< 5 3) "smaller")    ; => nil
```

---

## when

```
(when test form0 form1 ... formN)
```

Evaluates `test`. If truthy, evaluates all forms in order and returns the value
of the last form. If falsy, returns nil without evaluating any forms.

This is a macro that expands to `(if test (do form0 form1 ... formN) nil)`.

### Examples

```fol
(when true
  (print "hello")
  42)                     ; prints "hello", returns 42

(when false
  (print "hello")
  42)                     ; returns nil, nothing printed

(when (> x 0)
  (print "positive")
  x)                      ; if x > 0, prints "positive" and returns x

;; Useful for side effects when a condition is true
(when (empty? errors)
  (save-data data)
  (print "Saved successfully"))
```

---

## unless

```
(unless test form0 form1 ... formN)
```

Evaluates `test`. If falsy, evaluates all forms in order and returns the value
of the last form. If truthy, returns nil without evaluating any forms.

This is a macro that expands to `(if test nil (do form0 form1 ... formN))`.

### Examples

```fol
(unless false
  (print "hello")
  42)                     ; prints "hello", returns 42

(unless true
  (print "hello")
  42)                     ; returns nil, nothing printed

(unless (> x 0)
  (print "non-positive")
  0)                      ; if x <= 0, prints "non-positive" and returns 0

;; Useful for error handling when a condition is false
(unless (valid? input)
  (log-error "Invalid input")
  (throw-error "validation failed"))
```

---

## do

```
(do form0 form1 ... formN)
```

Evaluates all forms in sequence and returns the value of the last form.
Returns nil if no forms are provided.

### Examples

```fol
(do
  (print "step 1")
  (print "step 2")
  42)                     ; prints both, returns 42

(do)                      ; => nil
```

---

## bind

```
(bind [bindings] body...)
```

Creates local bindings and evaluates body forms. Bindings are pairs of pattern and value.
Supports destructuring.

### Examples

```fol
(bind [x 1
       y 2]
  (+ x y))                ; => 3

;; Destructuring
(bind [[a b] [1 2]]
  (+ a b))                ; => 3

;; Sequential bindings (each sees previous)
(bind [x 1
       y (+ x 1)]
  y)                      ; => 2
```
