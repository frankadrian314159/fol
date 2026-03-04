# Reducers

`fol.lib.reducers` provides chunk-based parallel reduction operations. Unlike the element-per-task model in `fol.lib.parallel`, reducers split a collection into fixed-size chunks and reduce each chunk independently on the thread pool, then combine the partial results. This is more efficient for expensive reductions over large collections because it amortises task-submission overhead.

---

## Threading model

- The same global work-stealing thread pool as `fol.lib.parallel` is used.
- Collections smaller than the chunk size `n` are always reduced **serially** on the calling thread — no threads are spawned.
- Partial results are combined **left-to-right** to preserve ordering when the combine function is not commutative.

---

## preduce                                                          *[function]*

```
(preduce fn init coll &optional (n 64)) → value
```

Parallel reduction over a collection. Splits `coll` into chunks of size `n`, reduces each chunk serially using `fn`, then reduces the partial results together with `init`.

`fn` must support being called with **zero arguments** to produce an identity value used as the starting accumulator for each chunk. This matches the zero-argument protocol from Clojure's reducers.

| Parameter | Description |
|-----------|-------------|
| `fn` | `() → identity`, `(acc elem) → acc` |
| `init` | Initial value combined with all partial results at the end |
| `coll` | Input collection |
| `n` | Chunk size (default 64) |

```fol
(preduce + 0 (range 1000))          ; => 500500
(preduce * 1 [1 2 3 4 5])           ; => 120
```

**Requirement:** `fn` must be associative and support `(fn)` returning an identity element. Built-in arithmetic functions (`+`, `*`) satisfy this.

---

## fold                                                             *[function]*

```
(fold combine-fn reduce-fn coll &optional (n 512)) → value
```

Parallel fold with separate reduction and combination functions. Each chunk of `coll` is reduced serially using `reduce-fn`; the partial results are then merged using `combine-fn`.

Both functions must support zero-argument calls to return their identity values.

| Parameter | Description |
|-----------|-------------|
| `combine-fn` | `() → identity`, `(a b) → a` — merges two partial accumulators |
| `reduce-fn` | `() → identity`, `(acc elem) → acc` — reduces elements into an accumulator |
| `coll` | Input collection |
| `n` | Chunk size (default 512) |

```fol
(fold + + (range 1000) 50)   ; => 500500

; Building a set: reduce-fn conjoins, combine-fn unions
(fold set/union conj #{} data 100)
```

**When to use `fold` over `preduce`:** when reduction and combination are genuinely different operations (e.g. `reduce-fn` conjoins items into a local set; `combine-fn` unions two sets).

---

## fold-recursive                                                   *[function]*

```
(fold-recursive combine-fn reduce-fn coll &optional (n 512)) → value
```

Divide-and-conquer variant of `fold`. Recursively halves the collection until chunks reach size `n`, then reduces and combines bottom-up. The right half of each split is submitted to the thread pool while the left half is processed on the calling thread.

Same function signatures as `fold`. Tends to produce better work distribution when the collection size is not a multiple of `n`, at the cost of more recursive task submissions.

```fol
(fold-recursive + + (range 1000) 64)   ; => 500500
```

---

## aggregate                                                        *[function]*

```
(aggregate zero seq-op combine-op coll &optional (n 512)) → value
```

Parallel aggregate in the style of Scala's `.par.aggregate(zero)(seqOp, combOp)`.

The key distinction from `preduce` and `fold` is that **`seq-op` and `combine-op` may work on a different type from the collection elements**, enabling a single parallel pass to build accumulators of any shape — histograms, tagged tuples, sets of strings from integer inputs, etc.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `zero` | Initial accumulator. If a **function**, called with no arguments to produce a fresh accumulator for each chunk (required when the accumulator is mutable or must not be shared). If a plain value, used directly for the serial path. |
| `seq-op` | `(accumulator element) → accumulator` — reduces one element into the chunk's accumulator. Called serially within each chunk. |
| `combine-op` | `(accumulator accumulator) → accumulator` — merges two partial accumulators. Must be associative. |
| `coll` | Input collection. |
| `n` | Chunk size (default 512). Collections ≤ `n` elements use the serial path. |

### Difference from `fold`

| | `fold` | `aggregate` |
|---|---|---|
| Zero value per chunk | `(reduce-fn)` — zero-arg call | `zero` or `(funcall zero)` |
| Element type = accumulator type? | Required | **Not required** |
| Accumulator can be mutable? | No (shared via zero-arg fn) | Yes (via `zero` as function) |

### Examples

**Sum and collect in one pass** (accumulator is a tuple, input is integers):

```fol
(aggregate
  (fn [] [0 []])
  (fn [[cnt elems] x] [(inc cnt) (conj elems x)])
  (fn [[ca ea] [cb eb]] [(+ ca cb) (concat ea eb)])
  [1 2 3 4 5])
; => [5 [1 2 3 4 5]]
```

**Frequency map** (accumulator is a dict, input is keywords):

```fol
(aggregate
  (fn [] {})
  (fn [m x] (update m x (fnil inc 0)))
  (fn [a b] (merge-with + a b))
  [:a :b :a :c :b :a])
; => {:a 3 :b 2 :c 1}
```

**Parallel string collection** (accumulator is a different type from input):

```fol
(aggregate
  (fn [] [])
  (fn [acc n] (conj acc (str n)))
  concat
  [1 2 3 4 5])
; => ["1" "2" "3" "4" "5"]  ; order depends on chunk boundaries
```

**Simple sum** (same as `preduce`, shown for comparison):

```fol
(aggregate 0 + + [1 2 3 4 5])   ; => 15
```

### Mutable accumulator safety

When `zero` is a function, each chunk receives its **own fresh accumulator** from `(funcall zero)`. This makes it safe to use mutable accumulators (hash-tables, adjustable arrays) within `seq-op` without locking, because no two chunks share a reference. The `combine-op` then merges the independent partials.

```fol
; Safe: each chunk builds its own hash-table
(aggregate
  (fn [] (make-hash-table))
  (fn [m x] (do (setf! (get m x) (inc (get m x 0))) m))
  merge-hash-tables
  large-collection)
```

---

## Summary

| Function | Use when |
|---|---|
| `preduce fn init coll` | Simple associative reduction, `fn` supports zero-arg identity |
| `fold combine-fn reduce-fn coll` | Reduction and combination are distinct operations, same type |
| `fold-recursive combine-fn reduce-fn coll` | Better work distribution on unevenly-sized chunks |
| `aggregate zero seq-op combine-op coll` | Accumulator type differs from element type, or zero must be fresh per chunk |

---

## Also see

- [parallel.md](parallel.md) — element-per-task parallel operations (`pmap`, `pfilter`, `pcount`, etc.)
- [core-async.md](core-async.md) — channel-based streaming parallelism (`pipeline`, `pipeline-async`)
