# FOL Internals

This document describes internal functions and features used for testing and development of FOL. These are not part of the public API and may change without notice.

---

## %test%                                                            *[function]*

Test and evaluate FOL expressions from strings.

### Syntax

```fol
(%test% form-string)
(%test% form-string env)
```

### Arguments

| Argument | Description |
|----------|-------------|
| `form-string` | A string containing FOL source code to parse and evaluate |
| `env` | Optional environment in which to evaluate the form. Defaults to the standard module. |

### Returns

The result of evaluating the parsed form.

### Description

`%test%` is the primary function used for testing FOL code. It:

1. Parses `form-string` using the FOL reader
2. Evaluates the parsed form in the given environment (or the standard module if none provided)
3. Returns the evaluation result

This function is bound to `fol.repl:fol-test` in Common Lisp.

### Examples

```lisp
;; In Common Lisp test files:
(fol.repl:fol-test "(+ 1 2)")        ; => 3
(fol.repl:fol-test "[1 2 3]")        ; => #<VECTOR [1 2 3]>
(fol.repl:fol-test "(map inc [1 2 3])") ; => lazy-seq (2 3 4)

;; With custom environment:
(let ((env (fol.eval:make-env nil 'x 42)))
  (fol.repl:fol-test "x" env))       ; => 42
```

### Usage in Test Files

Test files in the `bootstrap/tests/` directory use this function via the `fol.repl:fol-test` Common Lisp binding:

```lisp
(deftest test-arithmetic
  (is (= 3 (fol-test "(+ 1 2)")))
  (is (= 6 (fol-test "(* 2 3)")))
  (is (= 2 (fol-test "(- 5 3)"))))
```

### Notes

- The `%test%` name uses percent signs to indicate it is an internal function
- In FOL code, it can be accessed directly: `(%test% "(+ 1 2)")`
- The function is available in the standard environment for meta-programming and dynamic evaluation testing
