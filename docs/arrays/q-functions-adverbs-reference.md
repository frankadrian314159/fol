# Q Language Primitive Functions & Adverbs Reference

A comprehensive guide for implementing q-style operations for FOL vectors and arrays.

---

## Part 1: Primitive Functions

**Implementation Note**: All functions are implemented as **generic functions** that dispatch on:
- Scalar numbers (dispatch to CL primitives)
- Vectors and arrays (element-wise operations)
- Mixed scalar/vector (broadcasting)

**Syntax Styles**:
- **Operators** (symbols like `+`, `-`, `=`, etc.): Can be used as prefix functions or in expression context
- **Functions** (named like `mod`, `abs`, `sqrt`): Called as normal functions

### Examples

```lisp
;; Operators (symbol-based, generic dispatch)
(+ 1 2 3)                 ;; CL-style: 6
(+ arr1 arr2)             ;; Element-wise addition
(+ 10 arr)                ;; Broadcast scalar to array

(= 1 2 3)                 ;; Returns false
(= arr 5)                 ;; Element-wise equality → boolean vector

;; Functions (named, generic dispatch)
(abs -5)                  ;; Returns 5
(abs arr)                 ;; Element-wise absolute value

(mod 10 3)                ;; Returns 1
(mod arr 7)               ;; Element-wise modulo

;; Adverbs work with all of these
(fold #'+ arr)            ;; Sum all elements
(fold #'* arr)            ;; Product of all elements
(each #'abs arr)          ;; Absolute value of each element
```

---

### Arithmetic Functions

**Operators (generic functions, work on numbers/vectors/arrays)**

| Operator | Q Symbol | Clojure | Arity | Description | Example |
|----------|----------|---------|-------|-------------|---------|
| Addition | `+` | `+` | 2+ | Add; broadcast/element-wise | `(+ 1 2 3)` → `6`, `(+ arr 10)` → element-wise |
| Subtraction | `-` | `-` | 2+ | Subtract | `(- 10 3)` → `7`, `(- arr 5)` → element-wise |
| Multiplication | `*` | `*` | 2+ | Multiply | `(* 2 3 10)` → `60`, `(* arr 2)` → element-wise |
| Division | `%` | `/` | 2 | Divide (floating-point) | `(/ 10 2)` → `5.0`, `(/ arr 2)` → element-wise |

**Functions (named, work on numbers/vectors/arrays)**

| Function | Q Symbol | Clojure | Arity | Description | Example |
|----------|----------|---------|-------|-------------|---------|
| Integer Division | `div` | `quot` | 2 | Floor division | `(quot 10 3)` → `3` |
| Modulo | `mod` | `mod` | 2 | Remainder | `(mod 10 3)` → `1` |
| Absolute value | `abs` | `abs` | 1 | Absolute value | `(abs -5)` → `5`, `(abs arr)` → element-wise |
| Negate | `neg` | `-` | 1 | Negation (unary) | `(- x)` → negate x |
| Sign | `signum` | `sign` | 1 | +1, 0, or -1 | `(sign -5)` → `-1` |
| Min | `min` | `min` | 2+ | Minimum | `(min 3 1 4)` → `1` |
| Max | `max` | `max` | 2+ | Maximum | `(max 3 1 4)` → `4` |
| GCD | `gcd` | `gcd` | 2 | Greatest common divisor | `(gcd 12 8)` → `4` |
| LCM | `lcm` | `lcm` | 2 | Least common multiple | `(lcm 4 6)` → `12` |
| Power | `pow` / `**` | `pow` | 2 | Exponentiation | `(pow 2 10)` → `1024` |
| Square root | `sqrt` | `sqrt` | 1 | Square root | `(sqrt 16)` → `4.0` |
| Log (natural) | `log` | `log` | 1 | Natural logarithm | `(log 2.718)` → `1.0` |
| Exp | `exp` | `exp` | 1 | e^x | `(exp 1)` → `2.718` |
| Floor | `floor` | `floor` | 1 | Floor | `(floor 3.7)` → `3` |
| Ceiling | `ceil` | `ceil` | 1 | Ceiling | `(ceil 3.2)` → `4` |
| Round | `round` | `round` | 1 | Round to nearest | `(round 3.5)` → `4` |

### Comparison Functions (Generic Operators)

