# FOL REPL Guide

The FOL REPL is a Common Lisp-like Read-Eval-Print Loop that evaluates FOL expressions using the FOL evaluator.

## Starting the REPL

### Option 1: Using the startup script (recommended)
```bash
sbcl --load start-repl.lisp
```

### Option 2: From within SBCL
```lisp
(ql:quickload :fol)
(fol.repl:start-repl)
```

### Option 3: Using batch files (Windows)
```batch
repl.bat
```

### Option 4: Using shell script (Linux/Mac)
```bash
chmod +x repl.sh
./repl.sh
```

## REPL Commands

- `:quit` or `:q` - Exit the REPL
- `:reset` - Reset the environment to initial state
- `:help` or `:h` - Show help message

## REPL Variables

The REPL maintains history of evaluated forms and results:

- `*v1`, `*v2`, `*v3` - Last three values returned
- `*f1`, `*f2`, `*f3` - Last three forms evaluated
- `*l1`, `*l2`, `*l3` - Last three value lists (for future multiple-value support)

## Supported Features

### 1. Arithmetic Operations
```lisp
FOL> (+ 1 2 3)
6
FOL> (* 5 (- 10 3))
35
FOL> (/ 20 4)
5
```

### 2. Let Bindings (Clojure-style)
```lisp
FOL> (let (x 10) (* x 2))
20
FOL> (let (x 10 y 20) (+ x y))
30
FOL> (let (x 5 y (+ x 3)) y)
8
```

### 3. Lambda Functions
```lisp
FOL> ((lambda (x) (* x x)) 7)
49
FOL> (let (square (lambda (x) (* x x))) (square 8))
64
```

### 4. Higher-Order Functions
```lisp
FOL> (let (add1 (lambda (x) (+ x 1))
           apply-twice (lambda (f x) (f (f x))))
       (apply-twice add1 5))
7
```

### 5. Conditional Expressions
```lisp
FOL> (if 1 "yes" "no")
"yes"
FOL> (if nil "yes" "no")
"no"
FOL> (if #f "yes" "no")
"no"
```

### 6. Quote
```lisp
FOL> (quote (1 2 3))
(1 2 3)
FOL> '(+ 1 2)
(+ 1 2)
```

### 7. FOL Syntax

#### Vectors
```lisp
FOL> [1 2 3 4 5]
[1 2 3 4 5]
```

#### Dictionaries
```lisp
FOL> {x 10 y 20}
{x 10, y 20}
```

#### Sets
```lisp
FOL> #{1 2 3 2 1}
#{1 2 3}
```

#### Boolean Literals
```lisp
FOL> #t
#t
FOL> #f
#f
```

### 8. List Operations
```lisp
FOL> (list 1 2 3)
(1 2 3)
FOL> (cons 1 (quote (2 3)))
(1 2 3)
FOL> (car (quote (1 2 3)))
1
FOL> (cdr (quote (1 2 3)))
(2 3)
```

## Example Session

```lisp
$ sbcl --load start-repl.lisp

===================================
Welcome to the FOL REPL
Type :help for commands, :quit to exit
===================================

FOL> (+ 1 2 3)
6

FOL> (let (factorial (lambda (n acc)
                       (if (= n 0)
                           acc
                           (factorial (- n 1) (* n acc)))))
       (factorial 5 1))
120

FOL> [1 2 3 4 5]
[1 2 3 4 5]

FOL> {name "Alice" age 30}
{name "Alice", age 30}

FOL> (let (x 10 y 20)
       (let (z (+ x y))
         (* z 2)))
60

FOL> :quit
Goodbye!
```

## Notes

- The REPL uses the FOL syntax readtable, so you can use FOL's special syntax for collections
- All FOL operations (`+`, `-`, `*`, `/`, `=`, `<`, etc.) use FOL's type system and return FOL-wrapped values
- Closures properly capture their lexical environment
- Let bindings are sequential (later bindings can reference earlier ones)
- The REPL environment persists across evaluations until reset with `:reset`

## Troubleshooting

### Warnings on Startup

You may see many warnings about "redefining" when loading the FOL system. These are normal SBCL warnings when reloading code and can be safely ignored.

### Suppressing Warnings

The `start-repl.lisp` script automatically suppresses these warnings. If you're loading manually, you can suppress them with:

```lisp
(handler-bind ((warning #'muffle-warning))
  (ql:quickload :fol))
```

### REPL Exits Immediately

If the REPL exits immediately after starting, make sure you're running it in an interactive terminal with stdin available, not as a batch script with EOF.
