# Racket 8.x Dispatch Caching Benchmark Results

## Test Configuration

- **Implementation**: Racket (Scheme dialect)
- **Platform**: Windows 11 Pro, AMD Ryzen 9 5900X (12 cores)
- **Test Data**: 200,000 calls per iteration
- **Compiler**: JIT (Just-in-Time compilation to native code)

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
- **Baseline dispatch cost**: ~? ns (vs SBCL ~30 ns, CCL ~360 ns, LispWorks ~105 µs)

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

### Generic Function Dispatch

Test: 200,000 calls through generic function dispatch

#### Results

| Run | Time (seconds) | Per-call (µs) |
|-----|----------------|---------------|
| 1   | TBD            | TBD           |
| 2   | TBD            | TBD           |
| 3   | TBD            | TBD           |
| **Average** | **TBD** | **TBD** |

#### Analysis

- **Baseline generic dispatch cost**: TBD µs
- **Comparison with COND**: TBD (faster / slower than heterogeneous COND)

---

## Cross-Implementation Comparison

### Baseline Dispatch Cost (Heterogeneous, Uncached)

```
SBCL 2.6.0:        6.1 ms     (30.5 ns per call)
CCL 1.13:         72.0 s      (360 ns per call)
ABCL 1.9.2:       29.9 s      (149.4 µs per call)
LispWorks 8.1.2:  21.1 s      (105.7 µs per call)
Racket 8.x:       TBD s       (TBD per call)
```

### Caching Effectiveness

```
SBCL:       5.3× SLOWER with caching (overhead dominates)
CCL:        1.02× FASTER with caching (type tests avoided)
ABCL:       ~1.0× NEUTRAL (GC pressure dominates)
LispWorks:  1.20× SLOWER with caching (memory explosion)
Racket:     TBD (fast JIT like SBCL?)
```

---

## Key Questions for Racket

1. **JIT Performance**: Will Racket's JIT compile dispatch as aggressively as SBCL?
2. **Type System**: How does Racket's type dispatch (fixnum vs exact-integer) compare?
3. **Allocation Overhead**: Will Racket avoid LispWorks' allocation explosion?
4. **Scheme vs Lisp**: How do Scheme semantics differ from Common Lisp for dispatch?

---

## Observations and Analysis

### Compilation Strategy

Racket uses:
- **JIT compilation to native code** (like SBCL)
- **Aggressive inline optimization** (similar to SBCL)
- **Proper tail recursion** (inherent optimization)
- **Immutable-by-default** (may reduce allocation pressure)

**Expected**: Racket baseline should be fast (10-100 ns range, similar to SBCL or CCL).

### Caching Outcome Prediction

Based on Racket's compilation strategy:

- If Racket baseline < 100 ns: Caching likely fails (like SBCL)
- If Racket baseline 100-500 ns: Caching may help (like CCL)
- If Racket shows less allocation overhead: Caching ratio better than LispWorks

---

## Instructions for Running Tests

See **RACKET-BENCHMARK-GUIDE.md** for:
1. Installing Racket
2. Running benchmark files
3. Recording results

---

## Results Entry Template

When running benchmarks, copy the output and paste timing values into tables above, replacing "TBD".

Example raw output:

```
================================
Racket Heterogeneous Dispatch Caching Micro-Benchmark
================================
Implementation: Racket 8.x.x
Test data: 200,000 calls over repeating 5-type cycle
  Type cycle: fixnum -> string -> list -> vector -> symbol

Warming up JIT compiler (10,000 calls)...
Warmup complete.

=== Uncached COND Dispatch (3 iterations) ===
  Run 1: X.XXX seconds
  Run 2: X.XXX seconds
  Run 3: X.XXX seconds

=== Cached Dispatch (3 iterations) ===
  Run 1: X.XXX seconds
  Run 2: X.XXX seconds
  Run 3: X.XXX seconds

Cached Dispatch Stats:
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