| Operator | Q Symbol | Clojure | Arity | Description | Example |
|----------|----------|---------|-------|-------------|---------|
| Equal | `=` | `=` | 2+ | Element-wise equality | `(= 1 1 1)` → `true`, `(= arr 5)` → boolean vector |
| Not equal | `<>` | `not=` | 2 | Element-wise inequality | `(not= arr 5)` → boolean vector |
| Less than | `<` | `<` | 2+ | Element-wise less-than | `(< 1 2 3)` → `true`, `(< arr 5)` → boolean vector |
| Greater than | `>` | `>` | 2+ | Element-wise greater-than | `(> 3 2 1)` → `true`, `(> arr 5)` → boolean vector |
| Less or equal | `<=` | `<=` | 2+ | Element-wise ≤ | `(<= arr 5)` → boolean vector |
| Greater or equal | `>=` | `>=` | 2+ | Element-wise ≥ | `(>= arr 5)` → boolean vector |

### Logical Functions (Generic Functions)

| Function | Q Symbol | Clojure | Arity | Description | Example |
|----------|----------|---------|-------|-------------|---------|
| And | `&` | `and` | 2+ | Logical AND (element-wise) | `(and true false)` → `false`, `(and arr1 arr2)` → boolean vector |
| Or | `\|` | `or` | 2+ | Logical OR (element-wise) | `(or true false)` → `true`, `(or arr1 arr2)` → boolean vector |
| Not | `~` | `not` | 1 | Logical NOT | `(not true)` → `false`, `(not arr)` → inverted boolean vector |
| Xor | `xor` | `xor` | 2 | Logical XOR | `(xor true false)` → `true`, `(xor arr1 arr2)` → boolean vector |

### List/Sequence Functions
| Function | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Count/length | `count` or `#` | 1 | Number of elements | `count 1 2 3 4` → `4` |
| Reverse | `reverse` or `|:` | 1 | Reverse order | `reverse 1 2 3` → `3 2 1` |
| Sort | `sort` or `asc` | 1 | Sort ascending | `sort 3 1 4 1 5` → `1 1 3 4 5` |
| Sort descending | `desc` | 1 | Sort descending | `desc 3 1 4` → `4 3 1` |
| Group | `group` | 1 | Group identical elements | `group 1 2 1 3` → Dictionary |
| Distinct | `distinct` | 1 | Unique elements | `distinct 1 2 1 3 2` → `1 2 3` |
| Join | `join` or `,` | 2 | Concatenate/join | `(1 2), (3 4)` → `1 2 3 4` |
| Take | `take` or `#` | 2 | Take first N elements | `3 take 1 2 3 4 5` → `1 2 3` |
| Drop | `drop` | 2 | Drop first N elements | `2 drop 1 2 3 4 5` → `3 4 5` |
| Head | `head` | 1 | First element(s) | `head 1 2 3` → `1` |
| Tail | `tail` | 1 | Last element(s) | `tail 1 2 3` → `3` |
| Index of | `index` or `?` | 2 | Find index of element | `3 ? 1 2 3 4` → `2` |
| Find | `find` | 2 | Boolean membership test | `3 find 1 2 3 4` → `1` |
| Raze/flatten | `raze` or `,/` | 1 | Flatten nested lists | `raze (1 2; 3 4)` → `1 2 3 4` |
| Enlist | `enlist` | 1 | Wrap in list | `enlist 5` → `,5` |
| First | `first` | 1 | First element | `first 10 20 30` → `10` |
| Last | `last` | 1 | Last element | `last 10 20 30` → `30` |

### Type & Conversion Functions
| Function | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Type | `type` or `@` | 1 | Data type of argument | `type 1 2 3` → `-7h` (int vector) |
| Cast | `cast` | 2 | Convert to type | `"i" cast "1 2 3"` → `1 2 3` |
| String | `string` | 1 | Convert to string | `string 123` → `"123"` |
| Parse | `parse` | 1 | Parse string to value | `parse "1 2 3"` → `1 2 3` |
| Integer | `int` | 1 | Convert to integer | `int 3.7 2.1` → `3 2` |
| Float | `float` | 1 | Convert to float | `float 3 2` → `3.0 2.0` |

### String Functions
| Function | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| String length | `strlen` | 1 | Length of string | `strlen "hello"` → `5` |
| String concatenate | `,` | 2 | Join strings | `"hello", " ", "world"` → `"hello world"` |
| Substring | `substring` | 3 | Extract substring | `0 5 substring "hello"` → `"hello"` |
| String search | `search` | 2 | Find substring position | `"ll" search "hello"` → `2` |
| String split | `split` | 2 | Split by delimiter | `" " split "a b c"` → `("a"; "b"; "c")` |
| String join | `join` | 2 | Join with delimiter | `" " join ("a"; "b"; "c")` → `"a b c"` |
| String upper | `upper` | 1 | Convert to uppercase | `upper "Hello"` → `"HELLO"` |
| String lower | `lower` | 1 | Convert to lowercase | `lower "Hello"` → `"hello"` |
| Trim | `trim` | 1 | Remove leading/trailing whitespace | `trim " hello "` → `"hello"` |

