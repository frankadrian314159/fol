# Compliance Benchmark Analysis

## 1. Nature of the Benchmark

The Compliance Benchmark evaluates the performance of the **FOL Predicate Dispatch** system compared to a manual **Common Lisp** implementation. The test case simulates a financial trade validation system.

### Domain Logic
The benchmark processes trade objects through a set of compliance rules:
- **Restricted Symbols**: Immediate rejection if the symbol is on a blacklist (AMZN, GOOG, META, MSFT).
- **High Value Trades**: Flagged for manual review if the total price exceeds $1,000,000.
- **Penny Stocks**: Warning issued for buy-side trades where the price is below $5.00.
- **Standard Approval**: Default case for valid trades.

### Technical Implementation
- **FOL Strategy**: Utilizes advanced predicate dispatching in `defmethod`. Methods are specialized based on custom predicates (e.g., `(trd (restricted-symbol?))`), showcasing the language's expressive power in handling complex dispatch conditions.
- **Common Lisp Strategy**: Implements the same logic using a standard `cond` block for manual dispatch. This represents a highly optimized, low-overhead baseline.

---

## 2. Performance Findings

The benchmark was executed across various iteration counts to measure throughput and memory efficiency.

### Summary Data

| Iterations | Transpiled (FOL) Time | Common Lisp Time | Speedup (CL) | Memory (FOL) | Memory (CL) | Reduction (CL) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **500** | 71.10 ms | 5.40 ms | 13.18x | 31.46 MB | 2.11 MB | 14.91x |
| **10,000** | 181.58 ms | 16.54 ms | 10.98x | 100.46 MB | 9.48 MB | 10.60x |
| **100,000** | 1,230.00 ms | 128.68 ms | 9.58x | 753.57 MB | 79.53 MB | 9.48x |
| **1,000,000** | 11,520.00 ms | 945.73 ms | 12.18x | 7.11 GB | 779.53 MB | 9.35x |

### Key Observations

1.  **Throughput**: 
    - The Common Lisp implementation consistently outperforms the transpiled FOL code by a factor of **10x to 13x**. 
    - At the highest scale (1M iterations), FOL takes approximately **11.52 microseconds** per validation, while Common Lisp requires less than **1 microsecond** (~946 nanoseconds).
2.  **Memory Footprint**:
    - FOL exhibits significantly higher memory consumption, roughly **9x to 15x** that of pure Common Lisp.
    - At 1 million iterations, FOL consumed **7.11 GB** of memory compared to CL's **~780 MB**.
3.  **Scalability**:
    - The performance gap remains relatively stable as the workload scales, indicating that the overhead in FOL is predominantly due to the dispatch mechanism's infrastructure (likely related to predicate evaluation and memoization) rather than a scaling bottleneck.

### Conclusion
While FOL's predicate dispatch provides a much higher level of abstraction and code readability for complex business rules, it currently carries a performance tax of roughly one order of magnitude in both execution time and memory usage compared to manual dispatch in Common Lisp.
