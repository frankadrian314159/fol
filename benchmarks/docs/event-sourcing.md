# Event Sourcing Benchmark Analysis

## Overview
This report analyzes the **Event Sourcing** benchmark, which demonstrates declarative aggregate updates with automatic event logging. It compares a **FOL** implementation (`benchmarks/fol-code/event-sourcing.fol`) using `:around` methods and persistent objects against a **Common Lisp** implementation (`benchmarks/lisp-code/event-sourcing.lisp`).

---

## 1. Performance Benchmark
The benchmark executed **100,000 command applications** (deposits and withdrawals). Each command triggers an `:around` method that persists the update and appends to an immutable event log.

| Metric | Common Lisp (Optimized) | FOL (Transpiled) | Ratio (FOL/CL) |
| :--- | :--- | :--- | :--- |
| **Real Time** | 0.097 seconds | 0.759 seconds | **~7.85x** |
| **Bytes Consed** | 20.69 MB | 170.88 MB | **~8.26x** |

### Performance Analysis
- **Metadata Management**: The FOL implementation relies on `persistent-class` and automatic structural sharing. Every command application involves creating multiple persistent maps (the command object, the event log entry, the vector update, and the account object).
- **Method Dispatch**: FOL's `:around` method combined with **Predicate Dispatch** for command routing adds a layer of runtime complexity compared to CL's standard CLOS dispatch and `defstruct`.
- **Structural Sharing**: While FOL is slower, it maintains a true persistent history. The CL version uses `push` into a list, which is faster but produces a reversed log that would require $O(N)$ reversal for correct-order replay.
- **Allocation Efficiency**: FOL conses ~8.3x more than CL, reflecting the per-command persistent-object and event-log updates that each involve one or more HAMT path copies.

---

## 2. LOC Analysis (Conciseness)
This analysis compares the source-level complexity of the implementations.

| Metric | FOL (`event-sourcing.fol`) | CL (`event-sourcing.lisp`) | Difference |
| :--- | :---: | :---: | :---: |
| **Total Lines** | 48 | 70 | -22 lines |
| **Blank Lines** | 8 | 11 | -3 lines |
| **Comments** | 12 | 14 | -2 lines |
| **SLOC (Logic)** | **28** | **45** | **-17 lines (-38%)** |

### Conciseness Analysis
- **Declarative Dispatch**: The use of Predicate Specializers in `apply-command` allows for inline command filtering (`(cmd (deposit?))`), which is significantly more compact than defining separate `defstruct` types and class-based methods in CL.
- **Protocol Integration**: FOL's native support for persistent updates (`assoc`, `conj`) and its `bind` macro for destructuring provide a high density of logic per line.
- **Aggregate Definition**: The `defclass` syntax in FOL is more concise for defining aggregates with default collection initializers.

---

## 3. Conclusion
The **38% reduction in Source Lines of Code (SLOC)** makes Event Sourcing one of the strongest use cases for FOL. By using Predicate Dispatch and persistent collections, developers can implement complex, audit-ready aggregates with minimal boilerplate. While there is a ~7.9x performance premium over native CL, the resulting code is easier to reason about and change.
