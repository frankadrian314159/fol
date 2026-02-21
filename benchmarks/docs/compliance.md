# Compliance Benchmark Analysis
## Overview
This report compares the **FOL** implementation (`benchmarks/fol-code/compliance.fol`) against a baseline **Common Lisp** implementation (`benchmarks/lisp-code/compliance.lisp`). The benchmark demonstrates the expressive power of FOL's predicate dispatch system and evaluates the performance cost of its high-level abstractions.

---

## 1. Performance Benchmark
The performance test executed **1,000,000 validation checks** on a randomized set of 1,000 pre-allocated trades.

| Metric | Common Lisp (Optimized) | FOL (Transpiled) | Ratio (FOL/CL) |
| :--- | :--- | :--- | :--- |
| **Real Time** | 0.624 seconds | 1.349 seconds | **~2.16x** |
| **Processor Cycles** | 1.43 billion | 3.10 billion | **~2.16x** |
| **Bytes Consed** | 112.80 MB | 1,163.75 MB | **~10.32x** |
| **CPU Utilization** | 100.16% | 98.44% | - |

### Performance Analysis
- **Execution Overhead**: The ~2.16x slowdown is primarily attributed to Lisp-1 compatibility checks (standard in FOL transpilation) and the pervasive use of persistent data structures.
- **Memory Allocation**: The higher memory consing (10x) is due to FOL's immutable persistent objects and collection-based helpers (`MAKE '<LIST>`, `STR`, `GET`) which involve more allocations than native Lisp lists and slot access.
- **Dispatch Efficiency**: Despite using arbitrary boolean predicates for dispatch, the generated `cond`-based branching remains highly efficient at scale.

---

## 2. LOC Analysis (Conciseness)
This analysis compares the source-level complexity and maintenance burden of both implementations.

| Metric | FOL (`compliance.fol`) | CL (`compliance.lisp`) | Difference |
| :--- | :---: | :---: | :---: |
| **Total Lines** | 93 | 107 | -14 lines |
| **Blank Lines** | 18 | 25 | -7 lines |
| **Comments** | 25 | 22 | +3 lines |
| **SLOC (Logic)** | **50** | **60** | **-10 lines (-17%)** |

### Conciseness Analysis
The FOL implementation is **17% more concise** in terms of functional logic (SLOC). Key drivers include:
- **Predicate Specializers**: FOL integrates business logic directly into the method signature, removing the need for manual `cond` routing blocks.
- **Collection Literals**: Expressive syntax for maps and sets (`#{...}`, `[...]`) reduces boilerplate.
- **Immutable Persistence**: Automatic integration of persistence and immutability reduces the code needed for defensive copying or state management.

---

## 3. Conclusion
The FOL implementation represents a standard trade-off in modern language design: **Developer Productivity vs. Absolute Performance**. 

By accepting a **2x performance penalty**, the developer gains a **17% more maintainable codebase** with built-in immutability and a powerful dispatch system that is natively resilient to complex business rule changes.
