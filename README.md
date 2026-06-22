# FOL: Functional Object Lisp

FOL is a Clojure dialect that combines **persistent data structures** (from Clojure), **CLOS-style object orientation** with persistent objects, and **array programming capabilities** (inspired by Q/APL). Every value is an object backed by persistent structures enabling efficient structural sharing and immutability. FOL transpiles to Common Lisp (currently only SBCL has been tested and is supported).

## Current version
0.1.0

## Features

- **Persistent Data Structures**: Vectors, dictionaries, sets, bags with structural sharing
- **Object-Oriented Programming**: CLOS-style generic functions, methods, and classes
- **Array Programming**: Vectorized operators, axis-aware adverbs, multi-dimensional operations
- **Functional Programming**: First-class functions, closures, partial application, memoization
- **Immutability by Default**: All data structures are immutable; mutation assoc/dissoc creating shared structures (collections) or new objects (CLOS objects)
- **Meta-Object Protocol**: Full introspection and reflection capabilities
- **Lazy Sequences**: Infinite sequences with on-demand evaluation

## Quick Start

### Building

```bash
cd src
sbcl --noinform --non-interactive \
  --eval "(push (truename \".\") asdf:*central-registry*)" \
  --eval "(asdf:load-system :fol-compiler)"
```

### Running Tests

```bash
cd src && sbcl --noinform --non-interactive \
  --eval "(push (truename \".\") asdf:*central-registry*)" \
  --eval "(asdf:load-system :fol-compiler/tests)" \
  --eval "(fol.compiler.tests:run-compiler-tests)"
```

### Using the REPL

```bash
cd src && sbcl
(push (truename ".") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(use-package :fol.core)

; Now you can evaluate FOL code
(+ 1 2 3)                           ; => 6
(def x [1 2 3 4 5])
(map #(* % 2))                      ; => [2 4 6 8 10]
```

## Project Structure

```
fol/
├── src/                            # Compiler and runtime
│   ├── compiler.lisp               # Main compiler (parse/emit)
│   ├── ast.lisp                    # AST node definitions
│   ├── package.lisp                # Package definitions
│   ├── collections.lisp            # Collection classes
│   ├── array-functions.lisp        # Vectorized operators
│   ├── adverbs.lisp                # Axis-aware operations
│   ├── advanced-array-operations.lisp  # Reshape, slice, transpose
│   ├── fol-compiler.asd            # ASDF system definition
│   └── tests/                      # Test suites
├── docs/                           # Documentation
│   ├── manual/                     # User manual
│   │   ├── FOL-MANUAL.md          # Main reference
│   │   ├── array-operations.md    # Array operator reference
│   │   ├── adverbs.md             # Adverb reference
│   │   └── ...                    # Other documentation
│   └── caching/                    # Research papers
├── benchmarks/                     # Performance benchmarks
├── vscode/                         # VSCode extension
└── README.md                       # This file
```

## Documentation

- **[FOL Manual](docs/manual/FOL-MANUAL.md)** - Complete language reference
- **[Array Operations](docs/manual/array-operations.md)** - Phase 1: Vectorized operators
- **[Adverbs](docs/manual/adverbs.md)** - Phase 2: Axis-aware operations
- **[Collections](docs/manual/collections.md)** - Vector, dict, set operations
- **[Special Forms](docs/manual/special-forms.md)** - if, do, fn, loop, recur, etc.

## Architecture

### -Array Programming System

**Generic Operators**
- Vectorized arithmetic: `+`, `-`, `*`, `/`
- Broadcasting support for scalar-vector operations
- Varargs reduction chains

**Adverbs**
- Axis-aware operations: `fold`, `scan`, `each`, `window`
- Statistics: `sum`, `mean`, `variance`, `std-dev`
- Transformations: `array-reverse`, `map-array`, `zip`
- Partitioning: `array-partition`, `array-take`, `array-drop`

**Advanced Operations**
- Shape operations: `shape`, `rank`, `array-size`, `flatten`, `reshape`
- Axis operations: `sum-axis`, `mean-axis`, `max-axis`, `min-axis`
- Slicing: `slice`, `get-slice`, `put-slice`
- Concatenation: `concat-arrays`, `stack`, `hstack`, `vstack`
- Transposition: `transpose`

**159/159 tests passing (100%)**

## Example Usage

### Array Operations

```fol
; Vectorized arithmetic
(+ [1 2 3] [4 5 6])                 ; => [5 7 9]
(* [1 2 3] 10)                      ; => [10 20 30]

; Axis-aware reductions
(sum [[1 2 3] [4 5 6]] :axis 0)     ; => [5 7 9]
(mean [[1 2 3] [4 5 6]] :axis 0)    ; => [2.5 3.5 4.5]

; Reshaping and transposition
(reshape [1 2 3 4 5 6] [2 3])      ; => [[1 2 3] [4 5 6]]
(transpose [[1 2 3] [4 5 6]])       ; => [[1 4] [2 5] [3 6]]
```

### Collections

```fol
; Vectors
(def v [1 2 3 4 5])
(get v 0)                           ; => 1
(assoc v 2 99)                      ; => [1 2 99 4 5]

; Dictionaries
(def m {:name "FOL" :year 2026})
(get m :name)                       ; => "FOL"

; Sets
(def s #{1 2 3})
(contains? s 2)                     ; => true
```

### Functional Programming

```fol
; Higher-order functions
(map #'(lambda (x) (* x 2)) [1 2 3])  ; => [2 4 6]
(filter #'(lambda (x) (> x 2)) [1 2 3 4 5])  ; => [3 4 5]
(reduce #'+ [1 2 3 4 5])            ; => 15

; Composition
(comp #'inc #'double)               ; Returns function

; Memoization
(def fib (memoize #'(lambda (n) ...)))
```

## Contributing

When modifying FOL:

1. **Run tests** before committing changes
2. **Update documentation** if you change public APIs
3. **Follow naming conventions**: predicate functions end with `?`, functions that modify state end with `!`
4. **Keep it immutable**: Default to persistent data structures

## Performance

Benchmarks available in `benchmarks/` directory. Key results:

- **Array Operations**: 2-4× faster than equivalent CL loops with broadcasting
- **Collections**: Structural sharing reduces memory usage by 60-70% vs. mutable copies
- **Dispatch Caching**: 2.3× speedup via generation-based cache validation

## Known Limitations

- **1D/2D Arrays Only**: Currently supports 1D vectors and 2D array matrices
- **Transpiler supports SBCL Only**: Dispatch caching and advanced features require SBCL
- **Lexical Scope**: No dynamic scoping (use explicit binding forms)

## License

MIT License - See LICENSE file for details

## Authors

- Frank Adrian (creator)
- Claude (AI assistant contributions to testing, documentation, optimization)

## References

- **Paper**: "FOL: A Functional Object Lisp" - European Lisp Symposium 2026
- **Inspired by**: Clojure, Q, APL, Common Lisp, Dylan
- **Dispatch Caching Research**: Multi-language analysis of dispatch caching strategies

---

**Last Updated**: June 22, 2026  
**Status**: Production Ready (159/159 tests passing)
