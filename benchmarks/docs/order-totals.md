# Order Totals Benchmark

This report measures the cost of FOL's dispatch-based keyword-accessor `get` versus
the compiler's interprocedural GET-bypass, which proves a function parameter's
persistent-object class from its call sites and compiles keyword-accessor reads
to a direct, world-guarded `slot-value`.

## 1. Pattern Description

### Problem

A read-heavy helper function takes a persistent-object parameter and reads several
fields off it via keyword accessors:

```fol
(defn order-total [o]
  (+ (get o :subtotal) (+ (get o :tax) (get o :shipping))))
```

By default `get` on a persistent object goes through generic dispatch: `class-of`,
a hash lookup mapping the keyword to a slot name, a `slot-boundp` check, then
`slot-value`. If the compiler can prove `o`'s class statically, all of that
collapses to a direct `slot-value` read.

### FOL Solution

`interprocedural-types.lisp`'s parameter-type analysis proves a function's
parameter type from every call site in the compilation unit — including a call
site that passes the result of another function, provided *that* function's own
return type is proven from its tail expression (a literal constructor call):

```fol
(defn build-order [i]
  (make-<order> :subtotal (* i 3) :tax (* i 1) :shipping 5))

(defn order-total [o]
  (+ (get o :subtotal) (+ (get o :tax) (get o :shipping))))

(defn sum-orders [n]
  (loop [i 0 total 0]
    (if (< i n)
      (recur (inc i) (+ total (order-total (build-order i))))
      total)))
```

`order-total`'s only call site passes `(build-order i)`; `build-order`'s tail
expression is a literal `make-<order>` call, so its return class is proven
`<order>`, which in turn proves `order-total`'s own parameter. The compiler emits
each `get` as a world-guarded direct slot read instead of generic dispatch.

This is a **different mechanism from transient conversion** (see
`derived-value-invalidation.fol`) — no accumulator is mutated in place here, and
none of `<order>`'s three fields are ever reassigned. The record is constructed
fresh each iteration and read once; the win comes entirely from proving its type
across the two function calls, not from in-place update.

### Companion control: `order-totals-unprovable.fol`

Same loop shape, same amount of work, but `build-order2` is written as a
**multi-clause** `defn`. The interprocedural analysis only tracks single-clause
functions (matching `%infer-returns-kind`'s existing precedent in
`escape-analysis.lisp` — a multi-clause function destructures per-clause
synthetic parameters with no single stable positional identity to attach a proof
to), so `build-order2`'s return class is never computed even though the only
clause actually reached is identical to `build-order`'s single one.
`order2-total`'s reads therefore stay on the generic dispatch path. This isolates
the GET-bypass's own contribution: everything else about the two variants is
identical.

## 2. Benchmark Setup

- **Workload**: 1,000,000 rounds of (construct one fresh `<order>`, read three
  fields via keyword accessor, accumulate). Unlike DVI's cart, the record is
  never loop-carried — it is born and read within a single iteration and never
  threaded through `recur`.
- **CL Implementation**: `order-totals-cl::sum-orders` — a native `defstruct`,
  built fresh each iteration, read via direct slot accessors.
- **FOL Implementation (provable)**: `sum-orders` (`order-totals.fol`) — the
  GET-bypass fires on all three reads.
- **FOL Implementation (unprovable control)**: `sum-orders2`
  (`order-totals-unprovable.fol`) — identical work, generic `get` throughout.
- **Environment**: SBCL 2.6.0, Windows 11, AMD Ryzen 5 7430U.
- **Methodology**: mean of 5 timed calls, each preceded by a forced full GC,
  reported as mean (sample stddev in parentheses below); one untimed warmup call
  first. Matches the protocol used for the paper's whole-program benchmarks.

## 3. Performance Results

| Implementation | Time (1M orders) | Time/order | Bytes Consed | vs. CL |
| :--- | ---: | ---: | ---: | ---: |
| **Common Lisp** (native struct) | 0.090 s (±0.005) | 90 ns | 30.5 MB | 1.0× |
| **FOL, provable** (SLOT-VALUE bypass) | 0.682 s (±0.025) | 682 ns | 152.6 MB | 7.56× |
| **FOL, unprovable control** (generic GET) | 1.278 s (±0.029) | 1278 ns | 213.5 MB | 14.17× |

**GET-bypass's own contribution** (unprovable / provable): **1.87× time, 1.40×
memory** — isolated from everything else, since the two variants differ only in
whether the analysis can prove `o`'s type.

**Correctness**: all three return 2,000,003,000,000.

## 4. Analysis

### Where the remaining 7.56× (provable vs. CL) goes

Even with the bypass firing on every read, FOL is still ~7.6× slower than the
hand-written CL struct version. The gap is not in the reads any more — it's in
construction: `make-<order>` allocates a CLOS instance via `allocate-instance`
plus per-slot `setf`s and the persistent-object bookkeeping slots
(`%transient-owner`, `%schema-version`), roughly 5× the bytes-per-object of a
plain `defstruct` (152.6 MB vs. 30.5 MB for 1M objects, matching the memory
ratio almost exactly). This is the cost of CLOS-backed persistent objects
generally, not something the GET-bypass addresses or was meant to.

### Why this benchmark, and not DVI, demonstrates the win

DVI's `cart` is a loop-carried accumulator threaded through `recur` and mutated
via `assoc`. Proving its type would require tracking loop-carried variable types
(not implemented) and treating `assoc` as class-preserving under a trust check —
which, traced by hand, still would not clear DVicart's own `:around` method on
`assoc` even though that customization happens to preserve class (see project
history). `order-total`'s parameter, by contrast, is proven from an ordinary
function call site whose argument is itself a proven-returning function — no
loop-carried tracking or mutation-preservation reasoning needed. This benchmark
was constructed specifically to isolate that provable shape.

## 5. Running the Benchmark

```
sbcl --noinform --non-interactive --load benchmarks/run-order-totals-bench.lisp
```

## 6. Source Files

| File | Description |
| :--- | :--- |
| `benchmarks/fol-code/order-totals.fol` | FOL source (provable) |
| `benchmarks/fol-code/order-totals-unprovable.fol` | FOL source (control) |
| `benchmarks/transpiled-fol-code/order-totals.lisp` | Transpiled output (provable) |
| `benchmarks/transpiled-fol-code/order-totals-unprovable.lisp` | Transpiled output (control) |
| `benchmarks/lisp-code/order-totals.lisp` | Native CL equivalent |
| `benchmarks/run-order-totals-bench.lisp` | Runner script |
