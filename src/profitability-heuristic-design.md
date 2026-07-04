# Design: Profitability Heuristic for Transient Conversion

**Status**: Proposed  
**Owner**: Anonymous  
**Depends On**: Transient Conversion (v0.1.1)

## 1. Motivation

The automatic transient conversion optimization provides significant speedups for large accumulation loops. However, as noted in Section 8 of the PLDI 2027 paper and confirmed by benchmarks, there is a constant-factor overhead associated with creating and managing transient collections.

For loops that operate on very small collections or perform few iterations (small-N loops), this overhead can exceed the performance gains from avoiding allocations. This can lead to a performance *regression*, where the "optimized" code is slower than the original.

The goal of the profitability heuristic is to prevent these regressions by ensuring the transient fast-path is only taken when it is likely to be profitable.

## 2. Core Design

The solution is to augment the existing dual-path emission with a **runtime profitability check**. Instead of just checking the world-guard validity cell, the compiler will emit a guard that also checks the size of the accumulator collection.

### 2.1. Modified Guard Condition

The current guard is:
```lisp
(if (is-valid? *region-cell*)
    <optimized-transient-path>
    <original-persistent-path>)
```

The new guard will be:
```lisp
(if (and (is-valid? *region-cell*)
         (> (count accumulator) <threshold>))
    <optimized-transient-path>
    <original-persistent-path>)
```

Where:
- `accumulator` is the name of the loop variable being converted.
- `<threshold>` is a pre-determined integer constant.

This check is cheap (a single `count` call and a comparison) and is performed only once upon entering the loop.

### 2.2. Determining the Threshold

The value of `<threshold>` is critical. It must be chosen such that for any collection size greater than the threshold, the transient path is faster.

This value will be determined empirically by running a new suite of micro-benchmarks (`benchmarks/run-profitability-benchmarks.lisp`). These benchmarks will measure the performance of a fixed number of updates on collections of varying initial sizes for both the baseline and optimized paths.

The crossover point where the optimized path becomes faster will determine the threshold.

**Key Considerations**:
- The threshold may differ for different collection types (e.g., `dict` vs. `vector`) due to their different internal structures and update costs.
- The threshold will be a hardcoded constant in the compiler, derived from these benchmark results.

### 2.3. Implementation Plan

1.  **[benchmarks]** Create the profitability micro-benchmarks for dicts and vectors.
2.  **[benchmarks]** Run the benchmarks to determine the crossover points for `dict` and `vector` accumulators.
3.  **[src/escape-analysis.lisp]** Modify `maybe-transient-loop` to:
    - Identify the type of the qualified accumulator (dict, vector, etc.).
    - Return a third value: a `profitability-check` form, e.g., `(> (count acc) 16)`. This form will be `nil` if no check is needed or if the type is unsupported.
4.  **[src/compiler.lisp]** Modify `emit-loop` to:
    - Receive the new `profitability-check` form from `maybe-transient-loop`.
    - If the check is present, `AND` it with the existing world-guard check in the emitted `if` statement.
5.  **[src/tests]** Add new tests to verify that the profitability check is correctly emitted for qualifying loops.

## 3. Benefits

- **Improved Robustness**: The optimization will no longer cause performance regressions on small-N loops.
- **"Do No Harm" Principle**: Makes the optimization safer to enable by default, as it will automatically avoid cases where it is not beneficial.
- **Honest Cost Model**: The implementation directly reflects the cost model discussed in the paper, where transients have a fixed overhead.

## 4. Drawbacks

- **Slight Overhead**: Adds a `count` call and a comparison to the entry of every potentially convertible loop. This cost is negligible compared to the loop's execution time.
- **Heuristic Nature**: The threshold is based on micro-benchmarks run on a specific machine. While generally applicable, performance characteristics on different hardware or with different underlying Lisp implementations might vary slightly. The chosen threshold should be conservative enough to be safe across most platforms.

By implementing this heuristic, we make the transient conversion optimization smarter and more reliable, ensuring it consistently delivers performance improvements without unintended side effects.

---