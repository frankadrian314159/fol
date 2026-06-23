# FOL Documentation Index

FOL (Functional Object Lisp) is a Lisp dialect combining features from Common Lisp, Clojure, and Dylan. It features persistent/immutable data structures, a Meta-Object Protocol, and lazy sequences.

## Getting Started

- [Primitives](primitives.md) - Basic types: booleans, characters, strings, symbols, keywords, numbers, UUIDs, streams
- [Collections](collections.md) - Persistent collections: vectors, lists, dicts, sets, bags, arrays, lazy-seqs
- [Destructuring](destructuring.md) - Pattern matching in bindings and function parameters
- [Pattern Specificity](pattern-specificity.md) - Priority ordering for multi-pattern dispatch in functions, methods, and macros

## Language Reference

### Special Forms & Control Flow

- [Special Forms](special-forms.md) - Core evaluation forms: quote, if, do, bind, fn, def, defn, loop, recur, try/catch, etc.
- [Control Flow](control-flow.md) - Comprehensive control flow: conditionals, threading macros, iteration, dynamic binding
- [Macros](macros.md) - Macro definition with defmacro, quasiquote syntax, macroexpand

### Functions & Operations

- [Arithmetic](arithmetic.md) - Math operations: +, -, *, /, trigonometry, floor/ceiling, random numbers
- [Comparison](comparison.md) - Comparison operators: =, /=, <, >, <=, >=, min, max
- [Logical](logical.md) - Boolean operations: and, or, not, xor, implies, nand, nor
- [Bitwise](bitwise.md) - Bit manipulation: bit-and, bit-or, bit-xor, bit-shift, etc.

### Predicates

- [Predicates](predicates.md) - Type predicates: `<number>?`, `<string>?`, `<vector>?`, etc.
- [Collection Predicates](collection-predicates.md) - Collection type checks: `<collection>?`, `<ordered-collection>?`, etc.

### Sequences & Collections

- [Sequences](sequences.md) - Sequence operations: reduce, map, filter, range, iterate, repeat, cycle
- [Sequence Operations](seqop.md) - Extended operations: first, rest, take, drop, concat, sort, group-by, partition
- [List Operations](list-operations.md) - List-specific: cons, list, list*, peek, pop, push, append, reverse

### Array Programming

- [Array Operations](array-operations.md) - Vectorized operators: +, -, *, / with broadcasting; comparisons; logical ops
- [Adverbs](adverbs.md) - Axis-aware operations: fold, scan, sum, mean, variance; transformations: transpose, zip

### Strings & Characters

- [String Functions](string.md) - String manipulation: str, trim, split, join, replace, starts-with?, etc.
- [Character Functions](char.md) - Character operations: char-upcase, char-downcase, alpha-char?, whitespace?

### Regular Expressions

- [Regular Expressions](regex.md) - Pattern matching: re-pattern, re-find, re-seq, re-scanner

### Functional Programming

- [Functional](functional.md) - Higher-order functions: identity, complement, partial, comp, juxt, memoize, trampoline

### Object System

- [Generic Functions](generic-functions.md) - Polymorphism: defgeneric, defmethod, defclass
- [Meta-Object Protocol](mop.md) - Introspection and reflection: class-name*, class-slots*, make, instance-class

### Modules

- [Module System](module.md) - Namespaces: module, use-module, fol.core, zip module

### Tree Navigation

- [Walk](walk.md) - Tree traversal and transformation: walk, prewalk, postwalk, prewalk-replace, postwalk-replace
- [Zippers](zip.md) - Functional tree editing: zipper, vector-zip, seq-zip, navigation and editing

### Miscellaneous

- [Miscellaneous](misc.md) - Utilities: print, type, str, gensym, parse functions

## Performance & Optimization

- [Optimization Guide](optimization-guide.md) - Compiler optimizations: type annotations, metadata, dispatch caching, performance tuning
- [Metadata](metadata.md) - Reader syntax for metadata: `^TYPE`, `^{:key val}`, `^:keyword`

## Quick Reference by Category

### Defining Things

| Form | Description | Documentation |
|------|-------------|---------------|
| `def` | Define a variable | [special-forms.md](special-forms.md) |
| `defn` | Define a function | [special-forms.md](special-forms.md) |
| `defmacro` | Define a macro | [macros.md](macros.md) |
| `defgeneric` | Define a generic function | [generic-functions.md](generic-functions.md) |
| `defmethod` | Define a method | [generic-functions.md](generic-functions.md) |
| `defclass` | Define a class | [generic-functions.md](generic-functions.md) |

### Control Flow

| Form | Description | Documentation |
|------|-------------|---------------|
| `if` | Conditional | [control-flow.md](control-flow.md) |
| `when` / `unless` | One-branch conditional | [control-flow.md](control-flow.md) |
| `cond` | Multi-branch conditional | [control-flow.md](control-flow.md) |
| `case` | Value matching | [control-flow.md](control-flow.md) |
| `loop` / `recur` | Tail-recursive iteration | [control-flow.md](control-flow.md) |
| `->` / `->>` | Threading macros | [control-flow.md](control-flow.md) |

### Working with Collections

| Function | Description | Documentation |
|----------|-------------|---------------|
| `first` / `rest` | Access sequence elements | [seqop.md](seqop.md) |
| `get` | Access by key/index | [collections.md](collections.md) |
| `conj` / `add` | Add elements | [collections.md](collections.md) |
| `assoc` / `dissoc` | Dict operations | [seqop.md](seqop.md) |
| `map` / `filter` | Transform sequences | [sequences.md](sequences.md) |
| `reduce` | Fold a sequence | [sequences.md](sequences.md) |

### Collection Literals

| Syntax | Type | Example |
|--------|------|---------|
| `()` or `'(...)` | List | `'(1 2 3)` |
| `[...]` | Vector | `[1 2 3]` |
| `{...}` | Dict | `{:a 1 :b 2}` |
| `#{...}` | Set | `#{1 2 3}` |

### Number Literals

| Syntax | Type | Example |
|--------|------|---------|
| `42` | Integer | `42`, `-17` |
| `3.14` | Double-float | `3.14`, `1.0e10` |
| `1/2` | Ratio | `1/2`, `22/7` |
| `#C(1 2)` | Complex | `#C(3 4)` |
| `##Inf` | Positive infinity | `##Inf` |
| `##-Inf` | Negative infinity | `##-Inf` |
| `##NaN` | Not a number | `##NaN` |

### Special Characters

| Syntax | Meaning |
|--------|---------|
| `'x` | Quote (don't evaluate) |
| `` `x `` | Syntax-quote (template) |
| `~x` | Unquote (in syntax-quote) |
| `~@x` | Unquote-splicing |
| `#"..."` | Regular expression |
| `\a` | Character literal |
| `:keyword` | Keyword |

## Internal Documentation

- [INTERNALS.md](../INTERNALS.md) - Implementation details for FOL developers
