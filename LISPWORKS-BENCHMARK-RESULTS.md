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
- **Expected baseline cost**: ~? ns (vs SBCL ~30 ns, CCL ~360 ns, ABCL ~150 µs)

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
SBCL 2.6.0:        6.1 ms (30.5 ns per call)
CCL 1.13:         72.0 s  (360 ns per call)
ABCL 1.9.2:       29.9 s  (149.4 µs per call)
LispWorks 8.1.2:  TBD s   (TBD ns per call)
```

### Caching Effectiveness

```
SBCL:       5.3× SLOWER with caching (overhead dominates)
CCL:        1.02× FASTER with caching (type tests avoided)
ABCL:       ~1.0× NEUTRAL (GC pressure dominates)
LispWorks:  TBD (conservative compilation vs aggressive JIT?)
```

---

## Observations and Analysis

### JIT Compilation Strategy

LispWorks Personal Edition uses a combination of:
- Interpretation of source code
- On-demand native code compilation via embedded C backend
- More conservative optimization than SBCL

**Expected**: LispWorks baseline should be slower than SBCL, possibly between CCL and ABCL, depending on:
1. How aggressively COND branches are optimized
2. Whether type tests are inlined
3. Register allocation strategy

### Caching Outcome Prediction

Based on compilation strategy, we might expect:

- If LispWorks baseline < 100 ns: Caching fails (like SBCL)
- If LispWorks baseline 100-500 ns: Caching helps (like CCL)
- If LispWorks baseline > 1 µs: Caching effect is masked (like ABCL)

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

