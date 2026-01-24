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

---

## cond

```
(cond test1 form1 test2 form2 ... testN formN)
```

Evaluates test/form pairs in order. When a test evaluates to a truthy value,
evaluates and returns the corresponding form. If no test is truthy, returns nil.

Requires an even number of arguments (test/form pairs).

### Examples

```fol
(cond
  (< x 0) :negative
  (= x 0) :zero
  (> x 0) :positive)      ; returns based on value of x

(cond
  false :never
  nil :also-never
  true :always)           ; => :always

;; Default case using t
(cond
  (= n 1) :one
  (= n 2) :two
  t :other)               ; returns :other if n is not 1 or 2

;; No match returns nil
(cond
  false :a
  nil :b)                 ; => nil
```

---

## case

```
(case target-form
  target1 form1
  target2 form2
  ...
  [default-form])
```

Evaluates `target-form` to get a value, then matches against targets.
Each target can be an atom (number, string, keyword, symbol) or a vector of atoms.
When matched, evaluates and returns the corresponding form.

If no match is found:
- If a default form is provided (odd number of remaining args), evaluates and returns it
- Otherwise, signals an error

Duplicate targets cause an error at evaluation time.

### Examples

```fol
;; Simple matching
(case x
  1 :one
  2 :two
  3 :three
  :unknown)               ; default if x is not 1, 2, or 3

;; Vector of targets (matches any)
(case day
  [0 6] :weekend
  [1 2 3 4 5] :weekday)   ; 0 or 6 => :weekend, 1-5 => :weekday

;; String keys
(case major
  "engineering" (values 60000 :engineering)
  "business" (values 90000 :management)
  (values 20000 :production))  ; default

;; Game of Life neighbor rule
(case neighbor-count
  [0 1] :dies             ; underpopulation
  2 :survives             ; stable
  3 :births               ; reproduction
  [4 5 6 7 8] :dies)      ; overpopulation

;; No default - signals error if no match
(case status
  :active :process
  :pending :queue)        ; error if status is neither

;; Evaluates target expression
(case (+ 1 2)
  1 :one
  2 :two
  3 :three)               ; => :three
```
