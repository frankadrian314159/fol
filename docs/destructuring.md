# Destructuring

Destructuring allows you to bind names to parts of compound data structures in a single operation.
FOL supports destructuring in `bind` forms, function parameters (`fn`, `defn`), and macro parameters.

## Sequential Destructuring

Sequential destructuring works with ordered collections like vectors and lists.
Use a vector pattern to match elements by position.

### Basic Pattern

```fol
;; Bind a and b to the first two elements
(bind [[a b] [1 2 3]]
  (+ a b))                    ; => 3

;; Works with lists too
(bind [[a b] (list 1 2 3)]
  (+ a b))                    ; => 3
```

### Nested Patterns

Patterns can be nested to destructure nested structures.

```fol
(bind [[a [b c]] [1 [2 3]]]
  (+ a b c))                  ; => 6

(bind [[[a b] [c d]] [[1 2] [3 4]]]
  (+ a b c d))                ; => 10
```

### Rest Binding with &

Use `&` to capture remaining elements as a list.

```fol
(bind [[a b & rest] [1 2 3 4 5]]
  rest)                       ; => (3 4 5)

(bind [[first & rest] [1 2 3 4 5]]
  (size rest))                ; => 4

;; Rest can be empty
(bind [[a b & rest] [1 2]]
  rest)                       ; => ()
```

### Whole Binding with :as

Use `:as` to bind the entire collection while also destructuring it.

```fol
(bind [[a b :as all] [1 2 3 4 5]]
  (size all))                 ; => 5

(bind [[a b :as all] [1 2 3 4 5]]
  a)                          ; => 1

;; Combine :as with &
(bind [[a & rest :as all] [1 2 3]]
  all)                        ; => [1 2 3]
```

### Discarding with _

Use `_` to ignore elements you don't need.

```fol
;; Discard middle element
(bind [[a _ c] [1 2 3]]
  (+ a c))                    ; => 4

;; Discard first element
(bind [[_ b c] [1 2 3]]
  (+ b c))                    ; => 5

;; Multiple discards
(bind [[_ b _] [1 2 3]]
  b)                          ; => 2

;; Discard rest
(bind [[a & _] [1 2 3 4]]
  a)                          ; => 1
```

---

## Associative Destructuring

Associative destructuring works with maps (dicts). Use a map pattern to extract values by key.

### :keys Shorthand

The `:keys` keyword extracts values by keyword, binding them to variables of the same name.

```fol
(bind [{:keys [a b]} {:a 1 :b 2 :c 3}]
  (+ a b))                    ; => 3

(bind [{:keys [name age]} {:name "Alice" :age 30}]
  name)                       ; => "Alice"
```

### Explicit Key Mapping

Map variable names to specific keys when you want different names.

```fol
;; Bind x to :a, y to :b
(bind [{x :a y :b} {:a 1 :b 2}]
  (+ x y))                    ; => 3

;; Useful for renaming
(bind [{user-name :name user-age :age} {:name "Bob" :age 25}]
  user-name)                  ; => "Bob"
```

### Default Values with :or

Use `:or` to provide default values for missing keys.

```fol
;; b is missing, use default
(bind [{:keys [a b] :or {:a 10 :b 20}} {:a 1}]
  b)                          ; => 20

;; a is present, default ignored
(bind [{:keys [a b] :or {:a 10 :b 20}} {:a 1}]
  a)                          ; => 1

;; Both missing, both use defaults
(bind [{:keys [a b] :or {:a 10 :b 20}} {}]
  (+ a b))                    ; => 30

;; Works with explicit mapping too
(bind [{x :a :or {:x 99}} {}]
  x)                          ; => 99
```

### Whole Binding with :as

Use `:as` to bind the entire map while also destructuring it.

```fol
(bind [{:keys [a] :as m} {:a 1 :b 2}]
  (size m))                   ; => 2

(bind [{:keys [a] :as m} {:a 1 :b 2}]
  a)                          ; => 1
```

---

## Multiple Values

Sequential destructuring can capture Common Lisp multiple return values.

```fol
;; floor returns quotient and remainder as multiple values
(bind [[q r] (floor 17 3)]
  (+ q r))                    ; => 7 (5 + 2)

;; Extra values are ignored
(bind [[a b] (floor 17 3)]
  a)                          ; => 5

;; Capture all values with rest
(bind [[q & rest] (floor 17 3)]
  (first rest))               ; => 2
```

---

## Function Parameters

Destructuring works in function parameter lists.

### fn

```fol
;; Destructure single argument
((fn [[a b]] (+ a b)) [1 2])  ; => 3

;; Nested destructuring
((fn [[a [b c]]] (+ a b c)) [1 [2 3]])  ; => 6

;; With rest
((fn [[a & rest]] (size rest)) [1 2 3 4])  ; => 3

;; With :as
((fn [[a b :as all]] (size all)) [1 2 3 4])  ; => 4

;; Map destructuring
((fn [{:keys [a b]}] (+ a b)) {:a 1 :b 2})  ; => 3

;; Mixed simple and destructured params
((fn [x [a b]] (+ x a b)) 1 [2 3])  ; => 6
```

### defn

```fol
(defn sum-pair [[a b]]
  (+ a b))
(sum-pair [2 3])              ; => 5

(defn greet [{:keys [name greeting] :or {:greeting "Hello"}}]
  (str greeting ", " name "!"))
(greet {:name "World"})       ; => "Hello, World!"
```

---

## Macro Parameters

Destructuring also works in macro parameter lists, operating on the unevaluated forms.

```fol
;; Extract parts of a form
(defmacro debug-call [[op & args]]
  `(do
     (print "Calling" '~op "with" '~args)
     (~op ~@args)))

;; Macro sees the literal structure
(defmacro swap [[a b]]
  `[~b ~a])
(swap [1 2])                  ; => [2 1]
```

---

## Mixed Bindings

Regular bindings and destructuring can be mixed in the same `bind` form.

```fol
(bind [x 1
       [a b] [2 3]
       y 4]
  (+ x a b y))                ; => 10

(bind [config {:host "localhost" :port 8080}
       {:keys [host port]} config]
  (str host ":" port))        ; => "localhost:8080"
```

---

## Summary

| Pattern | Description | Example |
|---------|-------------|---------|
| `[a b]` | Positional binding | `[a b]` matches `[1 2]` |
| `[a b & rest]` | Rest binding | Captures remaining elements |
| `[a b :as all]` | Whole binding | Also binds entire collection |
| `[_ b _]` | Discard | Ignores unwanted elements |
| `{:keys [a b]}` | Key extraction | Binds by keyword name |
| `{x :a}` | Explicit mapping | Binds x to value at :a |
| `{:or {:a 1}}` | Defaults | Default for missing keys |
| `{:as m}` | Whole map | Also binds entire map |
