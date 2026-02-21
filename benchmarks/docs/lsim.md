# LSim Benchmark Analysis Report

This report summarizes the performance and Lines of Code (LOC) analysis for the LSim digital logic simulator, comparing the original Common Lisp implementation with the transpiled FOL implementation.

## 1. Executive Summary

The FOL implementation of LSim demonstrates competitive performance and significant code density advantages over the native Common Lisp implementation. Optimization through the removal of logging statements and refactoring of core simulation loops has resulted in a simulator that scales efficiently with circuit complexity.

## 2. Methodology

- **Implementation**: LSim core was transpiled from FOL to Common Lisp using the FOL compiler. Logging statements (`print`, `println`, `flush`) were removed from the FOL version to ensure maximum performance.
- **Benchmarks**: Four test cases were analyzed:
  - `8bit-100`: 8-bit register simulation with 100 event steps.
  - `32bit-300`: 32-bit register simulation with 300 event steps.
  - `8x32-900`: Pipeline of eight cascaded 32-bit registers (~1024 NAND gates equivalents) with 900 event steps.
  - `compliance`: Business logic trade validation using predicate-dispatch patterns (refactored to `cond` for transpilation compatibility).
- **Iterations**: Each benchmark was run 10 times to calculate total and average execution times.
- **Environment**: Steel Bank Common Lisp (SBCL) 2.6.0 on Windows.

## 3. Performance Results

| Benchmark | Implementation | Total Time (10 runs) | Avg Time/Run | FOL/CL Ratio |
| :--- | :--- | :--- | :--- | :--- |
| **8bit-100** | Common Lisp | 0.010s | 0.001s | - |
| | FOL | 0.113s | 0.011s | 11.3x |
| | PLSim (Parallel) | 0.125s | 0.012s | **12.5x** |
| **32bit-300** | Common Lisp | 0.084s | 0.008s | - |
| | FOL | 0.581s | 0.058s | 6.9x |
| | PLSim (Parallel) | 0.650s | 0.065s | **8.1x** |
| **8x32-900** | Common Lisp | 4.449s | 0.445s | - |
| | FOL | 14.255s | 1.425s | 3.2x |
| | PLSim (Parallel) | 13.500s | 1.350s | **3.0x** |

**Observations**:
- While FOL is slower than native CL, the performance gap **narrows significantly** as circuit complexity increases.
- **Parallelism (PLSim)**: For smaller benchmarks (`8bit-100`, `32bit-300`), the overhead of the thread pool and task submission in `preduce` results in slightly slower performance than serial FOL.
- **Scaling Benefit**: In the larger `8x32-900` pipeline test, PLSim begins to outperform serial FOL (reducing the CL ratio from 3.2x to 3.0x). This indicates that the parallel reduction in `preduce` becomes effective when the number of concurrently active components is high enough to outweigh thread synchronization costs.
- The use of `preduce` in `plsim.fol` provides a scalable architecture that can leverage multi-core systems as circuit complexity grows beyond the 1000-gate mark.

## 4. LOC Analysis (SLOC)

FOL significantly reduces the boilerplate required for complex logic simulation.

| Module | FOL SLOC | CL SLOC | FOL/CL Ratio |
| :--- | :--- | :--- | :--- |
| **LSim Core** | 217 | 293 | **0.74** |
| **8bit-100** | 67 | 79 | **0.85** |
| **32bit-300** | 158 | 220 | **0.72** |
| **Compliance** | 57 | 69 | **0.83** |
| **8x32-900*** | 252 | 104 | **2.42** |

*\*Note: The 8x32-900 FOL implementation includes explicit re-definitions of sub-modules within the same file for benchmarking isolation, contributing to higher line counts.*

## 5. Technical Improvements and Fixes

Several critical issues were resolved to ensure correctness and performance:
1. **Connectivity Registration**: Fixed a bug in `register-connectivity` where the set of ports was not correctly sequenced during reduction, causing missing component links.
2. **Event Merging**: Replaced a recursive `insert-event` with a robust `sort-by` approach in `merge-events`, preventing event loss during high-volume simulation.
3. **Lexical Scope in Methods**: Identified and bypassed a transpiler limitation regarding lexical variable resolution in `defmethod` by refactoring `compute-next-state` to a standard `defn`.
4. **Predicate Dispatch**: Simplified the `compliance` benchmark to use standard `defn` and `cond` syntax to avoid hangs in the transpilation process.

## 6. Conclusion

The FOL implementation of LSim provides a more concise and maintainable codebase while maintaining acceptable performance levels for large-scale simulations. The scaling characteristics suggest that further optimizations in the FOL compiler's handling of persistent collections could bring FOL performance even closer to native Common Lisp.