### Statistical Functions
| Function | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Sum | `sum` | 1 | Sum of elements | `sum 1 2 3 4` → `10` |
| Average/Mean | `avg` or `mean` | 1 | Arithmetic mean | `avg 2 4 6` → `4.0` |
| Minimum | `min` | 1 | Minimum value | `min 3 1 4` → `1` |
| Maximum | `max` | 1 | Maximum value | `max 3 1 4` → `4` |
| Count | `count` | 1 | Number of elements | `count 1 2 3` → `3` |
| Variance | `var` | 1 | Population variance | `var 1 2 3` → `0.667` |
| Standard deviation | `dev` or `std` | 1 | Population std dev | `dev 1 2 3` → `0.816` |
| Median | `median` | 1 | Median value | `median 1 2 3 4 5` → `3` |
| Mode | `mode` | 1 | Most frequent value | `mode 1 2 2 3` → `2` |

### Set Operations
| Function | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Union | `union` | 2 | Unique elements from both | `1 2 3 union 3 4 5` → `1 2 3 4 5` |
| Intersection | `inter` | 2 | Common elements | `1 2 3 inter 2 3 4` → `2 3` |
| Difference | `diff` | 2 | Elements in first not in second | `1 2 3 diff 2 4` → `1 3` |
| Subset | `subset` | 2 | Test if first is subset of second | `1 2 subset 1 2 3` → `1` |

### Matrix/Array Functions
| Function | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Transpose | `transpose` or `+` | 1 | Transpose matrix | `transpose (1 2; 3 4)` → `(1 3; 2 4)` |
| Matrix multiply | `matmul` or `#` | 2 | Matrix multiplication | `(1 2; 3 4) matmul (5 6; 7 8)` → result |
| Reshape | `reshape` | 2 | Change shape | `(2 3) reshape 1..6` → 2x3 matrix |
| Flatten | `flatten` | 1 | Flatten to 1D | `flatten (1 2; 3 4)` → `1 2 3 4` |
| Diagonal | `diag` | 1 | Extract diagonal | `diag (1 2 3; 4 5 6; 7 8 9)` → `1 5 9` |
| Identity | `identity` | 1 | Create identity matrix | `identity 3` → `(1 0 0; 0 1 0; 0 0 1)` |

---

## Part 2: Adverbs (Higher-Order Operators)

Adverbs modify how functions behave by applying them in different ways to data.

