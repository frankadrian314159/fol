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

---

## %time%                                                                *[macro]*

Evaluates expressions and prints the elapsed time.

### Syntax

```fol
(%time% body*)
```

### Arguments

| Argument | Description |
|----------|-------------|
| `body*` | One or more expressions to evaluate |

### Returns

The result of evaluating the last expression in the body.

### Description

`%time%` is a timing utility macro for performance measurement and debugging. It:

1. Records the start time before evaluation
2. Evaluates all body expressions in sequence
3. Records the end time after evaluation
4. Prints the elapsed time in seconds to standard output
5. Returns the result of the last expression

The timing output format is: `Elapsed time: X.XXXXXX seconds`

This macro is implemented using Common Lisp's `get-internal-real-time` for precise timing.

### Examples

```fol
;; Time a simple computation
(%time% (reduce + (range 10000)))
;; Prints: Elapsed time: 0.001234 seconds
;; => 49995000

;; Time multiple expressions (returns last result)
(%time%
  (def data (vec (range 100000)))
  (reduce + data))
;; Prints: Elapsed time: 0.045678 seconds
;; => 4999950000

;; Time a recursive function
(%time% (fib 30))
;; Prints: Elapsed time: 0.234567 seconds
;; => 832040
```

### Usage Notes

- Use `%time%` for quick performance checks during development
- The timing includes all overhead from the FOL evaluator
- For more precise benchmarking, consider running multiple iterations
- Output goes to standard output and may interleave with other output

### Related

- `%time-thunk%` - The underlying helper function that performs the timing (takes a zero-argument function)
