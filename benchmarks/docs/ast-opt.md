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

### Results (from earlier run)

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
| **Build** | 0.516 ms / 0.16 MB | 60.062 ms / 23.95 MB | **116x** time, **153x** mem |
| **Optimizer (per pass)** | 0.357 ms / 0.125 MB | 72.103 ms / 17.911 MB | **202x** time, **144x** mem |
| Per-node (optimizer) | 35.7 ns | 7,211 ns | — |

GC cycles: CL 1 per 100-pass run; FOL 35 per 100-pass run.

### Analysis

The three primary drivers of overhead on the balanced tree are:

1. **Dispatch scan depth.** FOL's `defgeneric` performs an O(N) linear scan over 25 clauses. The balanced tree on average scans ≈12 clauses before finding the match for a uniformly distributed operator set, whereas the chain (below) always matches clause 1.

2. **Identity rule short-circuit rate.** Most internal nodes have subtrees (not literals) as direct children, so the identity rule rarely fires and nearly all 9,999 nodes are reconstructed each pass — each requiring a new HAMT path copy.

3. **Cache pressure.** The 9,999-node FOL tree consists of 9,999 HAMT-backed persistent objects scattered across heap. Each `get` slot read follows an indirection through the HAMT into cache-cold nodes. The 202× optimizer ratio also reflects GC pressure: 35 collection cycles vs. 1 for CL over the same 100-pass run.

### Practical interpretation

The balanced-tree ratio (**202×** optimizer, **116×** build) represents the worst-case profile for FOL: uniformly distributed operators, low identity-rule rate, and full HAMT path copies for nearly every node per pass.  Real code ASTs are dominated by a small number of operator types and have higher literal rates, which reduce the effective ratio.

For workloads where speculative rollback is valuable (rewrite-rule passes that may fail), the `O(1)` rollback benefit — discarding a modified root pointer — is available regardless of operator distribution.

---

## Build cost

FOL build cost (116×) exceeds optimizer cost per pass (202×/pass) on an absolute per-node basis only because build is one-time and passes are amortized over it. Building requires:
* One `make-<class>` call per node (~7 µs vs ~0.05 µs for `make-instance`)
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
