# FOL: Functional Object Lisp

FOL is an interpreter for a new Lisp dialect that harmonizes the functional programming paradigms of Clojure with the robust object-oriented capabilities of Common Lisp and Apple's Dylan. Written in Common Lisp, FOL features a unified object system where every entity is an object, backed by persistent data structures.

## Pedigree and Influences

FOL is a cross between three primary languages:

*   **Common Lisp**: Serves as the implementation language and provides the foundation for the object system (CLOS).
*   **Clojure**: Inspires the syntax (e.g., brackets for vectors, braces for maps) and the core philosophy of immutability and persistent collections.
*   **Dylan**: Specifically Apple's original prefix-syntax Dylan, influencing class naming conventions (e.g., `<class-name>`) and the module system.

## Key Features

### Unified Object System
All items in FOL are objects. The inheritance hierarchy is rooted in `<persistent-class>`. Even primitive types are wrapped as objects:
*   `<number>`
*   `<char>`
*   `<string>`

These primitives wrap Common Lisp values, accessible internally via the `fol-val` generic function.

### Persistent Collections
Collection classes in FOL are persistent; updated values share structure with older values rather than mutating them in place. This functionality is backed by Common Lisp libraries such as FSet or Sycamore.

### Generic Dispatch
FOL utilizes generic functions and methods for dispatch, similar to CLOS and Dylan. See `fol-code/eval.fol` for a meta-circular evaluator example demonstrating `defgeneric` and `defmethod`.

## Development

### Prerequisites
*   A Common Lisp implementation (e.g., SBCL).
*   Quicklisp for dependency management.

### Style Guidelines
*   **FOL Code**: Follows the Clojure Style Guide.
*   **Interpreter Implementation**: Follows the Common Lisp Style Guide.

### Testing

Tests are performed using the internal function `%test%` (bound to `fol.repl:fol-test` in the Common Lisp layer). This function parses a string containing FOL source code and evaluates it in a given environment.

Example usage in CL test files:

```lisp
(deftest test-arithmetic
  (is (= 3 (fol.repl:fol-test "(+ 1 2)"))))
```

## Documentation

*   **Internals**: See `INTERNALS.md` for documentation on internal functions like `%test%`.
*   **Specifications**: References to CLHS, Clojure docs, and Dylan books are maintained in `claude.md`.