# LispWorks Benchmark Guide

## Overview

LispWorks Personal Edition is a GUI-based IDE and does not support batch/non-interactive mode. This guide explains how to run the dispatch caching benchmarks interactively in the LispWorks IDE.

## Files

Three benchmark files have been created for interactive evaluation in LispWorks:

1. **hetero-micro-bench-lispworks.lisp** — Heterogeneous 5-type dispatch cycle
2. **simple-micro-bench-lispworks.lisp** — Homogeneous fixnum-only dispatch
3. **method-dispatch-bench-lispworks.lisp** — CLOS generic function dispatch

## How to Run

### Step 1: Open the Benchmark File

1. Launch LispWorks Personal Edition
2. Choose **File → Open** from the menu
3. Navigate to the benchmark file you want to run
4. Click **Open**

The file will open in the editor window.

### Step 2: Load the Code

1. Select all code: **Ctrl+A**
2. Evaluate the buffer: **Ctrl+E**
   - Or: **Editor → Evaluate Buffer**

This will load all the benchmark functions into LispWorks' Lisp image.

### Step 3: Run the Benchmark

In the **REPL window** (Listener), type:

```lisp
(RUN-ALL-BENCHMARKS)
```

Then press **Enter**.

The benchmark will run and print detailed output to the Listener window.

### Step 4: Record Results

Copy the output from the Listener window and paste it into a text editor or directly into the results document.

## What to Expect

### Heterogeneous Benchmark Output

```
================================
LispWorks Heterogeneous Dispatch Caching Micro-Benchmark
================================
Implementation: LispWorks 8.1.2
Test data: 200,000 calls over repeating 5-type cycle
  Type cycle: fixnum -> string -> list -> vector -> symbol

Warming up JIT compiler (10,000 calls)...
Warmup complete.

=== Uncached COND Dispatch (3 iterations) ===
  Run 1: X.XXX seconds
  Run 2: X.XXX seconds
  Run 3: X.XXX seconds
Uncached Dispatch Results:
  Iterations: 3
  Total calls per iteration: 200000

=== Cached Dispatch (3 iterations) ===
  Run 1: X.XXX seconds
  Run 2: X.XXX seconds
  Run 3: X.XXX seconds
Cached Dispatch Results:
  Iterations: 3
  Total calls per iteration: 200000
  Cache hits: 200000
  Cache misses: 0
  Hit rate: 100.0000%

================================
Benchmark Complete
================================
```

## Timing Notes

- LispWorks uses `get-internal-run-time` for measurement, which returns CPU time in internal time units
- The time is converted to seconds by dividing by `internal-time-units-per-second`
- Multiple iterations help account for JIT compilation overhead
- First run is typically slower due to JIT warmup

## Comparison with Other Implementations

Results should be comparable to:
- **SBCL 2.6.0** — ~6 ms uncached, ~32 ms cached (heterogeneous)
- **CCL 1.13** — ~72 s uncached, ~70.5 s cached (heterogeneous)
- **ABCL 1.9.2** — ~30 s uncached, ~30.3 s cached (heterogeneous)

LispWorks Professional Edition results (if available) should provide additional data on how LispWorks' compilation strategy compares.

## Troubleshooting

### Code doesn't evaluate
- Make sure all code is selected before pressing Ctrl+E
- Check for syntax errors in the error/debug window

### Function not found when running (RUN-ALL-BENCHMARKS)
- Ensure the code was successfully evaluated (check for error messages)
- The REPL window must be active when you type the function call

### Unexpected performance (very fast or very slow)
- JIT compilation may not be engaged yet; warmup phase should help
- System load may affect timings; close other applications if possible
- Run multiple iterations to account for variance

## Next Steps

After recording results from all three benchmarks:

1. Note the times for uncached and cached versions
2. Calculate the ratio (cached / uncached)
3. Add results to LISPWORKS-BENCHMARK-RESULTS.md
4. Compare with SBCL, CCL, and ABCL results

---

**LispWorks Personal Edition Version**: 8.1.2  
**Platform**: Windows (x64)  
**Date Created**: 2026-05-13
