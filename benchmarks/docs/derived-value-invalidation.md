# Derived-Value Invalidation Benchmark

This report measures the cost of FOL's `:around assoc` automatic cache-invalidation
pattern versus manually coding the same invalidation in each Common Lisp update
function.

## 1. Pattern Description

### Problem

A persistent object (`<cart>`) caches a derived value (`:_total`) that must be
cleared whenever its upstream dependency (`:items`) changes.  In plain CL, every
function that modifies `:items` must explicitly set `:_total` to `nil`:

```lisp
(defun add-item (cart price)
  (%make-cart :items (cons price (cart-items cart))
              :_total nil))   ; <-- must not forget this
```

Forgetting the invalidation in any one mutation function produces a permanently
stale cache.

### FOL Solution

A single predicate-specialized `:around` method on `assoc` handles invalidation
automatically.  It fires only when the modified slot is `:items`, leaving all
other updates unaffected:

```lisp
(defmethod assoc :around [(cart <cart>) (slot (= :items)) val]
  (assoc (call-next-method) :_total nil))
```

The lazy accessor recomputes on demand and the caller stores the result back to
warm the cache:

```lisp
(defn cart-total [cart]
  (if (nil? (:_total cart))
    (reduce + 0 (:items cart))   ; cache miss: recompute
    (:_total cart)))             ; cache hit: return immediately
```

## 2. Benchmark Setup

- **Workload**: 1,000 independent add-item rounds, each followed by 1,000
  cart-total reads (1,000,000 total read operations).
  - After each `add-item`, one `cart-total` recompute is forced (cache miss),
    the result is stored back, then 999 additional reads hit the warm cache.
- **CL Implementation**: `dvi-cl::add-item` manually sets `_total = nil`;
  same lazy `cart-total` accessor.
- **FOL Implementation**: `derived-value-invalidation::add-item` triggers the
  `:around` method; `cart-total` uses `if (null cached)`.
- **Environment**: SBCL 2.6.0, Windows 11, AMD Ryzen 9 5900X, 64 GB RAM.

## 3. Performance Results

| Implementation | Time (1K adds + 1M reads) | Avg Time/write | Bytes Consed | Ratio |
| :--- | ---: | ---: | ---: | ---: |
| **Common Lisp** (manual invalidation) | 0.013 s | 12.7 µs | 0.09 MB | 1.0× |
| **FOL** (`:around assoc`) | 0.330 s | 330 µs | 85.54 MB | 26.0× |

**Correctness**: both return 166,666,500,000 (sum of all cached totals).

## 4. Analysis

### Time Overhead (26×)

Each `add-item` call in FOL performs three `assoc` operations instead of one:

1. `(assoc cart :items new-items)` — base update, triggers `:around`
2. `(assoc result :_total nil)` — automatic invalidation inside `:around`
3. `(assoc c1 :_total t1)` — caller stores back the computed total

Each `assoc` on a persistent object incurs CLOS generic dispatch + HAMT
path copy.  The CL equivalent performs one struct allocation per write.

The 1,000 cache-miss recomputes (one per `add-item`) have comparable cost in
both implementations: `fol.core:reduce` over a small persistent vector vs
`cl:reduce` over a CL cons list.  The dominant overhead is the extra `assoc`
calls.

### Memory Overhead (913×)

FOL allocates ~85.5 MB vs ~0.09 MB for CL.  Each of the three `assoc` calls per
round allocates a new persistent object (HAMT path copy) plus a new
persistent vector node for the growing `:items` trie.  The CL version uses
structs (one allocation per add) and cons cells (one per item).

The high ratio (913×) reflects both the HAMT path-copy overhead and the
structural sharing nodes for the growing persistent vector.  Both are expected
and are the price of full value semantics with structural sharing.

### Cache-Hit Reads

Both implementations access the same `:_total` field (a HAMT lookup in
FOL, a struct slot read in CL) on each of the 999 warm-cache reads per round.
The reads are dominated by the HAMT traversal in FOL vs direct slot access in CL,
but this contribution is negligible relative to write overhead at this workload
ratio (1:1000 writes to reads).

### Engineering Trade-off

| Dimension | CL (manual) | FOL (`:around assoc`) |
| :--- | :--- | :--- |
| Invalidation site | Every mutating function | Single `:around` declaration |
| Omission risk | Silent stale-cache bug | Structurally impossible |
| Write overhead | ~12.7 µs (1 struct alloc) | ~330 µs (3 assoc calls) |
| Read overhead (warm) | Direct slot read | HAMT traversal (~same) |
| Memory per write | ~90 B/op | ~85.5 KB/op (persistent nodes) |

The pattern is most appropriate when:
- Many code paths can modify the upstream dependency
- Correctness (no stale cache) matters more than write throughput
- Reads significantly outnumber writes (the cache benefit amortizes the write cost)

## 5. Running the Benchmark

```
sbcl --noinform --non-interactive --load benchmarks/run-derived-value-invalidation-bench.lisp
```

## 6. Source Files

| File | Description |
| :--- | :--- |
| `benchmarks/fol-code/derived-value-invalidation.fol` | FOL source |
| `benchmarks/transpiled-fol-code/derived-value-invalidation.lisp` | Transpiled output |
| `benchmarks/lisp-code/derived-value-invalidation.lisp` | Native CL equivalent |
| `benchmarks/run-derived-value-invalidation-bench.lisp` | Runner script |
