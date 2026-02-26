# Compliance Benchmark Analysis
## Overview
This report compares the **FOL** implementation (`benchmarks/fol-code/compliance.fol`) against a baseline **Common Lisp** implementation (`benchmarks/lisp-code/compliance.lisp`). The benchmark demonstrates the expressive power of FOL's predicate dispatch system and evaluates the performance cost of its high-level abstractions.

---

## 1. Performance Benchmark
The performance test executed **1,000,000 validation checks** on a randomized set of 1,000 pre-allocated trades (250 runs of 4,000 checks each).

| Metric | Common Lisp (Optimized) | FOL (Transpiled) | Ratio (FOL/CL) |
| :--- | :--- | :--- | :--- |
| **Real Time** | 0.173 seconds | 1.201 seconds | **~6.94x** |
| **Bytes Consed** | 134.15 MB | 1,358.70 MB | **~10.13x** |

### Performance Analysis
- **Execution Overhead**: The ~6.94x slowdown reflects the use of persistent data structures (HAMT-based dicts for validation results, persistent objects for trade instances). Each validation produces an immutable map result via HAMT allocation.
- **Memory Allocation**: The 10x memory overhead is due to FOL's immutable persistent objects and HAMT-based collection construction for each validation result.
- **Dispatch Efficiency**: Despite the overhead, validating 1,000,000 trades in ~1.2 seconds shows that the system is suitable for complex business logic processing.

---

## 2. LOC Analysis (Conciseness)

| Category | FOL | CL | Savings |
| :--- | :---: | :---: | :---: |
| Class definition | 5 | 8 | 38% |
| Predicates / logic | 12 | 13 | 8% |
| Dispatch / validation | 9 | 15 | 40% |
| Module boilerplate | 2 | 11 | 82% |
| Test harness | 23 | 22 | -5% |
| **Total SLOC** | **51** | **69** | **26%** |

### Conciseness Analysis
The FOL implementation is **26% more concise** in terms of functional logic (SLOC). Key drivers include:
- **Module boilerplate (82% reduction)**: FOL's `in-package` with inline exports replaces CL's separate `defpackage` with `(:use)`, `(:export)`, and `in-package` forms.
- **Dispatch / validation (40% reduction)**: FOL's map literals (`{:status :rejected ...}`) replace CL's `(list :status :rejected ...)` forms, and `cond` with keyword `:else` replaces `t`.
- **Class definition (38% reduction)**: FOL's `defclass` combines class definition with implicit constructor; CL requires a separate `make-trade` wrapper around `make-instance`.
- **Predicates (8% reduction)**: Nearly identical logic; FOL uses `contains?` with set literals while CL uses `member` with a `defparameter` list.
- **Test harness (-5%)**: FOL test code is slightly longer due to `bind` syntax vs CL's `let`/`defparameter`.

---

## 3. Conclusion
The FOL implementation represents a standard trade-off in modern language design: **Developer Productivity vs. Absolute Performance**.

By accepting a **~7x performance penalty**, the developer gains a **26% more maintainable codebase** with built-in immutability and a powerful dispatch system that is natively resilient to complex business rule changes.
