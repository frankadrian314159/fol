# Hierarchical Speculative Execution Benchmark

This report measures the cost of FOL's hierarchical `:around assoc` constraint
pattern versus manually coding all constraint levels in Common Lisp.

## 1. Pattern Description

### Problem

A domain object (`<regulated-account>`) must satisfy three nested constraints
on every update:

1. **Level 1 — Non-negative values** (`<validated>`): reject any negative slot value.
2. **Level 2 — Balance ceiling** (`<bounded-account>`): reject updates that would
   push the balance above a per-account `limit`.
3. **Level 3 — Per-transaction delta cap** (`<regulated-account>`): reject any
   single deposit that exceeds `tx-cap`.

In mutable CL, these three levels must all be flattened into one validation
function, because there is no persistent snapshot to "fall back to":

```lisp
(defun %try-update-balance (acc new-balance)
  ;; Level 3: per-transaction cap
  (when (> (- new-balance (ra-balance acc)) (ra-tx-cap acc))
    (return-from %try-update-balance acc))
  ;; Level 1: non-negative
  (when (< new-balance 0)
    (return-from %try-update-balance acc))
  ;; Level 2: balance ceiling
  (when (> new-balance (ra-limit acc))
    (return-from %try-update-balance acc))
  ;; All constraints passed
  (copy-regulated-account acc :balance new-balance))
```

Adding a new constraint class (e.g., rate-limiting) requires modifying this
function and every caller that needs the new constraint — violating the
open/closed principle.

### FOL Solution

Each class contributes exactly one `:around assoc` method.  When the chain
fires, the most-derived class (`<regulated-account>`) runs first and may
`call-next-method` to delegate up the hierarchy or return the current object
unchanged as a zero-cost rejection:

```fol
;; Level 1: most permissive — all validated objects
(defmethod assoc :around [(obj <validated>) key val]
  (if (< val 0)
    obj                   ; reject: return old snapshot
    (call-next-method)))  ; accept: propagate up

;; Level 2: balance ceiling
(defmethod assoc :around [(acc <bounded-account>) key val]
  (bind [tentative (call-next-method)]  ; tentative is result of Level 1
    (if (> (:balance tentative) (:limit acc))
      acc          ; reject: over ceiling
      tentative))) ; accept: within ceiling

;; Level 3: per-transaction delta — runs first (most specific)
(defmethod assoc :around [(acc <regulated-account>) key val]
  (if (and (= key :balance)
           (> (- val (:balance acc)) (:tx-cap acc)))
    acc                   ; reject: single tx too large
    (call-next-method)))  ; accept: within delta cap
```

### Why Rejection Is Free in FOL

In a mutable system, "returning the old object" means either returning a stale
reference (aliasing risk) or copying the whole struct before the mutation
begins.  In FOL, every persistent object *is* an immutable snapshot.  The
`:around` method already holds `obj` (or `acc`) as a live reference to the
pre-update state; returning it costs nothing beyond the function return itself.

The levels compose automatically via `call-next-method`: no changes are
required to `<validated>` or `<bounded-account>` when `<regulated-account>` is
added.  Each level is independently testable, independently extensible.

### Why This Pattern Is Inconvenient in CL and Clojure

**Common Lisp.**  CLOS `:around` method combination is available, but it
cannot express speculative rejection on mutable objects.  When the
Level-2 `:around` calls `call-next-method`, Level-1 runs and mutates the
struct in place.  By the time Level-2 receives `call-next-method`'s return
value, the object has already been modified; returning `acc` merely returns the
same pointer to the now-mutated object.  The "reject and return old state"
idiom is a no-op.

The only workaround is to copy the full struct *before* every `call-next-method`
call and return the copy on rejection.  That forces the copy cost on every
speculative call, regardless of whether the update is ultimately rejected, and
every `:around` author must know to perform this copy — a fragile convention
that breaks silently when a new level is added by a third party.

**Clojure.**  Clojure's persistent data structures solve the aliasing problem:
a pre-update value can safely be returned after the update because values are
immutable.  The remaining obstacle is composition.  Clojure protocols
(`defprotocol` / `defrecord`) have no method qualifiers and no
`call-next-method`.  To chain three validation levels, callers must explicitly
thread a continuation:

