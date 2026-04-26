# Expression Interpreter — CLOS Adoption Cost Benchmark

**Platform:** SBCL 2.6.0, AMD Ryzen 9 5900X, Windows 11
**FOL persistent objects + predicate dispatch vs. standard CL CLOS**

---

## Motivation

The AST-optimizer and LSim benchmarks were designed with FOL's value proposition
in mind.  This benchmark answers a different question:

> *What is the overhead of porting an ordinary CLOS codebase to FOL?*

The CL baseline uses **standard CLOS throughout** — `defclass`, `defgeneric`,
`defmethod` — not `defstruct` or `typecase`.  This is the realistic starting
point for a practitioner considering adoption.

---

## Setup

A small expression interpreter over 7 CLOS node types:

| Node class | Slots | Represents |
|---|---|---|
| `num-expr` / `<num-expr>` | `val` | Integer literal |
| `var-expr` / `<var-expr>` | `name` | Variable reference |
| `add-expr` / `<add-expr>` | `left, right` | Addition |
| `mul-expr` / `<mul-expr>` | `left, right` | Multiplication |
| `let-expr` / `<let-expr>` | `bvar, bval, body` | Variable binding |
| `if-expr`  / `<if-expr>`  | `test, consequent, alternate` | Conditional |
| `neg-expr` / `<neg-expr>` | `arg` | Negation |

Three generic functions are defined — all added *without modifying class
definitions*, demonstrating the "new operations" dimension of the Expression
Problem:

- **`eval-expr (expr env)`** — evaluates the expression in an environment
- **`pretty (expr)`** — pretty-prints to a string
- **`free-vars (expr bound)`** — computes the set of free variable names

### Key difference: the environment

| | CL | FOL |
|---|---|---|
| Environment type | Mutable `hash-table` | Persistent dict `{:x 3 …}` |
| `let-expr` binding | Shadow-and-restore (mutate, recurse, undo) | `(assoc env bvar v)` — functional update |
| Thread safety | Not safe without locking | Lock-free (snapshot semantics) |

The corpus is 50 depth-5 expression trees, seeded so that all 7 node types
appear in realistic proportions.  Each benchmark iteration calls `eval-expr`,
`pretty`, and `free-vars` on all 50 trees.

---

## Results

```
sbcl --noinform --non-interactive --load run-interp-bench.lisp
```

### Build Phase (construct 50 trees, depth 5)

| Implementation | Time | Alloc | vs. CL |
|---|---|---|---|
| CL (mutable CLOS) | 20.11 ms | 3.81 MB | 1.0× |
| FOL (persistent objects) | 35.86 ms | 8.86 MB | 1.8× time, 2.3× memory |

### Eval Phase (1,000 iterations × 50 exprs × 3 generic functions)

| Implementation | Total time | Alloc | Time/expr | vs. CL |
|---|---|---|---|---|
| CL (CLOS dispatch + hash-table env) | 0.499 s | 224.5 MB | 9.97 µs | 1.0× |
| FOL (predicate dispatch + persistent dict) | 2.763 s | 1300.0 MB | 55.25 µs | 5.54x time, 5.79x memory |

---

## What this measures vs. the AST-optimizer benchmark

| | AST Optimizer | Interpreter (this benchmark) |
|---|---|---|
| CL baseline | `defstruct` + `typecase` | `defclass` + `defgeneric`/`defmethod` |
| Number of classes | 25 | 7 |
| Number of dispatch rules | 54 | 7 per generic function |
| Environment | None | Hash-table (CL) / persistent dict (FOL) |
| Origin of benchmark | Designed for FOL | Canonical CLOS interpreter pattern |

The AST-optimizer ratio (~202×) represents the worst case: `defstruct` is the
fastest CL baseline, 25 classes exercises a long dispatch scan, and no
environment is needed.  This benchmark uses `defclass` — the realistic
migration baseline — so the overhead of FOL's persistent metaclass over standard
CLOS (not `defstruct`) is directly visible.

Measured overhead: **5.5x time, 5.8x memory** — substantially better than the
AST-optimizer worst-case (~202x) because the CL baseline is standard CLOS
(not the faster `defstruct`) and the dispatch fan-out is narrower (7 vs. 25 classes).

Overhead breakdown:
- **Persistent slot reads:** ~1.4–2.1× per `get` vs. `slot-value`; applies to
  all three generic functions.
- **let-expr environment update:** FOL `(assoc env k v)` is O(log N) structural
  copy vs. CL O(1) hash-table mutation; the small 3-key environment limits absolute
  cost but raises per-binding allocation pressure.
- **Dispatch:** FOL predicate dispatch over 7 clauses adds overhead from a linear
  scan vs. CLOS's discriminating function.
- **free-vars collections:** FOL uses Sycamore persistent hash-sets; CL uses
  CL lists.  Allocation pressure is the dominant cost for the small free-variable
  sets in these depth-5 trees.

---

## Code diff summary

Lines changed to port the CL version to FOL:

| Category | Change |
|---|---|
| Class definitions | `(defclass name (supers) (slot ...))` → `(defclass <name> [supers] [[slot]])` |
| Slot reads | `(num-val e)` → `(get e :val)` |
| Slot constructors | `(make-instance 'num-expr :val x)` → `(make-<num-expr> :val x)` |
| let-expr eval | 6-line shadow-and-restore → 3-line `bind`/`assoc` |
| String building | `(concatenate 'string ...)` → `(str ...)` |
| Free-var sets | `nil` / `(member ...)` / `(union ...)` on CL lists → `#{}` / `(contains? ...)` / `(union ...)` on persistent sets |
| Environment | `(make-env :x 3 :y 5 :z 2)` → `{:x 3 :y 5 :z 2}` |

The structural shape of every method is identical: one clause per node type,
no predicate specializers needed (pure type dispatch), same recursion pattern.
The FOL port required no architectural changes.

---

## Hardware / environment

| | |
|---|---|
| CPU | AMD Ryzen 9 5900X |
| OS | Windows 11 Pro |
| SBCL | 2.6.0 (x86-64) |
| Heap | default |
