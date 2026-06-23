# FOL Language Manual

FOL (Functional Object Lisp) is a Lisp dialect that combines Clojure's persistent data structures with CLOS-style class-based object orientation and a Dylan-inspired module system. Every value in FOL is an object, backed by persistent data structures that support efficient structural sharing.

For the design rationale, synergy patterns, and benchmarks, see the companion paper:

> Frank Adrian. "FOL: A Functional Object Lisp." *European Lisp Symposium*, 2026.

---

## Table of Contents

1. [Primitive Types](#1-primitive-types)
2. [Collections](#2-collections)
3. [Destructuring](#3-destructuring)
4. [Special Forms](#4-special-forms)
5. [Control Flow](#5-control-flow)
6. [Arithmetic](#6-arithmetic)
7. [Comparison](#7-comparison)
8. [Logical Operations](#8-logical-operations)
9. [Predicates](#9-predicates)
10. [Sequence Operations](#10-sequence-operations)
11. [List Operations](#11-list-operations)
12. [String Functions](#12-string-functions)
13. [Character Functions](#13-character-functions)
14. [Regular Expressions](#14-regular-expressions)
15. [Bitwise Operations](#15-bitwise-operations)
16. [Functional Programming](#16-functional-programming)
17. [Generic Functions and Object System](#17-generic-functions-and-object-system)
18. [Meta-Object Protocol](#18-meta-object-protocol)
19. [Macros](#19-macros)
20. [Exception Handling](#20-exception-handling)
21. [Zippers](#21-zippers)
22. [Array Programming](#22-array-programming)
23. [Miscellaneous](#23-miscellaneous)

---

# 1. Primitive Types

FOL provides persistent wrapper classes for all primitive values. Every primitive inherits from `<persistent-object>` and participates in FOL's persistent storage system.

## Boolean - `<bool>`

The boolean class wraps native Lisp booleans.

### Literals

```fol
t       ; => true
nil     ; => false/nil
```

### Predicate

```fol
(<bool>? t)        ; => true
(<bool>? nil)      ; => true
(<bool>? 0)        ; => false
```

---

## Character - `<char>`

The character class wraps native Lisp characters.

### Literals

```fol
\a            ; lowercase a
\A            ; uppercase A
\newline      ; newline character
\space        ; space character
\tab          ; tab character
\return       ; carriage return
\backspace    ; backspace
\formfeed     ; form feed
\u0041        ; Unicode character (A)
```

### Predicate

```fol
(<char>? \a)        ; => true
(<char>? \newline)  ; => true
(<char>? "a")       ; => false (string, not char)
```

### Functions

| Function | Description |
|----------|-------------|
| `char-name-string` | Returns the name of a character as a string |
| `int` | Converts a character to its character code |

### Examples

```fol
(char-name-string \newline)  ; => "NEWLINE"
(int \A)                     ; => 65
```

---

## String - `<string>`

The string class wraps native Lisp strings. Strings are immutable sequences of characters.

### Literals

```fol
"hello"           ; simple string
"line1\nline2"    ; string with escape sequences
""                ; empty string
```

### Predicate

```fol
(<string>? "hello")  ; => true
(<string>? "")       ; => true
(<string>? 'hello)   ; => false
```

### String Functions

| Function | Description |
|----------|-------------|
| `str` | Concatenate values into a string |
| `blank?` | Returns true if string is nil, empty, or only whitespace |
| `trim` | Remove leading and trailing whitespace |
| `triml` | Remove leading whitespace |
| `trimr` | Remove trailing whitespace |
| `trim-newline` | Remove trailing newlines |
| `capitalize` | Capitalize the first character |
| `upper-case` | Convert to uppercase |
| `lower-case` | Convert to lowercase |
| `starts-with?` | Check if string starts with prefix |
| `ends-with?` | Check if string ends with suffix |
| `includes?` | Check if string contains substring |
| `replace` | Replace all occurrences of a pattern |
| `replace-first` | Replace first occurrence of a pattern |
| `join` | Join collection elements with separator |
| `escape` | Escape special characters |
| `split` | Split string by pattern |
| `split-lines` | Split string into lines |

### Examples

```fol
(str "Hello, " "world!")        ; => "Hello, world!"
(blank? "  ")                   ; => true
(trim "  hello  ")              ; => "hello"
(starts-with? "hello" "he")     ; => true
(split "a,b,c" ",")             ; => ["a" "b" "c"]
```

See [Section 12: String Functions](#12-string-functions) for the complete API.

---

## Regular Expression Pattern - `<re-pattern>`

A regular expression pattern that inherits from `<string>`.

### Literal Syntax

```fol
#"pattern"        ; regex pattern literal
#"[a-z]+"         ; matches one or more lowercase letters
#"(?i)hello"      ; case-insensitive match
```

### Functions

| Function | Description |
|----------|-------------|
| `re-pattern` | Create a regex pattern from a string |
| `re-find` | Find first match of pattern in string |
| `re-seq` | Return lazy sequence of all matches |
| `re-scanner` | Create a compiled scanner for repeated use |

### Examples

```fol
(re-find #"\d+" "abc123def")     ; => "123"
(re-seq #"\d+" "a1b2c3")         ; => ("1" "2" "3")
```

See [Section 14: Regular Expressions](#14-regular-expressions) for the complete API.

---

## Symbol - `<symbol>`

Symbols have a name, an optional module name, and an optional associated value.

### Literals

```fol
foo           ; unquoted symbol (evaluated)
'foo          ; quoted symbol (literal)
my-var        ; hyphenated symbol name
```

### Predicate

```fol
(<symbol>? 'hello)    ; => true
(<symbol>? :keyword)  ; => true (keywords are symbols)
(<symbol>? "hello")   ; => false
```

### Functions

| Function | Description |
|----------|-------------|
| `symbol` | Create a symbol from a string |
| `gensym` | Generate a unique symbol |

### Examples

```fol
(symbol "my-name")    ; => my-name
(gensym)              ; => G__1234 (unique each time)
(gensym "prefix")     ; => prefix1234
```

---

## Keyword - `<keyword>`

Keywords are self-evaluating symbols that start with a colon. They inherit from `<symbol>` and are interned in the `keyword` module.

### Literals

```fol
:foo          ; simple keyword
:my-key       ; hyphenated keyword
```

### Predicate

```fol
(<keyword>? :foo)     ; => true
(<keyword>? 'foo)     ; => false (regular symbol)
```

### Functions

| Function | Description |
|----------|-------------|
| `keyword` | Create a keyword from a string or symbol |
| `find-keyword` | Find an existing keyword (returns nil if not found) |

### Examples

```fol
(keyword "name")      ; => :name
(keyword 'name)       ; => :name
(find-keyword "name") ; => :name or nil
```

---

## Numbers

FOL provides a complete numeric tower with the following hierarchy:

```
<number>
+-- <complex>
+-- <real>
    +-- <float>
    |   +-- <single-float>
    |   +-- <double-float>
    +-- <rational>
        +-- <ratio>
        +-- <integer>
            +-- <fixnum>
            +-- <bignum>
```

### Number Literals

```fol
42              ; integer (fixnum)
-17             ; negative integer
3.14            ; double-float (default)
3.14f0          ; single-float
3.14d0          ; double-float (explicit)
1/2             ; ratio
#C(1 2)         ; complex number (1 + 2i)
##Inf           ; positive infinity
##-Inf          ; negative infinity
##NaN           ; not a number
```

### Type Predicates

| Predicate | Description |
|-----------|-------------|
| `<number>?` | Any number type |
| `<complex>?` | Complex number |
| `<float>?` | Floating-point number |
| `<single-float>?` | Single-precision float |
| `<double-float>?` | Double-precision float |
| `<rational>?` | Rational number (integer or ratio) |
| `<ratio>?` | Exact fraction |
| `<integer>?` | Integer (fixnum or bignum) |
| `<fixnum>?` | Small integer (machine word) |
| `<bignum>?` | Arbitrary precision integer |

### Numeric Predicates

| Predicate | Description |
|-----------|-------------|
| `zero?` | True if number equals zero |
| `positive?` | True if number > 0 |
| `negative?` | True if number < 0 |
| `even?` | True if integer is even |
| `odd?` | True if integer is odd |
| `nat-int?` | True if non-negative integer (>= 0) |
| `pos-int?` | True if positive integer (> 0) |
| `NaN?` | True if floating-point NaN |
| `infinite?` | True if floating-point infinity |

### Type Conversion Functions

| Function | Description |
|----------|-------------|
| `<complex>` | Convert to complex number |
| `<single-float>` | Convert to single-precision float |
| `<double-float>` | Convert to double-precision float |
| `int` | Convert to integer (chars, bools, integers) |
| `rationalize` | Convert to rational approximation |

### Parsing Functions

| Function | Description |
|----------|-------------|
| `parse-int` | Parse string to integer |
| `parse-double` | Parse string to double-float |
| `parse-bool` | Parse string to boolean |
| `parse-uuid` | Parse string to UUID |

### Random Number Generation

| Function | Description |
|----------|-------------|
| `rand` | Random number: `(rand)` for [0,1), `(rand n)` for [0,n) |
| `with-seed` | Macro: evaluate body with seeded random state |

### Examples

```fol
(zero? 0)                ; => t
(positive? 5)            ; => t
(even? 4)                ; => t
(<double-float> 42)      ; => 42.0d0
(parse-int "123")        ; => 123
(rand)                   ; => 0.7234... (random)
(rand 10)                ; => 7 (random integer 0-9)
```

See [Section 6: Arithmetic](#6-arithmetic) for the complete set of math operations.

---

## UUID - `<uuid>`

A UUID (Universally Unique Identifier).

```fol
(parse-uuid "550e8400-e29b-41d4-a716-446655440000")
```

---

## Streams

Stream classes wrap native Lisp streams for I/O operations. Unlike other primitives, streams are **not** persistent objects because they are inherently stateful.

| Class | Description |
|-------|-------------|
| `<stream>` | Base stream class |
| `<input-stream>` | Base class for input streams |
| `<output-stream>` | Base class for output streams |
| `<string-input-stream>` | Read from a string |
| `<file-input-stream>` | Read from a file |
| `<string-output-stream>` | Write to a string |
| `<file-output-stream>` | Write to a file |

---

# 2. Collections

FOL provides a rich set of persistent, immutable collection types. All collections inherit from `<persistent-object>` and support structural sharing for efficient updates.

## Collection Hierarchy

```
<collection>
+-- <ordered-collection>
|   +-- <vector>
|   +-- <deque>
|   +-- <list>
|   +-- <lazy-seq>
|   +-- <array>
|   +-- <sorted-set>
|   +-- <ordered-set>
|   +-- <dense-int-set>
|   +-- <array-dict>
|   +-- <sorted-dict>
|   +-- <ordered-dict>
|   +-- <priority-dict>
+-- <unordered-collection>
    +-- <dict>
    +-- <set>
    +-- <bag>
```

## Collection Literals

| Syntax | Type | Example |
|--------|------|---------|
| `()` or `'(...)` | List | `'(1 2 3)` |
| `[...]` | Vector | `[1 2 3]` |
| `{...}` | Dict | `{:a 1 :b 2}` |
| `#{...}` | Set | `#{1 2 3}` |
| `#Q[...]` | Deque | `#Q[1 2 3]` |
| `#M{...}` | Bag | `#M{1 1 2}` |

---

## Vector - `<vector>`

A persistent ordered sequence with efficient random access. The primary indexed collection type.

```fol
[]              ; empty vector
[1 2 3]         ; vector of integers
(vec '(1 2 3))  ; => [1 2 3] (from sequence)
(mapv inc [1 2 3])     ; => [2 3 4] (eager map to vector)
(filterv odd? [1 2 3]) ; => [1 3] (eager filter to vector)
```

---

## List - `<list>`

A persistent singly-linked list with O(1) prepend.

```fol
'(1 2 3)          ; quoted list
(list 1 2 3)      ; => (1 2 3)
(cons 0 '(1 2 3)) ; => (0 1 2 3)
(conj '(1 2 3) 0) ; => (0 1 2 3) - lists prepend
```

---

## Deque - `<deque>`

A persistent double-ended queue with efficient O(log n) operations at both ends.

```fol
(deque 1 2 3)         ; => #Q[1 2 3]
(peek-front dq)       ; front element
(pop-front dq)        ; remove front
(push-front 0 dq)     ; add to front
(peek-end dq)         ; end element
(pop-end dq)          ; remove end
(push-end 4 dq)       ; add to end
```

---

## Lazy Sequence - `<lazy-seq>`

A lazy sequence that delays computation until elements are accessed. Supports infinite sequences.

```fol
(range)               ; infinite sequence 0, 1, 2, ...
(range 5)             ; => (0 1 2 3 4)
(take 5 (iterate inc 0))  ; => (0 1 2 3 4)
(map inc [1 2 3])     ; => lazy sequence (2 3 4)
```

---

## Dict - `<dict>`

A persistent hash map with O(1) average lookup.

```fol
{}              ; empty dict
{:a 1 :b 2}    ; dict with keyword keys
(get {:a 1} :a) ; => 1
(assoc {:a 1} :b 2) ; => {:a 1 :b 2}
```

---

## Set - `<set>`

A persistent hash set with O(1) average lookup.

```fol
#{}             ; empty set
#{1 2 3}        ; set of integers
(conj #{1 2} 3) ; => #{1 2 3}
```

---

## Bag - `<bag>`

A persistent multiset that counts occurrences.

```fol
#M{1 1 2}       ; bag with two 1s and one 2
```

---

## Array - `<array>`

A multi-dimensional array stored as a flat vector with dimension information.

```fol
(make <array> :dimensions (2 3) 1 2 3 4 5 6)  ; 2x3 array
```

### Typed Arrays

FOL provides specialized array types for different numeric data types, all inheriting from the `<array-ops>` base class for consistent dimension tracking and array operations.

#### Constructor Functions

| Constructor | Type | Storage | Description |
|-------------|------|---------|-------------|
| `f64-array` | `<f64-array>` | 64-bit floats | High-precision floating-point arrays |
| `f32-array` | `<f32-array>` | 32-bit floats | Single-precision floating-point arrays |
| `fixnum-array` | `<fix64-array>` | 64-bit integers | Machine word integer arrays |

#### Usage Examples

```fol
;; Create 64-bit float arrays
(f64-array 1.0 2.0 3.0)                              ; 1D array of 3 elements
(f64-array :dimensions (2 3) 1.0 2.0 3.0 4.0 5.0 6.0) ; 2x3 array
(f64-array :dimensions (4) :initial-element 0.0)    ; 4-element array, all zeros

;; Create 32-bit float arrays
(f32-array 1.0 2.0 3.0)                              ; 1D array of 3 elements
(f32-array :dimensions (2 2) 1.0 2.0 3.0 4.0)        ; 2x2 array
(f32-array :dimensions (3) :initial-element 5.0)    ; 3-element array, all 5.0

;; Create fixnum (64-bit integer) arrays
(fixnum-array 10 20 30)                              ; 1D array of 3 elements
(fixnum-array :dimensions (2 3) 1 2 3 4 5 6)         ; 2x3 array
(fixnum-array :dimensions (5) :initial-element 42)  ; 5-element array, all 42
```

#### Type Predicates

```fol
(f64-array? arr)     ; Check if arr is a 64-bit float array
(f32-array? arr)     ; Check if arr is a 32-bit float array
(fix64-array? arr)   ; Check if arr is a 64-bit integer array
(array-ops? arr)     ; Check if arr is any typed array (base class predicate)
```

#### Dimension Tracking

All typed arrays maintain dimension information accessible via `array-dimension`:

```fol
(let [arr (f64-array :dimensions (2 3) 1.0 2.0 3.0 4.0 5.0 6.0)]
  (array-dimension arr))  ; => (2 3)
```

---

## Specialized Set Types

| Constructor | Type | Description |
|-------------|------|-------------|
| `<set>` | `<set>` | Hash set (unordered) |
| `<sorted-set>` | `<sorted-set>` | Sorted set (natural ordering) |
| `<sorted-set-by>` | `<sorted-set-by>` | Sorted set with custom comparator |
| `<ordered-set>` | `<ordered-set>` | Insertion-order set |
| `<int-set>` | `<int-set>` | Integer-only sorted set |
| `<dense-int-set>` | `<dense-int-set>` | Dense integer range set |

## Specialized Dict Types

| Constructor | Type | Description |
|-------------|------|-------------|
| `<dict>` | `<dict>` | Standard hash map (unordered) |
| `<array-dict>` | `<array-dict>` | Small insertion-order map |
| `<sorted-dict>` | `<sorted-dict>` | Sorted map (natural key ordering) |
| `sorted-dict-by` | `<sorted-dict>` | Sorted map with custom comparator |
| `<ordered-dict>` | `<ordered-dict>` | Insertion-order map (unlimited) |
| `<priority-dict>` | `<priority-dict>` | Priority queue map (sorted by values) |
| `<int-dict>` | `<int-dict>` | Integer-key sorted map |

---

## Core Collection Functions

These functions work across all collection types.

| Function | Description |
|----------|-------------|
| `first` | Returns the first element |
| `rest` | Returns all elements after the first |
| `second` | Returns the second element |
| `third` | Returns the third element |
| `nth` | Returns element at index n (0-indexed) |
| `get` | Retrieves element by key/index with optional default |
| `size` | Returns the number of elements |
| `empty?` | Returns true if collection has no elements |
| `contains?` | Returns true if collection contains item |
| `seq` | Returns a sequential view as a list; nil if empty |
| `conj` | Returns a new collection with items added |
| `add` | Returns a new collection with item added |
| `into` | Pours one collection into another |
| `vec` | Converts a sequence to a vector |
| `vector` | Creates a vector from arguments |

### Examples

```fol
(first [1 2 3])       ; => 1
(rest [1 2 3])        ; => (2 3)
(nth [10 20 30] 1)    ; => 20
(get {:a 1} :a)       ; => 1
(get {:a 1} :b 0)     ; => 0 (default)
(size #{1 2 3})       ; => 3
(empty? [])           ; => true
(conj [1 2] 3)        ; => [1 2 3]
(into [] '(1 2 3))    ; => [1 2 3]
```

---

## Set Operations

| Function | Description |
|----------|-------------|
| `union` | All elements from all sets |
| `difference` | Elements in set1 but not set2 |
| `intersection` | Elements in all sets |
| `select` | Elements satisfying predicate |
| `subset?` | True if set1 is subset of set2 |
| `superset?` | True if set1 is superset of set2 |
| `disj` | Remove elements from set |

### Examples

```fol
(union #{1 2} #{2 3})           ; => #{1 2 3}
(difference #{1 2 3} #{2})      ; => #{1 3}
(intersection #{1 2 3} #{2 3 4}) ; => #{2 3}
(subset? #{1 2} #{1 2 3})       ; => true
```

---

## Dict Operations

| Function | Description |
|----------|-------------|
| `assoc` | Associate key with value |
| `assoc-in` | Associate value at nested key path |
| `dissoc` | Remove key from dict |
| `get-in` | Get value at nested key path |
| `find` | Returns key-value pair or nil |
| `keys` | Returns sequence of keys |
| `vals` | Returns sequence of values |
| `merge` | Merge dicts (later values win) |
| `merge-with` | Merge dicts using function for conflicts |
| `select-keys` | Dict with only specified keys |
| `rename-keys` | Rename keys in a dict |
| `map-invert` | Swap keys and values |
| `update` | Apply function to value at key |
| `update-in` | Apply function to value at nested key path |
| `update-keys` | Apply function to all keys |
| `update-vals` | Apply function to all values |

### Examples

```fol
(assoc {:a 1} :b 2)             ; => {:a 1 :b 2}
(dissoc {:a 1 :b 2} :b)         ; => {:a 1}
(get-in {:a {:b 1}} [:a :b])    ; => 1
(keys {:a 1 :b 2})              ; => (:a :b)
(merge {:a 1} {:b 2})           ; => {:a 1 :b 2}
(update {:a 1} :a inc)          ; => {:a 2}
```

---

## Collections as Functions

Collections can be used as functions for element access (Clojure-style):

```fol
(def v [10 20 30])
(v 1)                ; => 20

(def m {:name "Alice"})
(m :name)            ; => "Alice"

(def s #{:a :b :c})
(s :b)               ; => :b
```

Keywords can also be used as functions:

```fol
(:name {:name "Alice"})  ; => "Alice"
(:red #{:red :green})    ; => :red
```

---

# 3. Destructuring

FOL supports Clojure-style destructuring in `bind`, `fn`, `defn`, `loop`, and `defmacro`. Destructuring allows binding names to parts of a data structure in a single expression.

## Sequential Destructuring

Bind names to elements of ordered collections by position:

```fol
(bind [[a b c] [1 2 3]]
  (+ a b c))                ; => 6

;; Nested
(bind [[[a b] [c d]] [[1 2] [3 4]]]
  [a b c d])                ; => [1 2 3 4]

;; Rest elements
(bind [[a b & more] [1 2 3 4 5]]
  more)                     ; => (3 4 5)

;; :as binds the whole collection
(bind [[a b :as all] [1 2 3]]
  all)                      ; => [1 2 3]
```

## Associative Destructuring

Bind names to values in dicts by key:

```fol
;; :keys shorthand
(bind [{:keys [name age]} {:name "Alice" :age 30}]
  (str name " is " age))    ; => "Alice is 30"

;; :strs for string keys
(bind [{:strs [name]} {"name" "Bob"}]
  name)                     ; => "Bob"

;; :or for defaults
(bind [{:keys [x y] :or {y 0}} {:x 5}]
  [x y])                    ; => [5 0]

;; :as binds the whole map
(bind [{:keys [a] :as m} {:a 1 :b 2}]
  m)                        ; => {:a 1 :b 2}
```

## Function Parameters

```fol
;; Destructuring in fn parameters
(defn greet [{:keys [first-name last-name]}]
  (str "Hello, " first-name " " last-name))

(greet {:first-name "Jane" :last-name "Doe"})
; => "Hello, Jane Doe"

;; Sequential destructuring
(defn add-point [[x1 y1] [x2 y2]]
  [(+ x1 x2) (+ y1 y2)])

(add-point [1 2] [3 4])  ; => [4 6]
```

---

# 4. Special Forms

Special forms are the primitive building blocks of FOL. Unlike functions, their arguments are not necessarily evaluated before the form is processed.

## quote

```
(quote form)
'form
```

Returns the form unevaluated.

```fol
'(+ 1 2)    ; => (+ 1 2) - the list, not 3
'x          ; => x - the symbol
```

---

## if

```
(if test then)
(if test then else)
```

Evaluates `test`. If truthy, evaluates and returns `then`; otherwise `else` (or nil).

```fol
(if true "yes" "no")      ; => "yes"
(if (> 5 3) "bigger")     ; => "bigger"
```

---

## do

```
(do form0 form1 ... formN)
```

Evaluates all forms in sequence and returns the value of the last form.

```fol
(do (print "step 1") (print "step 2") 42) ; => 42
```

---

## bind / let

```
(bind [bindings] body...)
(let [bindings] body...)
```

Creates local bindings and evaluates body forms. Supports destructuring. `let` is an alias for `bind`.

```fol
(bind [x 1 y 2] (+ x y))               ; => 3
(bind [[a b] [1 2]] (+ a b))            ; => 3
(bind [x 1 y (+ x 1)] y)               ; => 2
```

---

## fn / lambda

```
(fn [params] body...)
(fn name [params] body...)
```

Creates an anonymous function. Optionally named for recursion. The `lambda` symbol is a synonym for `fn`.

```fol
((fn [x] (* x 2)) 5)                    ; => 10
(def fact (fn f [n] (if (<= n 1) 1 (* n (f (- n 1))))))
((fn [[a b]] (+ a b)) [3 4])            ; => 7
```

---

## def

```
(def name value)
```

Defines a global variable.

```fol
(def pi 3.14159)
(def greeting "Hello")
```

---

## defn

```
(defn name [params] body...)
(defn name
  ([params1] body1...)
  ([params2] body2...)
  ...)
```

Defines a named function. Supports multi-pattern dispatch.

```fol
(defn double [x] (* x 2))

(defn greet
  ([name] (str "Hello, " name "!"))
  ([greeting name] (str greeting ", " name "!")))
```

---

## defmacro

```
(defmacro name [params] body...)
```

Defines a macro. Macros receive unevaluated forms and return a new form to evaluate.

```fol
(defmacro unless [test & body]
  `(if (not ~test) (do ~@body)))
```

See [Section 19: Macros](#19-macros) for full details.

---

## cond

```
(cond test1 form1 test2 form2 ...)
```

Evaluates test/form pairs in order, returning the form whose test is first truthy.

```fol
(cond
  (< x 0) :negative
  (= x 0) :zero
  t :positive)
```

---

## case

```
(case target-form target1 form1 target2 form2 ... [default])
```

Matches `target-form` against literal targets.

```fol
(case day
  [0 6] :weekend
  [1 2 3 4 5] :weekday)
```

---

## loop / recur

```
(loop [bindings] body*)
(recur arg*)
```

Establishes a recursion point. `recur` jumps back with new values.

```fol
(loop [i 1 sum 0]
  (if (> i 10) sum
      (recur (+ i 1) (+ sum i))))  ; => 55
```

---

## throw / try / catch / finally

```
(throw value)
(try body* (catch var body*) (finally body*)?)
```

Exception handling.

```fol
(try
  (risky-operation)
  (catch e (print (str "Error: " e)) :error)
  (finally (cleanup)))
```

---

## syntax-quote

```
`form
```

Quasiquote for building code templates. `~` for unquote, `~@` for splicing, `#` suffix for auto-gensym.

```fol
(def x 42)
`(a ~x c)           ; => (a 42 c)
`(a ~@[1 2 3] b)    ; => (a 1 2 3 b)
`(bind [x# 1] x#)   ; => (bind [G123 1] G123)
```

---

## make-dynamic / binding

```
(def *debug* (make-dynamic *debug* false))
(binding [*debug* true] body...)
```

Dynamic variables with thread-local rebinding.

---

## lazy-seq

```
(lazy-seq body)
```

Creates a lazy sequence that delays evaluation until realized.

```fol
(defn integers [n]
  (lazy-seq (cons n (integers (+ n 1)))))
(take 5 (integers 0))  ; => (0 1 2 3 4)
```

---

## definline

```
(definline name [params] body)
```

Defines an inline function whose body is substituted at call sites.

```fol
(definline square [x] (* x x))
(square 5)  ; expands to (* 5 5) => 25
```

---

## env

```
(env)
```

Returns the current lexical environment as a value. Useful for debugging and introspection.

---

# 5. Control Flow

FOL provides comprehensive control flow through special forms, macros, and threading operators.

## Conditionals

| Form | Description |
|------|-------------|
| `if` | Two-branch conditional |
| `when` | One-branch conditional (true case) |
| `unless` | One-branch conditional (false case) |
| `when-not` | Synonym for `unless` |
| `cond` | Multi-branch conditional |
| `case` | Value matching |
| `condp` | Predicate-based matching |
| `if-let` | Conditional binding |
| `when-let` | Conditional binding (when branch) |
| `if-some` | Non-nil conditional binding |
| `when-some` | Non-nil conditional binding (when branch) |
| `when-first` | Bind first of seq if non-empty |
| `if-not` | Negated conditional |

### Examples

```fol
(when (> x 0) (print "positive") x)
(unless (empty? coll) (first coll))
(if-let [v (get m :key)] (process v) :not-found)

(condp = x
  1 :one
  2 :two
  :other)
```

---

## Threading Macros

Threading macros pipe a value through a series of transformations.

| Macro | Description |
|-------|-------------|
| `->` | Thread as first argument |
| `->>` | Thread as last argument |
| `as->` | Thread with named binding |
| `cond->` | Conditional thread-first |
| `cond->>` | Conditional thread-last |
| `some->` | Thread-first, short-circuit on nil |
| `some->>` | Thread-last, short-circuit on nil |

### Examples

```fol
(-> 5 (+ 3) (* 2))          ; => 16
(->> [1 2 3] (map inc) (filter even?))  ; => (2 4)
(as-> 1 x (+ x 1) (* x 2)) ; => 4
(some-> {:a {:b 1}} :a :b)  ; => 1
```

---

## Iteration

| Form | Description |
|------|-------------|
| `loop`/`recur` | Tail-recursive iteration |
| `dotimes` | Iterate n times |
| `doseq` | Iterate over sequence for side effects |
| `for` | List comprehension |

### Examples

```fol
(dotimes [i 5] (print i))
(doseq [x [1 2 3]] (print x))
(for [x (range 5) :when (odd? x)] (* x x))  ; => (1 9)
```

---

## Delay and Force

| Form | Description |
|------|-------------|
| `delay` | Create a delayed computation |
| `force` / `deref` | Force evaluation of a delay |
| `delay?` | Check if value is a delay |
| `realized?` | Check if delay has been forced |

```fol
(def d (delay (expensive-computation)))
(deref d)     ; forces computation, caches result
(realized? d) ; => true
```

---

## Miscellaneous Control

| Form | Description |
|------|-------------|
| `lazy-cat` | Lazily concatenate sequences |
| `assert` | Assert condition, throw on failure |
| `comment` | Ignore enclosed forms |

---

# 6. Arithmetic

FOL provides a complete set of mathematical operations.

## Basic Arithmetic

| Function | Description | Examples |
|----------|-------------|----------|
| `+` | Addition | `(+ 1 2)` => `3` |
| `-` | Subtraction / negation | `(- 10 3)` => `7`, `(- 5)` => `-5` |
| `*` | Multiplication | `(* 2 3)` => `6` |
| `/` | Division (exact) | `(/ 1 3)` => `1/3` |
| `inc` | Increment by 1 | `(inc 5)` => `6` |
| `dec` | Decrement by 1 | `(dec 5)` => `4` |
| `abs` | Absolute value | `(abs -5)` => `5` |
| `mod` | Modulus (sign of divisor) | `(mod -10 3)` => `2` |
| `rem` | Remainder (sign of dividend) | `(rem -10 3)` => `-1` |

## Rounding

| Function | Description |
|----------|-------------|
| `floor` | Largest integer <= x |
| `ceiling` | Smallest integer >= x |
| `truncate` | Integer part toward zero |
| `round` | Nearest integer (banker's rounding) |

All rounding functions return two values: the integer result and the remainder. With two arguments, operate on x/divisor.

```fol
(floor 3.7)    ; => 3, 0.7
(ceiling 3.2)  ; => 4, -0.8
(round 2.5)    ; => 2, 0.5 (rounds to even)
```

## Trigonometric and Exponential

| Function | Description |
|----------|-------------|
| `sin` | Sine (radians) |
| `cos` | Cosine (radians) |
| `tan` | Tangent (radians) |
| `sqrt` | Square root |
| `expt` | Exponentiation |
| `exp` | e^x |
| `ln` | Natural logarithm |

## Type Conversion

| Function | Description |
|----------|-------------|
| `<complex>` | Convert to complex |
| `<single-float>` | Convert to single-precision float |
| `<double-float>` | Convert to double-precision float |
| `int` | Convert to integer |
| `rationalize` | Convert to rational approximation |

```fol
(rationalize 3.14159 0.01)  ; => 22/7
```

## Random Numbers

| Function | Description |
|----------|-------------|
| `rand` | `(rand)` for [0,1), `(rand n)` for [0,n) |
| `with-seed` | Evaluate body with seeded random state |

```fol
(with-seed 42 (list (rand 100) (rand 100)))  ; deterministic
```

---

# 7. Comparison

| Function | Description |
|----------|-------------|
| `=` | Numerically equal |
| `/=` | Not equal |
| `<` | Strictly increasing |
| `>` | Strictly decreasing |
| `<=` | Non-decreasing |
| `>=` | Non-increasing |
| `min` | Minimum value |
| `max` | Maximum value |
| `compare` | Three-way comparison (-1, 0, 1) |
| `not=` | Not equal (any types) |

All comparison operators accept variadic arguments and test the property pairwise.

```fol
(= 1 1.0 1/1)    ; => true
(< 1 2 3 4)      ; => true
(min 3 1 4 1 5)  ; => 1
(max 3 1 4 1 5)  ; => 5
```

---

# 8. Logical Operations

| Function | Description |
|----------|-------------|
| `not` | Logical negation |
| `and` | Short-circuit AND (macro); returns first falsey or last value |
| `or` | Short-circuit OR (macro); returns first truthy or last value |
| `xor` | True if odd number of args are truthy |
| `implies` | Logical implication (if a then b) |
| `nand` | NOT AND |
| `nor` | NOT OR |

```fol
(and 1 2 3)       ; => 3
(or nil nil 3)    ; => 3
(xor true false)  ; => true
(implies false x) ; => true
```

---

# 9. Predicates

FOL provides a comprehensive set of type predicates. All predicates return `t` or `nil`.

## Type Predicates

| Predicate | Tests for |
|-----------|-----------|
| `<bool>?` | Boolean (`t` or `nil`) |
| `<char>?` | Character |
| `<number>?` / `number?` | Any number |
| `<integer>?` / `integer?` | Integer |
| `<fixnum>?` | Small integer |
| `<bignum>?` | Arbitrary precision integer |
| `<float>?` / `float?` | Floating point |
| `<single-float>?` | Single-precision float |
| `<double-float>?` | Double-precision float |
| `<ratio>?` / `ratio?` | Exact fraction |
| `<rational>?` / `rational?` | Rational (integer or ratio) |
| `<complex>?` / `complex?` | Complex number |
| `<string>?` | String |
| `<symbol>?` / `symbol?` | Symbol |
| `<keyword>?` | Keyword |

## Numeric Predicates

| Predicate | Tests for |
|-----------|-----------|
| `zero?` | Equals zero |
| `positive?` | Greater than zero |
| `negative?` | Less than zero |
| `even?` | Even integer |
| `odd?` | Odd integer |
| `nat-int?` | Non-negative integer |
| `pos-int?` | Positive integer |
| `NaN?` | Floating-point NaN |
| `infinite?` | Floating-point infinity |

## Collection Type Predicates

| Predicate | Tests for |
|-----------|-----------|
| `<collection>?` | Any collection |
| `<ordered-collection>?` | Ordered collection |
| `<unordered-collection>?` | Unordered collection |
| `<vector>?` | Vector |
| `<deque>?` | Deque |
| `<list>?` | List |
| `<dict>?` | Dict |
| `<set>?` | Set |
| `<bag>?` | Bag |
| `<array>?` | Array |
| `<lazy-seq>?` | Lazy sequence |
| `<sorted-set>?` | Sorted set |
| `<ordered-set>?` | Ordered set |
| `<int-set>?` | Integer set |
| `<dense-int-set>?` | Dense integer set |
| `<sorted-set-by>?` | Custom-comparator sorted set |
| `<array-dict>?` | Array dict |
| `<sorted-dict>?` | Sorted dict |
| `<ordered-dict>?` | Ordered dict |
| `<priority-dict>?` | Priority dict |
| `<int-dict>?` | Integer-key dict |

## General Predicates

| Predicate | Tests for |
|-----------|-----------|
| `nil?` | Value is nil |
| `some?` | Value is not nil |
| `fn?` | Value is a function |
| `instance?` | Value is instance of type |
| `<persistent-object>?` | Value is a persistent object |
| `associative?` | Value supports associative access |
| `indexed?` | Value supports indexed access |
| `seqable?` | Value can be converted to a sequence |
| `any?` | Always returns true |
| `atom?` | Value is an atom |
| `delay?` | Value is a delay |
| `realized?` | Delay or lazy-seq has been realized |
| `qualified-keyword?` | Keyword with namespace |
| `qualified-symbol?` | Symbol with namespace |
| `simple-keyword?` | Keyword without namespace |
| `simple-symbol?` | Symbol without namespace |
| `inst?` | Value is a timestamp |
| `uuid?` | Value is a UUID |
| `sized?` | Collection has known size |

---

# 10. Sequence Operations

FOL provides over 100 sequence operations that work uniformly across all collection types that support `seq`: vectors, lists, dicts, sets, bags, strings, and lazy sequences. Most sequence functions return lazy sequences, enabling efficient composition.

## Core Sequence Functions

| Function | Description |
|----------|-------------|
| `reduce` | Fold a sequence: `(reduce f coll)` or `(reduce f init coll)` |
| `map` | Apply f to each element, returns lazy seq |
| `filter` | Keep elements matching predicate |
| `remove` | Remove elements matching predicate |
| `keep` | Apply f, keep non-nil results |
| `keep-indexed` | Like keep but f receives index and item |
| `map-indexed` | Like map but f receives index and item |
| `mapcat` | Map then concatenate results |
| `reduce-kv` | Reduce with key, value pairs |

### Examples

```fol
(reduce + [1 2 3 4 5])              ; => 15
(reduce + 0 [1 2 3 4 5])            ; => 15
(map inc [1 2 3])                    ; => (2 3 4)
(filter odd? [1 2 3 4 5])           ; => (1 3 5)
(keep (fn [x] (if (> x 2) x nil)) [1 2 3 4])  ; => (3 4)
(mapcat (fn [x] [x (* x 2)]) [1 2 3])  ; => (1 2 2 4 3 6)
```

## Generators

| Function | Description |
|----------|-------------|
| `range` | Sequence of numbers: `(range)`, `(range end)`, `(range start end step)` |
| `iterate` | Infinite sequence: f(x), f(f(x)), f(f(f(x))), ... |
| `repeat` | Infinite or finite repetition |
| `repeatedly` | Repeatedly call a function |
| `cycle` | Infinite cycling of a sequence |
| `tree-seq` | Lazy depth-first tree traversal |

```fol
(range 5)                  ; => (0 1 2 3 4)
(range 1 10 2)             ; => (1 3 5 7 9)
(take 5 (iterate inc 0))   ; => (0 1 2 3 4)
(take 3 (repeat 42))       ; => (42 42 42)
(repeat 3 42)              ; => (42 42 42)
(take 6 (cycle [1 2 3]))   ; => (1 2 3 1 2 3)
```

## Subsequence Operations

| Function | Description |
|----------|-------------|
| `take` | First n elements |
| `drop` | All but first n elements |
| `take-while` | Elements while predicate holds |
| `drop-while` | Drop elements while predicate holds |
| `take-last` | Last n elements |
| `drop-last` | All but last n elements |
| `take-nth` | Every nth element |
| `split-at` | Split at index into two seqs |
| `split-with` | Split at first predicate failure |
| `partition` | Groups of n elements |
| `partition-all` | Like partition, includes incomplete final group |
| `partition-by` | Partition when f's return value changes |

```fol
(take 3 [1 2 3 4 5])              ; => (1 2 3)
(drop 2 [1 2 3 4 5])              ; => (3 4 5)
(take-while pos? [3 2 1 0 -1])    ; => (3 2 1)
(partition 2 [1 2 3 4 5 6])       ; => ((1 2) (3 4) (5 6))
(partition-by odd? [1 3 2 4 5])   ; => ((1 3) (2 4) (5))
```

## Ordering and Deduplication

| Function | Description |
|----------|-------------|
| `sort` | Sort a sequence |
| `sort-by` | Sort by key function |
| `reverse` | Reverse a sequence |
| `rseq` | Reverse of ordered collection |
| `shuffle` | Randomly reorder |
| `distinct` | Remove duplicates |
| `dedupe` | Remove consecutive duplicates |
| `flatten` | Flatten nested sequences |
| `interleave` | Interleave elements from multiple seqs |
| `interpose` | Insert separator between elements |
| `concat` | Concatenate sequences |

```fol
(sort [3 1 4 1 5])                ; => (1 1 3 4 5)
(sort-by :age [{:age 30} {:age 20}])  ; => ({:age 20} {:age 30})
(distinct [1 2 1 3 2])            ; => (1 2 3)
(interpose ", " ["a" "b" "c"])    ; => ("a" ", " "b" ", " "c")
```

## Quantifiers

| Function | Description |
|----------|-------------|
| `some` | Returns first truthy `(pred elem)` |
| `every` | True if pred is true for all elements |
| `not-any` | True if pred is false for all elements |
| `not-every` | True if pred is false for at least one |

```fol
(some even? [1 3 4 5])   ; => true
(every pos? [1 2 3])     ; => true
```

## Realization

| Function | Description |
|----------|-------------|
| `doall` | Force entire lazy seq, return it |
| `dorun` | Force entire lazy seq for side effects, return nil |
| `run!` | Apply proc to each element for side effects |

## Transducers

Many sequence functions (map, filter, take, drop, etc.) return transducers when called with one argument (no collection). Transducers are composable transformation pipelines.

| Function | Description |
|----------|-------------|
| `into` | Pour with optional transducer: `(into to xform from)` |
| `transduce` | Apply transducer and reduce |
| `sequence` | Apply transducer to seq |
| `eduction` | Create a reducible, iterable application of xform |
| `completing` | Wrap a reducing function |
| `ensure-reduced` | Wrap value in reduced if not already |
| `cat` | Transducer that concatenates |
| `halt-when` | Transducer that stops when predicate matches |
| `reduced` | Mark a value as reduced (early termination) |
| `reduced?` | Check if a value is reduced |
| `unreduced` | Unwrap a reduced value |

```fol
(into [] (comp (filter odd?) (map inc) (take 3)) (range))
; => [2 4 6]

(transduce (map inc) + [1 2 3])  ; => 9
```

## Miscellaneous Sequence Functions

| Function | Description |
|----------|-------------|
| `last` | Last element |
| `butlast` | All but last element |
| `next` | Rest, or nil if empty |
| `fnext` | First of next |
| `nnext` | Next of next |
| `ffirst` | First of first |
| `nfirst` | Next of first |
| `nthrest` | Drop n from front |
| `nthnext` | Like nthrest but returns nil when exhausted |
| `rand-nth` | Random element |
| `max-key` | Element maximizing key function |
| `min-key` | Element minimizing key function |
| `zipmap` | Create dict from keys and vals |
| `reductions` | Lazy sequence of intermediate reduce values |
| `into-array` | Convert to array |
| `apply` | Apply function to arguments |
| `seq-replace` | Replace elements using a map |
| `freqs` | Frequency count as dict |
| `group-by` | Group elements by function |
| `index` | Index a collection of maps |
| `pmap` | Parallel map |
| `seque` | Asynchronous sequence buffering |

```fol
(zipmap [:a :b :c] [1 2 3])      ; => {:a 1 :b 2 :c 3}
(freqs [1 1 2 3 3 3])            ; => {1 2, 2 1, 3 3}
(group-by even? [1 2 3 4 5])     ; => {false [1 3 5], true [2 4]}
```

## Relational Operations

| Function | Description |
|----------|-------------|
| `rel-join` | Join two relations (sets of maps) |
| `project` | Project relation to subset of keys |
| `rename` | Rename keys in a relation |

---

# 11. List Operations

List-specific operations for FOL's persistent singly-linked lists.

| Function | Description |
|----------|-------------|
| `list` | Create a list: `(list 1 2 3)` => `(1 2 3)` |
| `list*` | Create a list with last arg as tail: `(list* 1 2 [3 4])` => `(1 2 3 4)` |
| `cons` | Prepend element: `(cons 0 '(1 2))` => `(0 1 2)` |
| `peek` | Access end element (last for lists) |
| `pop` | Remove end element |
| `push` | Add to end |
| `append` | Concatenate lists |

---

# 12. String Functions

FOL provides comprehensive string manipulation operations.

| Function | Description |
|----------|-------------|
| `str` | Concatenate any values into a string |
| `sub` | Substring extraction |
| `blank?` | True if nil, empty, or only whitespace |
| `trim` | Remove leading and trailing whitespace |
| `triml` | Remove leading whitespace |
| `trimr` | Remove trailing whitespace |
| `trim-newline` | Remove trailing newlines |
| `capitalize` | Capitalize first character |
| `upper-case` | Convert to uppercase |
| `lower-case` | Convert to lowercase |
| `starts-with?` | Check prefix |
| `ends-with?` | Check suffix |
| `includes?` | Check for substring |
| `replace` | Replace all occurrences |
| `replace-first` | Replace first occurrence |
| `join` | Join collection with separator |
| `escape` | Escape characters using a map |
| `split` | Split by pattern |
| `split-lines` | Split into lines |
| `reverse` | Reverse a string |
| `index-of` | Find first occurrence |
| `last-index-of` | Find last occurrence |

### Examples

```fol
(str "Hello" ", " "world!")     ; => "Hello, world!"
(trim "  hello  ")              ; => "hello"
(split "a,b,c" ",")            ; => ["a" "b" "c"]
(join ", " ["a" "b" "c"])      ; => "a, b, c"
(replace "hello" "l" "r")      ; => "herro"
(upper-case "hello")           ; => "HELLO"
```

---

# 13. Character Functions

| Function | Description |
|----------|-------------|
| `char-name-string` | Character name as string |
| `char-upcase` | Convert to uppercase |
| `char-downcase` | Convert to lowercase |
| `alpha-char?` | Is alphabetic? |
| `digit-char?` | Is digit? |
| `alphanumeric?` | Is alphanumeric? |
| `upper-case?` | Is uppercase? |
| `lower-case?` | Is lowercase? |
| `whitespace?` | Is whitespace? |

```fol
(char-name-string \newline) ; => "NEWLINE"
(alpha-char? \a)            ; => true
(digit-char? \5)            ; => true
```

---

# 14. Regular Expressions

FOL provides Perl-compatible regular expression support via CL-PPCRE.

## Types

| Type | Description |
|------|-------------|
| `<re-pattern>` | A compiled regex pattern (inherits from `<string>`) |
| `<re-scanner>` | A compiled scanner for repeated matching |

## Functions

| Function | Description |
|----------|-------------|
| `re-pattern` | Create a regex from a string |
| `re-find` | Find first match; returns string or vector of groups |
| `re-seq` | Lazy sequence of all matches |
| `re-scanner` | Create compiled scanner for efficiency |

### Examples

```fol
(re-find #"\d+" "abc123def")        ; => "123"
(re-find #"(\d+)-(\d+)" "12-34")   ; => ["12-34" "12" "34"]
(re-seq #"\d+" "a1b2c3")           ; => ("1" "2" "3")
```

### Literal Syntax

```fol
#"pattern"        ; regex literal
#"[a-z]+"         ; one or more lowercase letters
#"(?i)hello"      ; case-insensitive
```

---

# 15. Bitwise Operations

FOL provides bitwise operations on integers.

| Function | Description |
|----------|-------------|
| `bitnot` | Bitwise NOT |
| `bitand` | Bitwise AND |
| `bitor` | Bitwise OR |
| `bitxor` | Bitwise XOR |
| `bit-nand` | Bitwise NAND |
| `bit-nor` | Bitwise NOR |
| `bit-andc1` | AND complement of first arg with second |
| `bit-andc2` | AND first arg with complement of second |
| `bit-orc1` | OR complement of first arg with second |
| `bit-orc2` | OR first arg with complement of second |
| `bit-test` | Test if bit at position is set |
| `bit-set` | Set bit at position |
| `bit-clear` | Clear bit at position |
| `bit-count` | Count set bits |
| `bit-shift` | Shift left (positive) or right (negative) |
| `bit-rotate` | Rotate bits within width |

### Examples

```fol
(bitand 12 10)       ; => 8
(bitor 12 10)        ; => 14
(bit-shift 1 10)     ; => 1024
(bit-test 8 3)       ; => true (bit 3 of 8 is set)
(bit-count 255)      ; => 8
```

---

# 16. Functional Programming

Higher-order functions for composing and transforming functions.

| Function | Description |
|----------|-------------|
| `identity` | Returns its argument unchanged |
| `constantly` | Returns a function that always returns the given value |
| `complement` | Negates a predicate function |
| `comp` | Function composition: `(comp f g h)` => `(fn [x] (f (g (h x))))` |
| `partial` | Partial application from the left |
| `rpartial` | Partial application from the right |
| `juxt` | Juxtaposition: apply multiple fns, return vector of results |
| `memoize` | Cache function results |
| `fnil` | Replace nil arguments with defaults |
| `disjoin` | OR of predicates |
| `conjoin` | AND of predicates |
| `trampoline` | Mutual recursion without stack overflow |
| `fn?` | Is value a function? |

### Examples

```fol
((comp str inc) 41)            ; => "42"
((partial + 10) 5)             ; => 15
((juxt min max) 3 1 4 1 5)    ; => [1 5]
(def fib (memoize (fn f [n] (if (< n 2) n (+ (f (- n 1)) (f (- n 2)))))))
((fnil + 0 0) nil 5)           ; => 5
```

---

# 17. Generic Functions and Object System

FOL provides CLOS-style object-oriented programming with generic functions, methods, and classes, enhanced with predicate dispatch and persistent slot storage.

## defgeneric

```fol
(defgeneric name [lambda-list] option*)
```

Defines a generic function.

```fol
(defgeneric area [shape]
  (:documentation "Calculate the area of a shape."))
```

## defmethod

```fol
(defmethod name qualifier* [specialized-lambda-list] body*)
```

Defines a method on a generic function. Methods can specialize on types and use predicate guards.

```fol
(defmethod area [(shape <circle>)]
  (* pi (expt (circle-radius shape) 2)))

(defmethod area [(shape <rect>)]
  (* (rect-width shape) (rect-height shape)))
```

## defclass

```fol
(defclass name [superclasses] [slots] class-option*)
```

Defines a persistent class. All user-level classes use `<persistent-object>` as a superclass.

```fol
(defclass <point> [<persistent-object>]
  [(x :initarg :x :accessor point-x)
   (y :initarg :y :accessor point-y)])
```

## Multi-Pattern Dispatch

Functions and methods support multi-clause definitions with automatic specificity ordering:

```fol
(defn process
  ([(x <vector>)] (vec (map process x)))
  ([(x <dict>)]   (update-vals x process))
  ([(x <number>)] (* x 2))
  ([x] x))
```

## Predicate Specializers

Dispatch on runtime predicates:

```fol
(defn age-group
  ([(age (< 13))] :child)
  ([(age (< 20))] :teen)
  ([(age (< 65))] :adult)
  ([age] :senior))
```

## Method Qualifiers

FOL supports `:before`, `:after`, and `:around` method qualifiers.

```fol
(defmethod apply-command :around [agg cmd]
  (bind [result (call-next-method)]
    (assoc result :log (conj (:log result) cmd))))
```

## Pattern Specificity

The specificity hierarchy for dispatch ordering:

1. **Predicate** (most specific) -- `(x (< 10))`
2. **Type** -- `(x <number>)`
3. **Destructuring** -- `[[a b]]`
4. **Catch-all** (least specific) -- `[x]`

Within the same category, definition order determines priority.

---

# 18. Meta-Object Protocol

FOL adapts the CLOS Meta-Object Protocol for immutable persistent objects.

## Universal Constructor

```fol
(make <class> :slot1 val1 :slot2 val2)
```

Creates an instance of any FOL class.

## Class Introspection

| Function | Description |
|----------|-------------|
| `class-name` | Name of a class |
| `class-direct-superclasses*` | Direct superclasses as a list |
| `class-slots` | Slot definitions of a class |
| `slot-names` | Slot names of a class |

## Instance Introspection

| Function | Description |
|----------|-------------|
| `instance-class` | Class of an instance |
| `slot-value` | Value of a named slot |
| `type` | Type of any FOL value |

## Lazy Schema Evolution

When a class is redefined, existing instances are not mutated. Instead:
- Accessing new slots on old instances uses initform defaults
- Functional updates (`assoc` on slots) produce instances of the new schema
- Removed slots persist harmlessly in the storage map

This provides safe, zero-downtime class evolution.

---

# 19. Macros

FOL supports Clojure-style macros with quasiquote syntax.

## defmacro

```fol
;; Single-pattern
(defmacro name [params] body...)

;; Multi-pattern
(defmacro name
  ([params1] body1...)
  ([params2] body2...)
  ...)
```

Macros receive unevaluated forms and return code to evaluate.

### Quasiquote Syntax

| Syntax | Meaning |
|--------|---------|
| `` ` `` | Syntax-quote (template) |
| `~x` | Unquote: evaluate and insert |
| `~@x` | Unquote-splicing: evaluate and splice |
| `x#` | Auto-gensym: unique symbol |

### Examples

```fol
(defmacro unless [test & body]
  `(if (not ~test) (do ~@body)))

(defmacro when-let [[var expr] & body]
  `(bind [result# ~expr]
     (when result#
       (bind [~var result#]
         ~@body))))
```

## macroexpand-1 / macroexpand

```fol
(macroexpand-1 '(unless true 42) env)  ; one expansion step
(macroexpand '(outer 5) env)            ; full expansion
```

---

# 20. Module System

FOL provides a Dylan-inspired module system for namespace management.

## Standard Modules

| Module | Description |
|--------|-------------|
| `fol.core` | All standard functions, macros, and special forms |
| `fol.zip` | Zipper operations for tree navigation |
| `fol.walk` | Tree walking functions |

## Using Modules

```fol
(use-module fol.core)       ; import all exports from fol.core
(import fol.zip)            ; import is an alias for use-module
```

## Creating Modules

```fol
(module my-module
  (use-module fol.core)

  (defn helper [x] (* x 2))
  (defn public-fn [x] (helper x))

  (export public-fn))
```

## Exporting Symbols

```fol
(export name1 name2 ...)
```

Only exported symbols are visible when the module is imported.

---

# 21. Exception Handling

FOL provides exception handling via `try`/`catch`/`throw`, built on Common Lisp's condition system.

## Basic Usage

```fol
(throw "Something went wrong")

(try
  (risky-operation)
  (catch e
    (print (str "Error: " e))
    :error)
  (finally
    (cleanup)))
```

## Exception Classes

FOL defines an exception hierarchy:

| Class | Description |
|-------|-------------|
| `<exception>` | Base exception class |
| `<error>` | General errors |
| `<type-error>` | Type mismatch |
| `<arity-error>` | Wrong number of arguments |
| `<index-error>` | Index out of bounds |
| `<key-error>` | Key not found |
| `<division-error>` | Division by zero |

## Custom Exception Classes

```fol
(defclass <my-error> [<error>]
  [(detail :initarg :detail :accessor error-detail)])

(throw (make <my-error> :message "oops" :detail 42))
```

---

# 22. Zippers

Zippers provide functional tree editing -- navigating and modifying tree structures while maintaining immutability. Available in the `fol.zip` module.

## Creating Zippers

| Function | Description |
|----------|-------------|
| `zipper` | Create a zipper from branch?, children, make-node fns and a root |
| `vector-zip` | Zipper for nested vectors |
| `seq-zip` | Zipper for nested sequences |

## Navigation

| Function | Description |
|----------|-------------|
| `up` | Move to parent |
| `down` | Move to first child |
| `left` | Move to left sibling |
| `right` | Move to right sibling |
| `leftmost` | Move to leftmost sibling |
| `rightmost` | Move to rightmost sibling |
| `zip-next` | Depth-first next |
| `prev` | Depth-first previous |

## Accessors

| Function | Description |
|----------|-------------|
| `node` | Current node value |
| `branch?` | Is current node a branch? |
| `children` | Children of current node |
| `path` | Ancestors from root |
| `lefts` | Left siblings |
| `rights` | Right siblings |
| `root` | Navigate to root and return tree |
| `end?` | Has traversal ended? |

## Editing

| Function | Description |
|----------|-------------|
| `replace` | Replace current node |
| `edit` | Apply function to current node |
| `insert-child` | Insert child at front |
| `append-child` | Append child at end |
| `insert-left` | Insert left sibling |
| `insert-right` | Insert right sibling |
| `zip-remove` | Remove current node |

### Example

```fol
(use-module fol.zip)

(def tree [1 [2 3] [4 [5 6]]])
(def z (vector-zip tree))

(-> z down right down node)          ; => 4
(-> z down right down (replace 99) root)  ; => [1 [2 3] [99 [5 6]]]
```

---

# 22. Array Programming

Array programming operations for vectorized computation on collections with axis-aware semantics.

## Phase 1: Generic Operators

Vectorized arithmetic, comparison, and logical operators with automatic broadcasting.

See [array-operations.md](array-operations.md) for complete documentation of:

- **Arithmetic**: `+`, `-`, `*`, `/` with broadcasting
- **Comparison**: `=`, `<`, `>`, `<=`, `>=`, `not=`
- **Logical**: `and`, `or`, `not`

### Examples

```fol
(+ [1 2 3] [4 5 6])                 ; => [5 7 9] (element-wise)
(+ [1 2 3] 10)                      ; => [11 12 13] (broadcast scalar)
(* 2 3 4 5)                         ; => 120 (varargs reduction)
```

## Phase 2: Adverbs (Axis-Aware Operations)

Higher-order operations on vectors and arrays that reduce, scan, or transform along specified axes.

See [adverbs.md](adverbs.md) for complete documentation of:

- **Reductions**: `fold`, `scan` (cumulative reduction)
- **Iteration**: `each`, `window`, `group-by`
- **Statistics**: `sum`, `mean`, `variance`, `std-dev`
- **Transformations**: `array-reverse`, `map-array`, `zip`
- **Partitioning**: `array-partition`, `array-take`, `array-drop`

### Axis Convention

- **Axis 0** (default): Vertical (rows) - operates along columns
- **Axis 1**: Horizontal (columns) - operates along rows

### Examples

```fol
; Sum along axis 0 (reduce rows, return column sums)
(sum [[1 2 3] [4 5 6]] :axis 0)     ; => [5 7 9]

; Cumulative sum (scan)
(scan #'+ [1 2 3 4])                ; => [1 3 6 10]

; Apply function to each element
(map-array #'(lambda (x) (* x 2)) [1 2 3])
                                    ; => [2 4 6]
```

---

# 23. Miscellaneous

Additional utility functions available in `fol.core`.

| Function | Description |
|----------|-------------|
| `print` | Print a value |
| `type` | Returns the type of a value |
| `eval` | Evaluate a FOL form |
| `make` | Universal constructor for classes |
| `apply` | Apply function to argument list |
| `intern` | Create a symbol in a module |

## Atoms

Atoms provide mutable state within FOL's otherwise immutable world. They use
lock-free compare-and-swap (CAS) for thread-safe atomic updates — no locks,
no deadlock risk, and zero synchronization cost on reads.

| Function | Description |
|----------|-------------|
| `atom` | Create an atom: `(atom)` or `(atom initial-value)` |
| `<atom>?` | Check if value is an atom |
| `deref` | Get current value: `(deref a)`. For non-atoms, returns the value itself |
| `reset!` | Set value unconditionally: `(reset! a new-val)` — returns new-val |
| `swap!` | Atomically update: `(swap! a f args...)` — applies `(f current-val args...)` via CAS retry loop |
| `compare-and-set!` | Conditional update: `(compare-and-set! a old new)` — sets to new only if current is old, returns T/NIL |

```fol
(def counter (atom 0))
(swap! counter inc)       ; => 1
(swap! counter + 10)      ; => 11
(deref counter)           ; => 11
(reset! counter 0)        ; => 0

;; Conditional update
(compare-and-set! counter 0 42)   ; => T   (was 0, now 42)
(compare-and-set! counter 0 99)   ; => NIL (still 42, not 0)
```

## Refs (Software Transactional Memory)

Refs are coordinated, synchronous references for managing shared state across
multiple locations. All ref modifications must occur within a `dosync`
transaction, which provides atomic, isolated updates with automatic retry on
conflict.

| Function | Description |
|----------|-------------|
| `ref` | Create a ref: `(ref value)` or `(ref value :validator fn)` |
| `<ref>?` | Check if value is a ref |
| `deref` | Get current value: `(deref r)` — works inside and outside transactions |
| `dosync` | Execute body in an STM transaction: `(dosync body...)` |
| `ref-set` | Set ref to value within dosync: `(ref-set r new-val)` |
| `alter` | Apply fn within dosync: `(alter r f args...)` — conflict-preventing |
| `commute` | Commutative update within dosync: `(commute r f args...)` — allows concurrent writes |
| `ensure` | Protect ref from other transactions: `(ensure r)` — read-only lock |

```fol
;; Bank transfer — atomically move between two accounts
(def checking (ref 1000))
(def savings  (ref 2000))

(dosync
  (alter checking - 200)
  (alter savings  + 200))

(deref checking)  ; => 800
(deref savings)   ; => 2200

;; Commutative counter — allows concurrent updates without conflict
(def hits (ref 0))
(dosync (commute hits inc))

;; Validator ensures invariants
(def balance (ref 100 :validator (fn [x] (>= x 0))))
(dosync (alter balance - 50))    ; OK, balance is 50
;; (dosync (alter balance - 200)) ; Error — validator rejects negative
```

## Agents (Asynchronous State)

Agents manage independent state updated asynchronously. Actions (functions) are
dispatched to an agent and executed on a background thread, serialized
per-agent. The agent's value becomes the return value of each action.

| Function | Description |
|----------|-------------|
| `agent` | Create an agent: `(agent value)` or `(agent value :error-mode :continue)` |
| `<agent>?` | Check if value is an agent |
| `deref` | Get current value immediately: `(deref a)` |
| `send` | Dispatch action: `(send a f args...)` — returns agent immediately |
| `send-off` | Like send, for potentially blocking I/O actions |
| `await` | Block until pending actions complete: `(await a)` |
| `agent-error` | Return cached error or NIL: `(agent-error a)` |
| `restart-agent` | Clear error and set new value: `(restart-agent a new-val)` |
| `set-error-handler!` | Set error handler: `(set-error-handler! a fn)` |
| `set-error-mode!` | Set error mode: `(set-error-mode! a :fail)` or `:continue` |

```fol
;; Async counter
(def counter (agent 0))
(send counter inc)
(send counter + 10)
(await counter)
(deref counter)  ; => 11

;; Error handling
(def worker (agent 0 :error-mode :continue))
(send worker (fn [v] (error "oops")))
(send worker inc)
(await worker)
(deref worker)       ; => 1 (continued past error)
(agent-error worker) ; => the error object
```

## Dynamic Variables

FOL supports dynamic (special) variables — variables whose bindings are visible to all code called within their dynamic extent. Dynamic variables are conventionally named with `*earmuffs*`.

### Defining Dynamic Variables

Both `def` and `defdynamic` define dynamic variables (both compile to CL `defvar`). Use `defdynamic` to signal explicit intent that a variable is intended for dynamic rebinding:

| Form | Description |
|------|-------------|
| `(def *name* value)` | Define a dynamic variable |
| `(defdynamic *name* value)` | Same as def — explicit-intent alias |
| `(defdynamic *name*)` | Declare without initial value |

### Dynamic Rebinding

Use `binding` to temporarily rebind dynamic variables for the duration of a body. Unlike `bind` (which creates local lexical bindings with `let*`), `binding` uses CL `let` on special variables — bindings are parallel and dynamically scoped:

| Form | Description |
|------|-------------|
| `(binding [*var* val ...] body ...)` | Dynamically rebind vars for body |

```fol
(defdynamic *output-level* :normal)

(defn verbose-print [msg]
  (when (= *output-level* :verbose)
    (print msg)))

;; Temporarily enable verbose output
(binding [*output-level* :verbose]
  (verbose-print "this will print"))

;; Back to normal outside binding
(verbose-print "this will not print")
```

**Key differences from `bind`:**
- `bind` creates local (lexical) bindings with `let*` — sequential, visible only in body
- `binding` rebinds dynamic (special) variables with `let` — parallel, visible to all called code

## Streams

FOL provides a stream class hierarchy that wraps Common Lisp streams with a FOL-friendly interface.

### Class Hierarchy

```
<input-stream>          — base: wraps a CL input stream
<output-stream>         — base: wraps a CL output stream
<string-base>           — mixin: holds a string
<file-base>             — mixin: holds filename + file object
<socket-base>           — mixin: holds URL + socket

<string-input-stream>   — reads from a string
<string-output-stream>  — writes to a string
<file-input-stream>     — reads from a file
<file-output-stream>    — writes to a file
<socket-input-stream>   — reads from a socket
<socket-output-stream>  — writes to a socket
```

### Constructors

| Function | Description |
|----------|-------------|
| `(string-input-stream str)` | Create stream reading from string |
| `(string-output-stream)` | Create stream writing to string |
| `(file-input-stream path)` | Create stream reading from file |
| `(file-output-stream path &key if-exists)` | Create stream writing to file |
| `(socket-input-stream host port)` | Create stream reading from socket |
| `(socket-output-stream host port)` | Create stream writing to socket |

### Protocol

| Function | Description |
|----------|-------------|
| `(stream-read-char s)` | Read one character (NIL at EOF) |
| `(stream-read-line s)` | Read a line as string |
| `(stream-write-char s ch)` | Write one character |
| `(stream-write-string s str)` | Write a string |
| `(stream-write-line s str)` | Write string + newline |
| `(stream-close s)` | Close the stream |
| `(stream-flush s)` | Flush buffered output |
| `(get-output-string s)` | Get accumulated string from string-output-stream |

### Type Predicates

Each class has a predicate: `<input-stream>?`, `<output-stream>?`, `<string-input-stream>?`, `<file-input-stream>?`, etc.

### Global Variables

| Variable | Description |
|----------|-------------|
| `*in*` | Default input stream (file-input-stream on stdin) |
| `*out*` | Default output stream (file-output-stream on stdout) |

```fol
;; Read a line from stdin
(stream-read-line *in*)

;; Write to stdout
(stream-write-line *out* "Hello, world!")

;; String I/O
(bind [out (string-output-stream)]
  (stream-write-string out "hello ")
  (stream-write-string out "world")
  (get-output-string out))  ; => "hello world"

;; File I/O
(bind [out (file-output-stream "data.txt")]
  (stream-write-line out "line 1")
  (stream-write-line out "line 2")
  (stream-close out))

;; Rebind *out* to capture output
(binding [*out* (string-output-stream)]
  (stream-write-string *out* "captured")
  (get-output-string *out*))  ; => "captured"
```

## Tree Walking (fol.walk module)

| Function | Description |
|----------|-------------|
| `walk` | Walk a form, applying inner and outer fns |
| `prewalk` | Pre-order walk |
| `postwalk` | Post-order walk |
| `prewalk-replace` | Pre-order walk with replacement map |
| `postwalk-replace` | Post-order walk with replacement map |
| `prewalk-demo` | Pre-order walk printing each step |
| `postwalk-demo` | Post-order walk printing each step |

```fol
(use-module fol.walk)
(postwalk-replace {:a 1 :b 2} [:a :b :c])  ; => [1 2 :c]
```

---

*This manual covers all functions, macros, and special forms available in `fol.core`, `fol.zip`, and `fol.walk`. For implementation details, see [INTERNALS.md](../INTERNALS.md). For design rationale and benchmarks, see the [ELS 2026 paper](els-2026-paper.pdf).*
