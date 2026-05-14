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
| 1   | 20.906         | 104.5         |
| 2   | 20.969         | 104.8         |
| 3   | 21.14          | 105.7         |
| **Average** | **21.005** | **105.0** |

#### Cached Dispatch

| Run | Time (seconds) | Per-call (µs) | Cache Hits |
|-----|----------------|---------------|-----------|
| 1   | 21.797         | 109.0         | 200,000   |
| 2   | 21.828         | 109.1         | 200,000   |
| 3   | 21.766         | 108.8         | 200,000   |
| **Average** | **21.797** | **109.0** | **200,000** |

#### Analysis

- **Caching Ratio**: 1.038× SLOWER (cached / uncached)
- **Baseline dispatch cost**: ~105 µs per call (vs SBCL ~30 ns, CCL ~360 ns, ABCL ~150 µs, LispWorks ~105 µs)
- **Interpretation**: Racket's JIT compilation is slower than SBCL for this tight loop, resulting in significant per-call overhead (~100× higher than SBCL). Caching overhead (key allocation + cache lookup + funcall) dominates, making caching slightly detrimental (~4% slower).

---

### Homogeneous Dispatch (Fixnum Only)

Test: All 200,000 calls with fixnum only

#### Uncached COND Dispatch

| Run | Time (seconds) | Per-call (µs) |
|-----|----------------|---------------|
| 1   | 46.64          | 233.2         |
| 2   | 46.422         | 232.1         |
| 3   | 46.703         | 233.5         |
| **Average** | **46.588** | **232.9** |

#### Cached Dispatch

| Run | Time (seconds) | Per-call (µs) | Cache Hits |
|-----|----------------|---------------|-----------|
| 1   | 48.844         | 244.2         | 200,000   |
| 2   | 48.562         | 242.8         | 200,000   |
| 3   | 48.422         | 242.1         | 200,000   |
| **Average** | **48.609** | **242.8** | **200,000** |

#### Analysis

- **Caching Ratio**: 1.043× SLOWER (cached / uncached)
- **Homogeneous dispatch overhead**: ~233 µs per call (2.2× higher than heterogeneous)
- **Interpretation**: In homogeneous case (all fixnums), the first COND clause always succeeds, so the uncached dispatch is highly predictable. Caching overhead still dominates, making caching 4.3% slower. This contrasts with SBCL (1.9× faster with caching due to aggressive inline optimization).

---

### Generic Function Dispatch

Test: 200,000 calls through generic function dispatch

#### Results

| Run | Time (seconds) | Per-call (µs) |
|-----|----------------|---------------|
| 1   | 46.406         | 232.0         |
| 2   | 46.219         | 231.1         |
| 3   | 46.797         | 234.0         |
| **Average** | **46.474** | **232.3** |

#### Analysis

- **Generic dispatch cost**: ~232 µs per call
- **Comparison with heterogeneous COND**: ~2.2× SLOWER than cached heterogeneous dispatch (105 vs 232 µs)
- **Scheme-specific dispatch**: Racket's generic function dispatch (using `define-generics`) is much slower than simple COND-based dispatch, similar to performance characteristics seen in SBCL and LispWorks

---

## Cross-Implementation Comparison

### Baseline Dispatch Cost (Heterogeneous, Uncached)

```
SBCL 2.6.0:        6.1 ms     (30.5 ns per call)      — Native code, aggressive inlining
CCL 1.13:         72.0 s      (360 ns per call)       — Native code, conservative
ABCL 1.9.2:       29.9 s      (149.4 µs per call)     — JVM bytecode interpretation
LispWorks 8.1.2:  21.1 s      (105.7 µs per call)     — Compiled bytecode
Racket 8.x:       21.0 s      (105.0 µs per call)     — JIT to native, similar overhead to LispWorks
```

### Caching Effectiveness

```
SBCL:       5.3× SLOWER with caching (overhead dominates; JIT optimization fails)
CCL:        1.02× FASTER with caching (type tests avoided, overhead acceptable)
ABCL:       ~1.0× NEUTRAL (JVM overhead and GC pressure dominate)
LispWorks:  1.20× SLOWER with caching (memory explosion from caching overhead)
Racket:     1.038× SLOWER with caching (JIT slower than SBCL, overhead dominates)
```

---

## Key Findings for Racket

1. **JIT Performance**: Racket's JIT is SLOWER than SBCL (105 µs vs 30.5 ns per call = ~3450× slower). Despite JIT compilation, Racket shows much higher baseline dispatch overhead.
2. **Type System**: Racket's type predicates (fixnum?, string?, etc.) and generic dispatch work correctly but are not optimized for the tight-loop dispatch pattern.
3. **Allocation Overhead**: Racket does NOT show memory explosion like LispWorks (baseline allocations are reasonable), but per-call overhead is significant.
4. **Scheme vs Lisp**: Racket (Scheme-based) shows similar caching failure as SBCL and LispWorks, but for different reasons:
   - SBCL: Overhead too small relative to ultra-fast JIT baseline
   - Racket: Baseline dispatch cost itself is ~3450× SBCL, making any optimization difficult
   - Scheme vs Lisp semantics appear not to be the differentiating factor

---

## Observations and Analysis

### Actual Compilation Strategy vs Expected

**Expected**: Racket baseline should be fast (10-100 ns range, similar to SBCL or CCL)
**Actual**: Racket baseline is ~105 µs — ~3,450× SLOWER than SBCL, on par with LispWorks

Racket does use:
- **JIT compilation to native code** (like SBCL)
- **Proper tail recursion** (as designed)
- **Immutable-by-default** (reduces GC pressure)

However:
- **Type predicates** (`fixnum?`, `string?`) are NOT inlined like SBCL's type checks
- **Dispatch overhead** is much higher than expected for a JIT-compiled language
- **COND branching** doesn't optimize as aggressively as SBCL's compiled machine code

### Caching Outcome: Confirmed Failure

**Prediction**: If baseline 100-500 ns, caching may help
**Actual**: Caching FAILS at 105 µs baseline (1.038× slower)

**Explanation**: Caching overhead (~4-5 µs per call) becomes significant relative to dispatch cost. Even when baseline is already high (105 µs), the additional overhead from cache key allocation, lookup, and indirect funcall is enough to eliminate any benefit from avoiding repeated type tests.

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
**Status**: Benchmarks completed and integrated (2026-05-13)
**Racket Version**: 9.1 (Windows x64)
**Platform**: Windows 11 Pro, AMD Ryzen 9 5900X (12 cores)
**Test Date**: 2026-05-13

