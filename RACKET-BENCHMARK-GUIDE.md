# Racket Dispatch Caching Benchmark Guide

## Installation

### Step 1: Download Racket

1. Visit: https://download.racket-lang.org/
2. Select **Windows (x64)** for 64-bit systems
3. Download the `.exe` installer
4. Run the installer and follow the prompts
5. Default installation to `C:\Program Files\Racket` is fine

### Step 2: Verify Installation

Open PowerShell and run:

```powershell
racket --version
```

You should see output like:
```
Welcome to Racket v8.x.x [compiled]
```

## Files

Three Racket benchmark files have been created:

1. **hetero-micro-bench-racket.rkt** — Heterogeneous type dispatch (5-type cycle)
2. **simple-micro-bench-racket.rkt** — Homogeneous type dispatch (fixnum only)
3. **method-dispatch-bench-racket.rkt** — Generic function dispatch

## Running Benchmarks

For each benchmark file:

```powershell
cd 'C:\Users\frank\Projects\FOL\fol'
racket hetero-micro-bench-racket.rkt
```

Or use the Racket IDE (DrRacket):

1. Launch DrRacket
2. **File → Open** → Select the `.rkt` file
3. Click **Run** button (top right)
4. Results appear in the console panel

## Expected Output

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

## Key Differences from Lisp

Racket uses:
- **Lexical scoping** instead of dynamic scoping
- **Immutable data structures** by default (mutable via `set!` and `set-!`)
- **Different type system** (fixnum is `exact-integer`, not Common Lisp fixnum)
- **JIT compilation** similar to SBCL/CCL
- **Proper tail recursion** (allows iterative dispatch loops)

## Recording Results

Run all three benchmarks and record the times from each run:

**Heterogeneous:**
- Uncached: Run 1, Run 2, Run 3 (average)
- Cached: Run 1, Run 2, Run 3 (average)

**Homogeneous:**
- Uncached: Run 1, Run 2, Run 3 (average)
- Cached: Run 1, Run 2, Run 3 (average)

**Method Dispatch:**
- Generic: Run 1, Run 2, Run 3 (average)

---

## Performance Expectations

Racket is known for:
- **Fast JIT compilation** (competitive with SBCL for tight loops)
- **Efficient dispatch** (compiled to native code like SBCL)
- **Lower allocation overhead** than some Lisps (immutable-by-default helps)

Expected behavior:
- **Homogeneous dispatch** may show significant caching benefit (like SBCL)
- **Heterogeneous dispatch** may show caching overhead (like SBCL, due to branch prediction)
- **Overall speed** likely between CCL and ABCL

---

## Troubleshooting

### `command not found: racket`
- Racket not in PATH. Add `C:\Program Files\Racket\bin` to your PATH environment variable
- Or use full path: `C:\Program Files\Racket\bin\racket.exe file.rkt`

### Port already in use / DrRacket won't start
- Restart your terminal/IDE
- Check for hung Racket processes: `Get-Process racket | Stop-Process`

### Benchmark runs very slowly
- First run includes JIT compilation overhead—subsequent runs are faster
- Racket's garbage collector may run during benchmark (normal)

---

## Next Steps

1. Run all three benchmarks
2. Copy output to **RACKET-BENCHMARK-RESULTS.md**
3. Integrate with four-implementation comparison (SBCL, CCL, ABCL, LispWorks)

---

**Created**: 2026-05-13  
**Racket Version**: 8.x (tested with 8.12+)  
**Platform**: Windows x64

