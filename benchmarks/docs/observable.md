# Observable Benchmark Analysis

## Overview
This report analyzes the **Observable** benchmark which implements a sensor monitoring system with change notifications. It compares a **FOL** implementation (`benchmarks/fol-code/observable.fol`) using persistent objects and predicate dispatch against a **Common Lisp** implementation (`benchmarks/lisp-code/observable.lisp`) using standard CLOS and manual dispatch.

---

## 1. Performance Benchmark
The benchmark executed **1,000,000 iterations** of a sensor update loop. Each iteration involves updating a sensor reading, calculating a change event, and routing that event through a notification system.

| Metric | Common Lisp (Optimized) | FOL (Transpiled) | Ratio (FOL/CL) |
| :--- | :--- | :--- | :--- |
| **Real Time** | 0.441 seconds | 2.595 seconds | **~5.88x** |
| **Processor Cycles** | 1.01 billion | 5.96 billion | **~5.90x** |
| **Bytes Consed** | 391.02 MB | 2,376.15 MB | **~6.08x** |
| **CPU Utilization** | 99.32% | 99.96% | - |

### Performance Analysis
- **Structural Sharing vs. Mutation**: The FOL implementation uses persistent data structures (FSet-based) for both the sensor objects and the event records. The CL version uses mutable CLOS objects and structs, which are significantly faster for simple field updates.
- **Allocation Pressure**: FOL conses ~6x more than CL. This is expected as every "update" in FOL produces multiple new immutable maps (the change event, the result wrapper, and the new sensor state), whereas CL performs a shallow copy and in-place field mutation.
- **Dispatch Overhead**: FOL's `on-change` uses **Predicate Dispatch**, which involves running arbitrary logic (like `spike?` and `critical?`) during method selection. The CL version uses a hard-coded `cond` block.

---

## 2. LOC Analysis (Conciseness)
This analysis compares the source-level complexity of the implementations.

| Metric | FOL (`observable.fol`) | CL (`observable.lisp`) | Difference |
| :--- | :---: | :---: | :---: |
| **Total Lines** | 57 | 87 | -30 lines |
| **Blank Lines** | 8 | 14 | -6 lines |
| **Comments** | 4 | 21 | -17 lines |
| **SLOC (Logic)** | **45** | **52** | **-7 lines (-13%)** |

### Conciseness Analysis
- **Protocol Automation**: In FOL, the `update` protocol is more naturally expressed with functional `assoc` and `bind`, leading to a slightly more compact `updated` function.
- **Pattern Matching/Dispatch**: Predicate dispatch in FOL allows for cleaner separation of concerns in notification routing, although in this specific small-scale benchmark, the SLOC difference is modest (13%).
- **Boilerplate**: FOL's `defclass` and `defn` syntax reduces the noise of initargs and manual field copying required in the CL CLOS implementation.

---

## 3. Conclusion
The Observable benchmark highlights the cost of **Full Immutability**. While FOL is roughly 6x slower than native CL/CLOS in this specific update-heavy workload, it provides **structural integrity** and **time-travel debugging** capabilities by default. For monitoring systems where audit trails and event sourcing are required, the performance trade-off is often acceptable in exchange for the safety of persistent state.