### Each (Apply to Each Element)
| Adverb | Symbol | Arity | Description | Example |
|--------|--------|-------|-------------|---------|
| Each | `'` | 1 or 2 | Apply function to each element independently | `(+; 1 2 3; 10)` → `11 12 13` |
| Each-left | `\` | 2 | Apply function with fixed left arg to each right arg | `2 \* (1 2 3)` → `2 4 6` |
| Each-right | `/` | 2 | Apply function with fixed right arg to each left arg | `(1 2 3) /* 2` → `2 4 6` |
| Each-prior | `':` | 2 | Apply function between each element and previous | `+': 1 2 3 4` → `1 3 5 7` |

### Fold/Reduce Operations
| Adverb | Symbol | Arity | Description | Example |
|--------|--------|-------|-------------|---------|
| Over/Fold-right | `/` | 2 | Reduce from right to left | `+/ 1 2 3 4` → `10` |
| Scan/Partial sums | `\` | 2 | Cumulative fold (return all intermediate results) | `+\ 1 2 3 4` → `1 3 6 10` |
| Reduce-left | `fold-left` | 2 | Reduce from left to right | `fold-left - 10; (1 2 3)` → `4` |

### Windowing/Convolution
| Adverb | Symbol | Arity | Description | Example |
|--------|--------|-------|-------------|---------|
| Window | `/:` | 3 | Apply function to sliding windows | `(+/):2 (1 2 3 4 5)` → `(1+2; 2+3; 3+4; 4+5)` |
| N-gram | `-/:` | 2 | Generate n-grams | `-/:2 (1 2 3 4)` → `((1 2); (2 3); (3 4))` |

### Grouping/Aggregation
| Adverb | Symbol | Arity | Description | Example |
|--------|--------|-------|-------------|---------|
| Group by | `group-by` | 2 | Group elements by key function | `group-by (% 2; (1 2 3 4))` → `{0:(2;4), 1:(1;3)}` |
| Aggregate | `agg` | 2 | Apply function to groups | `agg (+; group-by ...)` → grouped sums |

### Control Flow Adverbs
| Adverb | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Amend | `@` | 2 | Apply function at index | `@[1; +; 5; x]` → Set index 1 to x[1]+5 |
| Conditional (if-then-else) | `?` | 3 | Ternary conditional | `if-then-else (x > 0; +; -)` |

### Composition Adverbs
| Adverb | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Compose | `@` | 2 | Function composition | `(sqrt @abs) -5` → `2.236` |
| Pipe | `\|` | 2 | Pipeline (reverse composition) | `5 \| abs \| sqrt` → `2.236` |

### Iteration Adverbs
| Adverb | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Iterate | `iterate` | 2 | Apply function N times | `iterate (+1; 5; 10)` → `15` |
| Repeat | `repeat` | 2 | Repeat N times | `repeat ("ab"; 3)` → `"ababab"` |
| While | `while` | 2 | Apply while condition true | `while (>; 10; -1)` → decrements from 10 to 0 |
| Until | `until` | 2 | Apply until condition true | `until (<=; 0; 100)` → increments until ≤ 0 |

### Parallel Adverbs
| Adverb | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Each-parallel | `:` | 1 or 2 | Parallel map (each element in parallel) | `(+; 1..1000000; 10) :` |
| Parallel-fold | `/:` | 2 | Parallel reduce | `+/:` on large data |

### Filtering Adverbs
| Adverb | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Select/Filter | `filter` or `#` | 2 | Keep elements where predicate is true | `filter (>; (1 2 3 4); 2)` → `3 4` |
| Reject | `reject` | 2 | Keep elements where predicate is false | `reject (>; (1 2 3 4); 2)` → `1 2` |
| Partition | `partition` | 2 | Split into matching/non-matching | `partition (>; (1 2 3 4); 2)` → `((3 4); (1 2))` |

### Mapping Adverbs
| Adverb | Symbol | Arity | Description | Example |
|----------|--------|-------|-------------|---------|
| Map | `map` or `'` | 2 | Apply function to each element | `map (+; (1 2 3); 10)` → `11 12 13` |
| Map2 | `map2` | 3 | Apply binary function to paired elements | `map2 (+; (1 2 3); (10 20 30))` → `11 22 33` |
| Mapcat | `mapcat` | 2 | Map and flatten result | `mapcat (enlist; (1 2 3))` → `1 2 3` |
| Zip | `zip` | 2+ | Interleave arrays | `zip ((1 2); (10 20))` → `(1 10 2 20)` |

---

## Implementation Priority

### High Priority (Core q Semantics)
1. **Each** (`'`) - Essential for vectorization
2. **Over/Fold** (`/`) - Critical for aggregation
3. **Scan** (`\`) - Cumulative operations
4. **Arithmetic** (+, -, *, /, mod, etc.) - Foundation
5. **Comparison** (=, <, >, <=, >=) - Essential predicates
6. **List ops** (take, drop, join, reverse, sort) - Basic manipulation
7. **Select/Filter** - Conditional extraction
8. **Map** - Function application pattern

### Medium Priority (Common Operations)
9. Group by / Aggregation
10. String operations
11. Type conversions
12. Statistical functions (sum, mean, min, max)
13. Set operations (union, intersection, difference)
14. Window/N-gram operations
15. Each-left / Each-right variants

### Lower Priority (Advanced/Specialized)
16. Parallel adverbs
17. Matrix operations (matmul, transpose)
18. Advanced iteration (while, until, iterate)
19. Composition adverbs
20. Amend operations

---

## Notes on Q Semantics

1. **Vectorization**: Most functions are implicitly vectorized; `1 2 3 + 10` broadcasts the scalar 10 to each element.

2. **Type promotion**: Operations follow q's type hierarchy; results are promoted as needed (e.g., int + float → float).

3. **Null handling**: Q has null values (represented as `::` or type-specific nulls) that propagate through operations.

4. **Dictionary/Table semantics**: Functions work on dictionaries and tables (column-oriented data) as well as lists.

5. **Atom vs. list**: Scalars are atoms; single-element lists are `,(atom)`. Operations handle both implicitly.

6. **Operator overloading**: Some symbols (e.g., `+`, `*`, `#`) have multiple meanings depending on argument types and context.

---

## Cross-Reference: FOL Implementation Mapping

Where these q functions/adverbs map to existing FOL implementations:

- **Arithmetic**: `src/arithmetic-functions.lisp` (+, -, *, /, inc, dec, abs, sqrt, etc.)
- **Comparisons**: `src/compareops.lisp` (=, <, >, <=, >=, min, max)
- **Logical**: `src/logical-operation-functions.lisp` (and, or, not, xor)
- **Collection ops**: `src/collection-functions.lisp` (vector, dict, set operations)
- **Sequence ops**: `src/merged-functions.lisp` (map, filter, take, drop, etc.)
- **String ops**: `src/string-functions.lisp`

**TODO**: Build adverb implementations in new `src/adverbs.lisp` and `src/q-functions.lisp`.
