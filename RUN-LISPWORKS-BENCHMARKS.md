# Running LispWorks Dispatch Caching Benchmarks

## Quick Start

LispWorks Personal Edition doesn't support batch mode, so the benchmarks are designed for interactive evaluation in the IDE.

### Files Created

Three benchmark files for LispWorks interactive evaluation:

1. **hetero-micro-bench-lispworks.lisp** — Heterogeneous type dispatch (5-type cycle)
2. **simple-micro-bench-lispworks.lisp** — Homogeneous type dispatch (fixnum only)
3. **method-dispatch-bench-lispworks.lisp** — CLOS generic function dispatch

### Running Each Benchmark

For each file:

1. **Launch LispWorks Personal Edition**
2. **File → Open** and select one of the three benchmark files
3. **Ctrl+A** to select all code
4. **Ctrl+E** to evaluate the buffer
5. In the Listener window (REPL), type:
   ```lisp
   (RUN-ALL-BENCHMARKS)
   ```
6. Press Enter and wait for results

Results will print to the Listener window. Copy and paste them into **LISPWORKS-BENCHMARK-RESULTS.md**.

---

## Detailed Guide

See **LISPWORKS-BENCHMARK-GUIDE.md** for:
- Detailed step-by-step instructions with screenshots (conceptual)
- Expected output format
- Troubleshooting tips
- Performance notes

---

## Results Template

Use **LISPWORKS-BENCHMARK-RESULTS.md** to:
- Record timing results from each benchmark
- Compare with SBCL, CCL, and ABCL
- Analyze LispWorks' compilation strategy

---

## What Each Benchmark Measures

### Heterogeneous Dispatch (`hetero-micro-bench-lispworks.lisp`)

- **Test**: 200,000 calls cycling through 5 different types
- **Type cycle**: fixnum → string → list → vector → symbol
- **Measures**: Cache effectiveness with frequent type changes
- **Expected**: SBCL shows 5.3× slowdown; CCL shows 1.02× speedup

### Homogeneous Dispatch (`simple-micro-bench-lispworks.lisp`)

- **Test**: 200,000 calls, all fixnum (same type every time)
- **Measures**: Cache effectiveness with single type (branch prediction)
- **Expected**: SBCL shows 1.9× speedup; CCL shows slight benefit

### Method Dispatch (`method-dispatch-bench-lispworks.lisp`)

- **Test**: 200,000 calls through CLOS generic function with 6 methods
- **Measures**: CLOS dispatch overhead vs COND dispatch
- **Expected**: Native CLOS caching may already be engaged

---

## Integration with Results Document

After running all three benchmarks in LispWorks:

1. Edit **LISPWORKS-BENCHMARK-RESULTS.md**
2. Replace all "TBD" values with actual timings from LispWorks
3. The document will automatically show cross-implementation comparison

The updated document will integrate into the main **COMPARATIVE-BENCHMARK-RESULTS.md** for the paper.

---

## Expected Performance

Based on LispWorks' compilation strategy (conservative native code like CCL):

| Metric | Expected |
|--------|----------|
| Heterogeneous uncached | ~5-100 ms (between SBCL and CCL) |
| Heterogeneous cached | Possibly 1-5% slower or faster |
| Baseline dispatch | ~50-500 ns per call |
| Caching ratio | 0.9-1.2× (near neutral or slight benefit) |

---

## Notes

- **JIT warmup**: First runs may be slower as the JIT compiler engages
- **Multiple iterations**: Run 3 iterations to account for startup overhead
- **System load**: Close other applications for consistent timing
- **LispWorks limitations**: Personal Edition is interactive-only; no batch mode support

---

## Files Reference

- `hetero-micro-bench-lispworks.lisp` — Run first for heterogeneous test
- `simple-micro-bench-lispworks.lisp` — Run second for homogeneous test
- `method-dispatch-bench-lispworks.lisp` — Run third for method dispatch test
- `LISPWORKS-BENCHMARK-GUIDE.md` — Detailed instructions
- `LISPWORKS-BENCHMARK-RESULTS.md` — Template for recording results

---

## Next Steps

1. Run benchmarks in LispWorks IDE
2. Record results in LISPWORKS-BENCHMARK-RESULTS.md
3. Update COMPARATIVE-BENCHMARK-RESULTS.md with LispWorks row
4. Finalize paper analysis with four-implementation comparison (SBCL, CCL, ABCL, LispWorks)

---

**Created**: 2026-05-13  
**Implementation**: LispWorks Personal Edition 8.1.2

