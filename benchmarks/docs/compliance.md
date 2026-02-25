# Compliance Benchmark Analysis
## Overview
This report compares the **FOL** implementation (`benchmarks/fol-code/compliance.fol`) against a baseline **Common Lisp** implementation (`benchmarks/lisp-code/compliance.lisp`). The benchmark demonstrates the expressive power of FOL's predicate dispatch system and evaluates the performance cost of its high-level abstractions.

---

## 1. Performance Benchmark
The performance test executed **1,000,000 validation checks** on a randomized set of 1,000 pre-allocated trades (250 runs of 4,000 checks each).

| Metric | Common Lisp (Optimized) | FOL (Transpiled) | Ratio (FOL/CL) |
| :--- | :--- | :--- | :--- |
| **Real Time** | 0.438 seconds | 2.989 seconds | **~6.82x** |
| **Bytes Consed** | 134.11 MB | 1,358.58 MB | **~10.13x** |

### Performance Analysis
- **Execution Overhead**: The ~6.82x slowdown reflects the use of persistent data structures (HAMT-based dicts, Sycamore hash-maps for persistent objects). This is an improvement over the previous 8.45x ratio, attributable to the migration from FSet/Sycamore collections to hand-coded HAMTs for dict operations.
- **Memory Allocation**: The 10x memory overhead (down from 14.45x) is due to FOL's immutable persistent objects and collection-based helpers, though the hand-coded HAMT reduces per-operation allocation compared to the previous FSet-based implementation.
- **Dispatch Efficiency**: Despite the overhead, validating 1,000,000 trades in ~3.0 seconds shows that the system is suitable for complex business logic processing.

---

## 2. LOC Analysis (Conciseness)
This analysis compares the source-level complexity and maintenance burden of both implementations.

| Metric | FOL (`compliance.fol`) | CL (`compliance.lisp`) | Difference |
| :--- | :---: | :---: | :---: |
| **Total Lines** | 81 | 116 | -35 lines |
| **Blank Lines** | 14 | 25 | -11 lines |
| **Comments** | 10 | 22 | -12 lines |
| **SLOC (Logic)** | **57** | **69** | **-12 lines (-17%)** |

### Conciseness Analysis
The FOL implementation is **17% more concise** in terms of functional logic (SLOC). Key drivers include:
- **Predicate Specializers**: FOL integrates business logic directly into the method signature, removing the need for manual `cond` routing blocks.
- **Collection Literals**: Expressive syntax for maps and sets (`#{...}`, `[...]`) reduces boilerplate.
- **Immutable Persistence**: Automatic integration of persistence and immutability reduces the code needed for defensive copying or state management.

---

## 3. Conclusion
The FOL implementation represents a standard trade-off in modern language design: **Developer Productivity vs. Absolute Performance**.

By accepting a **~7x performance penalty**, the developer gains a **17% more maintainable codebase** with built-in immutability and a powerful dispatch system that is natively resilient to complex business rule changes.
