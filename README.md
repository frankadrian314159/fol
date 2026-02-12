# FOL: Functional Object Lisp

FOL is a Lisp dialect that combines Clojure's persistent data structures and sequence abstractions with CLOS-style class-based object orientation and a Dylan-inspired module system. Written in Common Lisp, FOL features a unified object system where every value is an object, backed by persistent data structures with structural sharing.

For a detailed discussion of the language design and its motivations, see the submitted paper:

> Frank Adrian. "FOL: A Functional Object Lisp." *European Lisp Symposium*, 2026.
> Available at [`docs/els-2026-paper.pdf`](docs/els-2026-paper.pdf).

## Getting Started

### Prerequisites

- [SBCL](http://www.sbcl.org/) (Steel Bank Common Lisp)
- [Quicklisp](https://www.quicklisp.org/) for dependency management

### Installation

1. Install SBCL and Quicklisp following their respective instructions.

2. Install the required libraries. Add the following to your `~/.sbclrc`:

   ```lisp
   (ql:quickload "bordeaux-threads")
   (ql:quickload "fiveam")
   (ql:quickload "closer-mop")
   (ql:quickload "cl-ppcre")
   (ql:quickload "fset")
   (ql:quickload "sycamore")
   ```

3. Register the FOL project directory with ASDF:

   ```lisp
   (push #p"/path/to/fol/" asdf:*central-registry*)
   ```

4. Load FOL:

   ```lisp
   (asdf:load-system :fol)
   ```

### Starting the REPL

Once FOL is loaded, start the interactive REPL:

```lisp
(fol.repl:repl)
```

You will see the `FOL>` prompt. Try some expressions:

```fol
FOL> (+ 1 2)
3

FOL> (def greeting "Hello, FOL!")
"Hello, FOL!"

FOL> [1 2 3 4 5]
[1 2 3 4 5]

FOL> (map inc [1 2 3])
(2 3 4)

FOL> (defn factorial
       ([0] 1)
       ([n] (* n (factorial (dec n)))))
factorial

FOL> (factorial 10)
3628800

FOL> {:name "Alice" :age 30}
{:name "Alice" :age 30}

FOL> (-> {:name "Alice" :scores [95 87 92]}
         :scores
         (->> (filter (fn [x] (> x 90)))))
(95 92)
```

### Running Tests

```lisp
(asdf:test-system :fol)
```

## Key Features

### Persistent Data Structures

All collections are persistent and immutable. Updates return new values that share structure with the original, providing efficient O(log n) modifications.

```fol
(def v [1 2 3])
(def v2 (conj v 4))     ;; v is still [1 2 3], v2 is [1 2 3 4]
```

Collection literals follow Clojure conventions:

| Syntax | Type | Example |
|--------|------|---------|
| `'(...)` | List | `'(1 2 3)` |
| `[...]` | Vector | `[1 2 3]` |
| `{...}` | Dict | `{:a 1 :b 2}` |
| `#{...}` | Set | `#{1 2 3}` |

### Multi-Pattern Dispatch

Functions and methods support multi-clause definitions with type specializers and predicate guards. A specificity hierarchy (predicate > type > destructuring > catch-all) automatically orders clauses.

```fol
(defn describe
  ([(x <number>)] (str x " is a number"))
  ([(x <string>)] (str x " is a string"))
  ([(x <vector>)] (str "vector of size " (size x)))
  ([x] (str "something else")))
```

### CLOS-Style Object System

FOL provides `defclass`, `defgeneric`, and `defmethod` with persistent slot storage and full MOP (Meta-Object Protocol) support.

```fol
(defclass <point> [<persistent-object>]
  [(x :initarg :x :accessor point-x)
   (y :initarg :y :accessor point-y)])

(defgeneric distance [p1 p2])

(defmethod distance [(p1 <point>) (p2 <point>)]
  (sqrt (+ (expt (- (point-x p2) (point-x p1)) 2)
           (expt (- (point-y p2) (point-y p1)) 2))))
```

### Lazy Sequences and Transducers

```fol
;; Infinite sequences
(take 10 (filter even? (range)))   ;; => (0 2 4 6 8 10 12 14 16 18)

;; Transducers compose without intermediate collections
(into [] (comp (filter odd?) (map inc) (take 5)) (range))
;; => [2 4 6 8 10]
```

### Threading Macros

```fol
(-> person
    :address
    :city
    upper-case)

(->> (range 100)
     (filter even?)
     (map (fn [x] (* x x)))
     (take 5))
```

### Dylan-Style Naming and Modules

Classes use angle-bracket naming (`<point>`, `<vector>`). The module system provides namespace management:

```fol
(module my-module
  (use-module fol.core)
  (export my-function))
```

## Influences

FOL draws from three primary traditions:

- **Common Lisp**: Implementation language; CLOS and MOP foundations
- **Clojure**: Persistent data structures, sequence abstractions, collection literals, transducers
- **Dylan**: Class naming conventions (`<name>`), module system design

## Documentation

- **[Language Manual](docs/FOL-MANUAL.md)** -- comprehensive reference for all FOL features
- **[ELS 2026 Paper](docs/els-2026-paper.pdf)** -- design rationale, synergy patterns, and benchmarks
- **[INTERNALS.md](INTERNALS.md)** -- implementation details for FOL developers

## License

MIT