```clojure
(defprotocol Constrainable
  (constrain-assoc [this key val next-fn]))

(defrecord ValidatedRecord [...]
  Constrainable
  (constrain-assoc [this key val next-fn]
    (if (< val 0) this (next-fn this key val))))
```

The continuation `next-fn` must be assembled by the caller and updated
whenever a new level is added.  This is the CL manual-flattening problem
expressed differently: the composition is not automatic, and adding a new
constraint level requires modifying either the caller or a central wiring
point.  Clojure's `defmulti` dispatches on a single computed value and cannot
express "run all applicable methods in priority order" — that is CLOS method
combination, not multi-method dispatch.

## 2. Benchmark Setup

- **Benchmark**: 1,000,000 consecutive deposits of 1 unit each, starting from
  balance = 0.  All three validation levels are traversed on every call.
  The `tx-cap` is set to 1,000,000 and `limit` to 2,000,000, so all deposits
  pass cleanly.  The final result is the balance (expected: 1,000,000).
- **CL Implementation**: `hse-cl::run-bench` — `defstruct regulated-account`
  with read-only slots; all three constraint levels flattened into
  `%try-update-balance`.
- **FOL Implementation**: `hse::run-bench` — three-class hierarchy; each class
  has one `:around assoc` method composed via `call-next-method`.
- **Environment**: SBCL 2.6.0, Windows 11, AMD Ryzen 9 5900X, 64 GB RAM.

## 3. Performance Results

| Implementation | Time (1M ops) | Avg Time/op | Bytes Consed | Ratio |
| :--- | ---: | ---: | ---: | ---: |
| **Common Lisp** (all constraints in one flat function) | 0.054 s | 0.05 µs | 45.77 MB | 1.0× |
| **FOL** (three `:around` methods via `call-next-method`) | 1.257 s | 1.26 µs | 411.81 MB | 23.4× |

**Correctness**: both implementations return 1,000,000 (the final balance).

## 4. Analysis

### Time Overhead (23×)

Each `deposit` call invokes the `assoc` generic function once.  In the FOL
path, SBCL PCL dispatches through three `:around` methods and one primary
method before performing the actual HAMT path copy.  In the CL path, `deposit`
calls `%try-update-balance` directly — one function call with three integer
comparisons and one struct copy.  The 23× ratio is consistent with the guards
benchmark (also ~23×), which performs a single `:around` method; the three
levels here impose no additional multiplicative cost because SBCL's effective
method is compiled once and cached.

### Memory Overhead (9×)

FOL allocates ~412 MB vs 46 MB over 1M deposits (≈412 bytes vs 46 bytes per
update).  The persistent-object update allocates a HAMT path copy (1–3 nodes
×~40 bytes each) plus the CLOS frame overhead for each `:around` invocation.
The CL struct copy allocates one fixed-size record per deposit (~46 bytes
including the struct header and four slots).

### Comparison with Guards Benchmark

The guards benchmark (single `:around`) shows the same ~23× time overhead.
This confirms that the dominant cost is persistent-object HAMT update, not the
method-combination chain itself.  The memory ratio here (9×) is lower than
guards (8×), a slight variation within measurement noise.

### Engineering Trade-off

| Dimension | CL (manual) | FOL (`:around assoc`) |
| :--- | :--- | :--- |
| Constraint co-location | All levels in one function | One class per level |
| Adding a new level | Modify existing function + all callers | New subclass only |
| Rejection cost | Struct copy or alias risk | Free — original is immutable |
| Open/closed principle | Violated | Respected |
| Runtime cost (valid path) | 0.05 µs | 1.26 µs |
| Memory per update | ~46 B | ~412 B |

The pattern is most valuable when the constraint hierarchy is open to extension,
when levels are independently reusable across different classes, or when the
rollback semantics need to be correct by construction.  For a fixed, single-level
guard in a performance-critical loop, the CL approach is preferable.

## 5. Running the Benchmark

```
sbcl --noinform --non-interactive --load benchmarks/run-hse-bench.lisp
```

## 6. Source Files

| File | Description |
| :--- | :--- |
| `benchmarks/fol-code/hierarchical-speculative-execution.fol` | FOL source |
| `benchmarks/transpiled-fol-code/hierarchical-speculative-execution.lisp` | Transpiled output |
| `benchmarks/lisp-code/hierarchical-speculative-execution.lisp` | Native CL equivalent |
| `benchmarks/run-hse-bench.lisp` | Runner script |
