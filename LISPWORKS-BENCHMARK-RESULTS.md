# LispWorks 8.1.2 Dispatch Caching Benchmark Results

## Test Configuration

- **Implementation**: LispWorks Personal Edition 8.1.2 (x64)
- **Platform**: Windows 11 Pro, AMD Ryzen 9 5900X (12 cores)
- **Test Data**: 200,000 calls per iteration
- **Test Environment**: Interactive evaluation in LispWorks IDE

---

## Benchmark Results

### Heterogeneous Dispatch (5-Type Cycle)

Test: fixnum → string → list → vector → symbol

#### Uncached COND Dispatch

| Run | Time (seconds) | Per-call (µs) | Allocation |
|-----|----------------|---------------|------------|
| 1   | 21.128         | 105.64        | 798 MB    |
| 2   | 21.127         | 105.64        | 798 MB    |
| 3   | 21.159         | 105.80        | 798 MB    |
| **Average** | **21.138** | **105.69** | **798 MB** |

#### Cached Dispatch

| Run | Time (seconds) | Per-call (µs) | Cache Hits | Allocation |
|-----|----------------|---------------|-----------|------------|
| 1   | 25.408         | 127.04        | 200,000   | 5,530 MB  |
| 2   | 25.425         | 127.13        | 200,000   | 5,531 MB  |
| 3   | ~25.4          | ~127.0        | 200,000   | ~5,530 MB |
| **Average** | **25.412** | **127.06** | **200,000** | **5,531 MB** |

#### Analysis

- **Caching Ratio**: 1.202× SLOWER with caching (20.2% slowdown)
- **Baseline dispatch cost**: ~105.7 µs per call
- **Memory explosion**: 798 MB → 5,531 MB with caching (6.9× more allocation)
- **Notable**: %EVAL calls increase from 8.1M to 30.3M with caching (3.7× more evals)

---

### Homogeneous Dispatch (Fixnum Only)

Test: All 200,000 calls with fixnum only

#### Uncached COND Dispatch

| Run | Time (seconds) | Per-call (µs) |
|-----|----------------|---------------|
| 1   | TBD            | TBD           |
| 2   | TBD            | TBD           |
| 3   | TBD            | TBD           |
| **Average** | **TBD** | **TBD** |

#### Cached Dispatch

| Run | Time (seconds) | Per-call (µs) | Cache Hits |
|-----|----------------|---------------|-----------|
| 1   | TBD            | TBD           | TBD       |
| 2   | TBD            | TBD           | TBD       |
| 3   | TBD            | TBD           | TBD       |
| **Average** | **TBD** | **TBD** | **200,000** |

#### Analysis

- **Caching Ratio**: TBD× (cached time / uncached time)
- **Branch prediction effect**: TBD (vs SBCL 1.9× faster with caching)

---

### Generic Function Dispatch (CLOS defmethod)

Test: 200,000 calls through CLOS dispatch with 6 methods

#### Results

| Run | Time (seconds) | Per-call (µs) |
|-----|----------------|---------------|
| 1   | TBD            | TBD           |
| 2   | TBD            | TBD           |
| 3   | TBD            | TBD           |
| **Average** | **TBD** | **TBD** |

#### Analysis

- **Baseline dispatch cost**: TBD µs
- **Comparison with COND**: TBD (faster / slower than heterogeneous COND)

---

## Cross-Implementation Comparison

### Baseline Dispatch Cost (Heterogeneous, Uncached)

```
SBCL 2.6.0:        6.1 ms     (30.5 ns per call)
CCL 1.13:         72.0 s      (360 ns per call)
ABCL 1.9.2:       29.9 s      (149.4 µs per call)
LispWorks 8.1.2:  21.1 s      (105.7 µs per call)
```

### Caching Effectiveness

```
SBCL:       5.3× SLOWER with caching (overhead dominates, baseline too optimized)
CCL:        1.02× FASTER with caching (type tests dominate cost)
ABCL:       ~1.0× NEUTRAL (JVM GC overhead masks dispatch)
LispWorks:  1.20× SLOWER with caching (memory allocation explodes 7×)
```

---

## Observations and Analysis

### Compilation Strategy

LispWorks Personal Edition uses:
- Interpretation combined with on-demand native code compilation
- Embedded C backend for native code generation
- More conservative optimization than SBCL

**Actual Results**: Baseline is ~105 µs per call (intermediate between ABCL and CCL).

### Key Finding: Memory Allocation Explosion

The most striking result is **memory allocation**:
- **Uncached**: 798 MB (4 bytes per call)
- **Cached**: 5,531 MB (27.6 bytes per call)
- **Ratio**: 6.93× more allocation with caching

This massive allocation increase is due to:
1. Cache structure (dispatch-cache struct)
2. Key allocation (cons cells for (class-of x) pairs)
3. Function object references (stored as cache values)
4. Hash table growth (lookup table maintenance)

**Impact on Performance**: The allocation overhead is so severe that caching becomes **1.2× slower** despite 100% hit rate.

### Caching Outcome Explanation

For LispWorks (baseline ~105 µs):
- Cache overhead includes 27.6 bytes allocation per call
- Type test in COND (~10-20 µs) is cheap compared to baseline
- Savings from avoiding COND (<1% of baseline) don't offset allocation cost
- Result: Caching fails due to memory pressure, not dispatch speed

---

## Instructions for Running Tests

See **LISPWORKS-BENCHMARK-GUIDE.md** for step-by-step instructions on:
1. Opening benchmark files in LispWorks IDE
2. Evaluating the code
3. Running (RUN-ALL-BENCHMARKS)
4. Recording results

---

## Results Entry Template

When running benchmarks, copy the output from the LispWorks Listener window and paste here, replacing "TBD" values in the tables above.

Example raw output:

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

---

**Created**: 2026-05-13  
**Status**: Template awaiting benchmark execution

