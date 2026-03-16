# AST Optimizer Benchmarks

**Platform:** SBCL 2.6.0, AMD Ryzen 9 5900X, Windows 11
**FOL persistent objects + predicate dispatch vs. CL defstruct + typecase**

---

## Setup

The benchmark defines **25 persistent node classes** (`<ast-node>` base, `<op-lit>`, `<op-var>`, 23 binary operator classes) and encodes **54 algebraic rewrite rules** in a single multi-clause `defmethod ast-optimize`. A second 25-clause `defmethod walk` drives recursive descent, rebuilding each binary node via `ast-optimize`.

Two tree shapes are measured to bound the performance envelope.

---

## Benchmark 1 — Linear Chain (29 nodes, N = 10,000 passes)

### Tree structure
`build-tree 14` produces a depth-14 linear chain: each `op-add` has `left = subtree` and `right = op-lit(0)`. Total: 14 `op-add` nodes + 15 `op-lit(0)` nodes = **29 nodes**.

### Why this shape is favorable to FOL
* Only `op-add` appears as an internal node → the `walk` dispatch always matches the **first** clause (`<op-add>`), minimizing scan depth.
* Every `op-add` has `right = op-lit(0)` → the identity rule `(x + 0 → x)` fires on **every** node, returning the existing left subtree without allocating a new `op-add`. This greatly reduces per-pass allocation.

### Results

| Implementation | Time | Alloc | vs. CL |
|---|---|---|---|
| CL (`defstruct` + `typecase`) | 5 ms | 4.2 MB | 1.0× |
| FOL (persistent + predicate dispatch) | 92 ms | 30.2 MB | **19.2×** |

* **19.2× time overhead**, **7.2× memory overhead**.
* Per-node: CL ≈ 17 ns/node, FOL ≈ 317 ns/node.
* Cost breakdown: ~1.6× from dispatch routing (upper bound; mixed-level patterns short-circuit); ~12× from persistent field access (`get` ≈ 50 ns vs struct slot ≈ 4 ns).

---

## Benchmark 2 — Balanced Binary Tree (9,999 nodes, N = 100 passes)

### Tree structure
`build-balanced 9999 1` produces a near-perfect balanced binary tree of depth ≈ 13. The operator type is determined by `(mod idx 23)` cycling through all 23 binary operator types, and leaves cycle through `op-lit(0)`, `op-lit(1)`, and `op-var(:x)`. Total: **4,999 internal binary nodes × all 23 operator types + 5,000 leaf nodes**.

### Why this shape is more representative
* All 23 operator types appear uniformly → the `walk` `defgeneric` scan exercises all 25 dispatch clauses proportionally. For later operator types (e.g., `op-map`, matched at clause 24), the linear scan is fully exposed.
* Leaves are 1/3 each: `op-lit(0)`, `op-lit(1)`, `op-var(:x)`. Only nodes whose direct child is a literal trigger identity rules; with depth-13 subtrees as children of most internal nodes, the **identity rule firing rate is low**, so nearly all 9,999 nodes are re-allocated each pass.
* 9,999 HAMT-backed persistent objects spread across heap → increased cache pressure vs. 29-node chain.

### Results

| Phase | CL | FOL | Ratio |
|---|---|---|---|
| **Build** | 0.67 ms / 0.16 MB | 51.9 ms / 12.7 MB | **77×** time, **81×** mem |
| **Optimizer (per pass)** | 0.527 ms / 0.125 MB | 24.76 ms / 1.749 MB | **47×** time, **14×** mem |
| Per-node (optimizer) | 52.7 ns | 2,476 ns | — |

GC cycles: CL 1 per 100-pass run; FOL 4 per 100-pass run.

### Analysis

The balanced-tree ratio (**47×**) is substantially higher than the chain ratio (**19.2×**) for three compounding reasons:

1. **Dispatch scan depth.** FOL's `defgeneric` performs an O(N) linear scan over 25 clauses. The chain always matches clause 1 (`<op-add>`); the balanced tree on average scans ≈12 clauses before finding the match for a uniformly distributed operator set. This alone accounts for a ~6× per-dispatch increase.

2. **Identity rule short-circuit rate.** In the chain every `op-add` has `right = op-lit(0)`, triggering the identity rule and returning the existing left subtree without allocating a new node. In the balanced tree, most internal nodes have subtrees (not literals) as direct children, so the identity rule rarely fires and nearly all 9,999 nodes are reconstructed each pass.

3. **Cache pressure.** The 9,999-node FOL tree consists of 9,999 HAMT-backed persistent objects scattered across heap. Each `get` slot read follows an indirection through the HAMT into cache-cold nodes. The 29-node chain fits largely in L2 cache.

### Practical interpretation

The two tree shapes bound the realistic overhead:

| AST profile | Approx. ratio |
|---|---|
| Single dominant operator type (e.g., purely `op-add`) | ≈ 19× |
| Uniformly distributed 23-operator tree | ≈ 47× |
| Typical mixed code AST | between these bounds |

For workloads where speculative rollback is valuable (rewrite-rule passes that may fail), the `O(1)` rollback benefit — discarding a modified root pointer — is available regardless of operator distribution.

---

## Build cost

FOL build cost (77×) is higher than optimizer cost (47×). Building requires:
* One `make-<class>` call per node (≈183 ns vs ≈37 ns for mutable `make-instance`)
* HAMT construction for each persistent object's slot map

Build is a one-time cost in practice; optimizer passes are amortized over it.

---

## Hardware / environment

| | |
|---|---|
| CPU | AMD Ryzen 9 5900X |
| OS | Windows 11 Pro |
| SBCL | 2.6.0 (x86-64) |
| Heap | default |
