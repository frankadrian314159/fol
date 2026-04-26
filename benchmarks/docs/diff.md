# Structural Diff Pattern Benchmark

This report measures the cost of FOL's `:around assoc` structural-diff pattern
versus explicitly computing diffs in Common Lisp.

## 1. Pattern Description

### Problem

A system needs to count how many slots of a record actually changed during an
update.  In mutable CL, detecting changes requires an explicit before-snapshot:

```lisp
(defun update-all (m cpu memory disk net iops)
  (let ((old-cpu    (metric-cpu    m))   ; must snapshot BEFORE overwriting
        (old-memory (metric-memory m))
        (old-disk   (metric-disk   m))
        (old-net    (metric-net    m))
        (old-iops   (metric-iops   m)))
    (let ((new-m (make-metric :cpu cpu :memory memory :disk disk
                              :net net :iops iops
                              :changes (+ (metric-changes m) ...))))
      ...)))  ; compare every slot explicitly
```

Every struct that needs change-counting must repeat this snapshot-and-compare
boilerplate.  Adding a new slot means updating the snapshot and comparison in
every caller.

### FOL Solution

Because persistent objects are immutable, both the pre-update snapshot (`obj`)
and the post-update snapshot (`(call-next-method)`) coexist during the
`:around` method.  Change counting becomes a single, reusable method on
`<diffable>`:

```fol
(defmethod assoc :around [(obj <diffable>) key val]
  (bind [old-val (get obj key)
         result  (call-next-method)]
    (if (and (not (= key :_changes))
             (not (= old-val val)))
      (assoc result :_changes (inc (:_changes result)))
      result)))
```

Any class that inherits from `<diffable>` gains automatic change-counting at
zero cost to the domain code.  The domain class `<metric>` adds no
change-counting logic of its own:

```fol
(defclass <metric> [<diffable>]
  [[cpu    :initarg :cpu    :initform 0.0]
   [memory :initarg :memory :initform 0.0]
   [disk   :initarg :disk   :initform 0.0]
   [net    :initarg :net    :initform 0.0]
   [iops   :initarg :iops   :initform 0]])
```

### Why This Pattern Is Inconvenient in CL and Clojure

**Common Lisp.**  A CLOS `defgeneric assoc :around` method could intercept
slot writes.  The problem is that in a mutable system, at the time the
`:around` body runs, only *one* version of the object exists — the one being
mutated.  `(call-next-method)` returns the same object reference after
modifying it in place.  There is nothing to compare against.  The only escape
is to snapshot every slot *before* calling `call-next-method`, but that
requires knowing the slot list at the point of the `:around` method — defeating
the open-closed purpose of inheritance.  Each new slot added to a subclass
silently breaks the snapshot if the `:around` author forgot to include it.

**Clojure.**  Clojure's persistent data structures mean that both the old and
new values coexist after a `clojure.core/assoc` call — so the snapshot problem
disappears.  The obstacle is dispatch: `clojure.core/assoc` is a core function
that cannot be intercepted transparently.  A `defprotocol` can define a custom
`assoc-tracked` per type, but every call site must explicitly use
`assoc-tracked` instead of `assoc`; any code that calls plain `assoc` silently
bypasses the tracking.  Clojure protocols also have no method qualifiers —
there is no `:around` and no `call-next-method` — so composing the
change-counting across an inheritance hierarchy requires each class to
explicitly delegate to its super-protocol implementation.  The composition that
FOL provides automatically must be hand-wired at every level.

## 2. Benchmark Setup

- **Benchmark**: 500,000 iterations, each performing 5 slot updates on a
  `<metric>` object (resetting `_changes` to 0 first, then setting `cpu`,
  `memory`, `disk`, `net`, and `iops`).  The `_changes` counter after each
  iteration is accumulated in a running total, which becomes the final result
  (expected: 2,500,000 = 5 changes × 500,000 iterations).
- **CL Implementation**: `diff-cl::run-bench` — `defstruct metric` with
  read-only slots; `%update-all` saves old slot values before the struct copy
  and compares each slot to count changes.
- **FOL Implementation**: `diff::run-bench` — `<metric>` inherits from
  `<diffable>`; change counting is fully automatic via `:around assoc`.
- **Environment**: SBCL 2.6.0, Windows 11, AMD Ryzen 9 5900X, 64 GB RAM.

## 3. Performance Results

| Implementation | Time (500K iters) | Avg Time/op | Bytes Consed | Ratio |
| :--- | ---: | ---: | ---: | ---: |
| **Common Lisp** (explicit before-snapshot) | 0.073 s | 0.15 µs | 30.50 MB | 1.0× |
| **FOL** (`:around assoc` auto-diff) | 6.489 s | 12.98 µs | 1769.71 MB | 89.1× |

Each "op" is one complete 5-slot update iteration.

**Correctness**: both implementations return 2,500,000 (5 changes × 500,000 iterations).

## 4. Analysis

### Time Overhead (89×)

Each iteration makes 6 `assoc` calls (1 reset + 5 slot updates).  Each
`assoc` call:

1. Dispatches through the `fol.core:assoc` CLOS generic function.
2. Invokes the `<diffable>`:around method, which captures `old-val` and
   `result` (two separate persistent-object lookups and one HAMT path copy).
3. Calls `assoc` again recursively if a change is detected (incrementing
   `_changes`).

The CL baseline performs one struct allocation per iteration with inline slot
comparisons — the minimum possible work.  The 89× ratio reflects the
compounding of CLOS dispatch overhead, HAMT path-copy allocation, and the
extra recursive `assoc` call per changed slot.

### Memory Overhead (58×)

FOL allocates ~1,770 MB vs 30 MB over 500K iterations (≈3,539 bytes vs 61
bytes per iteration).  Each of the 6 `assoc` calls in the FOL path allocates a
new HAMT path (1–3 nodes × ~40 bytes), and the change-detection branches
trigger additional allocations for the `_changes` increment.  The CL struct
copy allocates one fixed-size record (~61 bytes) per iteration.

### Engineering Trade-off

| Dimension | CL (explicit) | FOL (`:around assoc`) |
| :--- | :--- | :--- |
| Change-counting code | In every update function | Single `<diffable>` declaration |
| New-slot maintenance | Must update snapshot + compare | Automatic |
| Snapshots coexist | No — requires explicit copy | Yes — persistent semantics |
| Runtime cost (5 slots) | 0.15 µs | 12.98 µs |
| Memory per iteration | ~61 B | ~3,539 B |

The FOL approach shines when the diff logic is cross-cutting (many classes,
many update paths) and when the snapshot semantics are already valued for
correctness.  For hot loops where performance is critical and the diff logic is
localised to one struct, the CL approach is preferable.

## 5. Running the Benchmark

```
sbcl --noinform --non-interactive --load benchmarks/run-diff-bench.lisp
```

## 6. Source Files

| File | Description |
| :--- | :--- |
| `benchmarks/fol-code/diff.fol` | FOL source |
| `benchmarks/transpiled-fol-code/diff.lisp` | Transpiled output |
| `benchmarks/lisp-code/diff.lisp` | Native CL equivalent |
| `benchmarks/run-diff-bench.lisp` | Runner script |
