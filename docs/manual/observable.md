# Observable Benchmark Report

This report compares the performance of the **FOL** language (transpiled to Common Lisp) against a native **Common Lisp** implementation using the same underlying persistent data structures.

## Benchmark Overview

The benchmark simulates a sensor monitoring system where:
1.  A `<sensor>` object is updated thousands/millions of times.
2.  Each update produces a "change" event (a persistent map).
3.  Change events are processed by a generic function `on-change` using **predicate dispatch**.
4.  Specific patterns (spikes, critical states) trigger alerts, while others are logged as info.

### Implementations

-   **FOL**: Transpiled from `observable.fol`. Uses `on-change` with predicate specializers.
-   **Common Lisp**: Idiomatic CL in `observable.lisp`, using the same `fol.compiler.persistent` library and Sycamore hash-maps to ensure a fair comparison of language-level overhead vs. runtime system.

## Performance Results

Measurements were taken on SBCL with full GC before each run. Time is in seconds, and Memory is the net heap allocation in Megabytes.

| Iterations | Implementation | Time (s) | Memory (MB) |
| :--- | :--- | :--- | :--- |
| **1,000** | FOL (Transpiled) | 0.047 | 14.67 |
| | Common Lisp | 0.000 | 1.99 |
| **10,000** | FOL (Transpiled) | 0.031 | 23.30 |
| | Common Lisp | 0.047 | 12.28 |
| **100,000** | FOL (Transpiled) | 0.250 | 28.75 |
| | Common Lisp | 0.156 | 20.41 |
| **1,000,000** | FOL (Transpiled) | 2.250 | 40.66 |
| | Common Lisp | 1.375 | 48.74 |

## Analysis

### CPU Performance
Common Lisp consistently outperforms the transpiled FOL code by approximately **1.6x** at high iteration counts (1M iterations). This overhead in FOL is primarily due to:
-   **Dispatched Function Calls**: FOL's generic functions with predicate dispatch involve more complex runtime checks than standard CL generic functions or the `cond` dispatcher used in the manual CL version.
-   **Dynamic Bindings**: The transpiled code makes extensive use of `LET` and `PROGN` wrappings produced by the compiler's code generation patterns.

### Memory Usage
Interestingly, at 1,000,000 iterations, the Transpiled FOL code showed lower net allocation (**40.66 MB**) than the Common Lisp version (**48.74 MB**). This suggests that the FOL compiler's handling of persistent structures and local bindings might be slightly more aggressive in preventing unnecessary allocations, or that the manual CL version's use of `sycamore:hash-map-insert` in the `updated` helper was slightly more verbose in its intermediate map creation.

### Conclusion
The FOL language provides a high-level, declarative syntax (especially for predicate dispatch) that is significantly more concise than the equivalent Common Lisp. While there is a measurable performance penalty (~40-60% slower), the absolute performance remains well within acceptable bounds for many applications, processing 1 million updates and notifications in roughly 2 seconds.
