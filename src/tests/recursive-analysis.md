# Recursive Analysis Performance Benchmarks

These benchmarks measure the performance impact of the Tier-2 fixed-point summary inference engine, which enables transient conversion for recursive and mutually recursive functions.

## Benchmarks

### 1. `recursive-accumulator-bench.fol`

**Purpose**: To validate that the fixed-point analysis correctly identifies a linear accumulator in a standard tail-recursive function.

**Workload**:
- A function `build-vec-recursively` constructs a vector of 100,000 elements using a tail-recursive helper.
- The `acc` parameter is passed linearly through `(conj acc i)` in each recursive step.

**Expected Result**:
- **Without optimization**: Each `conj` call allocates a new persistent vector, leading to high allocation and GC pressure.
- **With optimization**: The analysis should infer that `acc` is used linearly. The compiler will convert the loop to use `(transient [])` and `conj!`, resulting in a significant speedup.

### 2. `mutual-recursion-bench.fol`

**Purpose**: To validate that the fixed-point analysis can handle cycles between functions (mutual recursion).

**Workload**:
- Two functions, `process-a` and `process-b`, call each other.
- `process-a` accumulates items into `acc-a`.
- `process-b` accumulates items into `acc-b`.
- The benchmark processes a list of 100,000 items, splitting them between the two accumulators.

**Expected Result**:
- **Without optimization**: Both `conj` calls will perform persistent allocations.
- **With optimization**: The analysis must iterate to a fixed point to determine that both `acc-a` and `acc-b` are used linearly within their respective scopes. This should enable transient conversion for both accumulators, leading to a large performance improvement.

## How to Run

The benchmarks can be run using the provided runner script. This script will execute each benchmark with and without the transient optimization enabled and print a summary table.

```bash
# From the project root directory
sbcl --noinform --non-interactive --load benchmarks/run-recursive-benchmarks.lisp
```

## Expected Performance

The performance improvement for these benchmarks should be comparable to the `loop/recur` micro-benchmarks (e.g., `vector loop, 1M conjs`), as the underlying optimization is the same. We expect to see speedups in the range of **5-8×**.

Any significant deviation from this would indicate either a flaw in the recursive analysis (if speedup is low) or an unexpected interaction with the compiler's tail-call optimization (if speedup is unusually high).

## Validation

These benchmarks serve as the primary validation for the following claims:

1.  The `infer-summary` fixed-point analysis is correct and can handle simple tail recursion.
2.  The analysis can correctly resolve cycles (mutual recursion) and still produce precise summaries.
3.  The performance gains from optimizing recursive functions are substantial and on par with optimizing iterative `loop/recur` forms.

This provides strong evidence for the effectiveness and robustness of the Tier-2 interprocedural analysis system.