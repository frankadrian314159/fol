# Guards Pattern Benchmark

This report measures the cost of FOL's `:around assoc` invariant-guard pattern
versus manually coding the same guard in each Common Lisp update function.

## 1. Pattern Description

### Problem

A persistent object (`<account>`) must satisfy an invariant (balance ≥ 0) after
every update.  In plain CL, the guard must be duplicated in every update function:

```lisp
(defun deposit  (acc amount) (check-balance (- (balance acc) amount)) ...)
(defun withdraw (acc amount) (check-balance (- (balance acc) amount)) ...)
;; and any future: transfer, adjust, rollback, ...
```

Missing a single site silently breaks the invariant.

### FOL Solution

Declare the invariant *once* as an `:around` method on `assoc`.  It fires
automatically on every update to any slot of `<account>`, regardless of which
function initiates the change:

```lisp
(defmethod assoc :around [(acc <account>) slot val]
  (bind [result (call-next-method)]
    (when (< (:balance result) 0)
      (error "~A: balance cannot go negative" (:owner acc)))
    result))
```

The original object (before the attempted update) remains an immutable snapshot,
so the rollback is free — no undo logic required.

## 2. Benchmark Setup

- **Benchmark**: 1,000,000 consecutive valid deposits (`deposit acc 1`)
  starting from balance = 0.  The guard fires on every call but always passes.
- **CL Implementation**: `guards-cl::deposit` — direct struct copy + inline
  balance check.
- **FOL Implementation**: `guards::deposit` → `assoc` → `:around` → balance
  check → return.
- **Environment**: SBCL 2.6.0, Windows 11, AMD Ryzen 9 5900X, 64 GB RAM.

## 3. Performance Results

| Implementation | Time (1M ops) | Avg Time/op | Bytes Consed | Ratio |
| :--- | ---: | ---: | ---: | ---: |
| **Common Lisp** (manual guard per fn) | 0.065 s | 0.07 µs | 30.56 MB | 1.0× |
| **FOL** (`:around assoc`) | 1.507 s | 1.51 µs | 244.07 MB | 23.2× |

**Correctness**: both implementations return 1,000,000 (the final balance).

## 4. Analysis

### Time Overhead (23×)

The 23× slowdown on the happy path comes from several cumulative costs:

1. **Generic dispatch** — `fol.core:assoc` is a CLOS generic function.  Every
   call dispatches through the SBCL PCL discriminating function.
2. **`:around` method lookup and invocation** — an additional
   `call-next-method` trampoline is added.
3. **Persistent-object `assoc` mechanics** — copying the object with structural
   sharing (Sycamore hash-map path copy) is more expensive than allocating one
   two-field struct.

The CL baseline creates a raw `defstruct` instance with two slots and performs
one inline comparison — the minimal possible work.

### Memory Overhead (8×)

FOL allocates ~244 MB vs 30 MB for CL over 1M operations (≈244 bytes vs 31 bytes
per update).  The persistent-object update copies the HAMT path for the
modified slot (typically 1–3 nodes at ~40 bytes each).  The CL struct copies two
pointer-sized slots into a fresh allocation (~32 bytes for the header + 2 slots).

### Engineering Trade-off

| Dimension | CL (manual) | FOL (`:around assoc`) |
| :--- | :--- | :--- |
| Guard coverage | Per-function — can be omitted | Every update — structurally enforced |
| Code duplication | Repeats in every update fn | Single declaration |
| Rollback complexity | Must manually restore state | Free — original is immutable |
| Runtime cost (valid path) | 0.07 µs | 1.51 µs |
| Memory per update | ~31 B | ~244 B |

The overhead is justified when the invariant is cross-cutting (applies to many
update paths) and when correctness matters more than raw throughput.  For a
high-frequency inner loop where the guard has already been verified at a higher
level, the CL approach remains preferable.

## 5. Running the Benchmark

```
sbcl --noinform --non-interactive --load benchmarks/run-guards-bench.lisp
```

## 6. Source Files

| File | Description |
| :--- | :--- |
| `benchmarks/fol-code/guards.fol` | FOL source |
| `benchmarks/transpiled-fol-code/guards.lisp` | Transpiled output |
| `benchmarks/lisp-code/guards.lisp` | Native CL equivalent |
| `benchmarks/run-guards-bench.lisp` | Runner script |
