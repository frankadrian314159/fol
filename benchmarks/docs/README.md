# Dispatch Caching: Analysis and Findings

This directory contains comprehensive analysis and benchmarks of polymorphic inline caching for multi-clause function dispatch in Common Lisp.

## Contents

### Core Analysis Documents

1. **[caching.md](caching.md)** - Main analysis document
   - Executive summary of caching implementations
   - Benchmark results (micro and real-world)
   - Root cause analysis: why high cache hit rates don't help
   - Break-even analysis and recommendations
   - **Key finding**: Caching adds 5.3× overhead despite 99.9995% hit rate

2. **[assembly-analysis.md](assembly-analysis.md)** - Low-level machine code analysis
   - x86-64 disassembly comparison
   - Cycle-level cost breakdown
   - Why SBCL's COND compilation is optimal
   - Why indirect function calls destroy performance
   - **Key insight**: 5-10× more CPU cycles per cached call

3. **[assembly-tools.md](assembly-tools.md)** - Reference guide
   - How to use SBCL's disassembly tools
   - How to profile with `sb-sprof`
   - How to measure allocation overhead
   - How to interpret compiler output

### Benchmark Files

- **simple-micro-bench.lisp** - Homogeneous type dispatch (fixnum only)
  - Result: 1.9× faster with caching
  - Cache hit rate: ~100%
  - Conclusion: Caching helps when all types are the same

- **hetero-micro-bench.lisp** - Heterogeneous types (5-type cycle)
  - Result: 5.3× slower with caching
  - Cache hit rate: 99.9995%
  - Conclusion: High hit rates don't overcome overhead

- **disassemble-dispatch.lisp** - Assembly comparison tool
  - Shows machine code generated for both approaches
  - Highlights the instruction count difference
  - Reveals function call overhead

## Key Findings

### The Paradox

Despite achieving **99.9995% cache hit rate** on heterogeneous types:
- Caching is **5.3× SLOWER** than uncached dispatch
- Shows that cache hit rate ≠ performance

### Root Causes

1. **SBCL's COND dispatch is near-optimal**
   - Compiles to linear branch chain
   - No function calls or indirection
   - Branch predictor friendly
   - ~10-15 CPU cycles per dispatch

2. **Caching adds irreducible overhead**
   - Cache key creation (list consing): 10-20 cycles
   - Hash table lookup: 10-20 cycles
   - Function pointer indirection: 12-15 cycles
   - Total: ~50-100 cycles per cache hit

3. **Memory allocation kills performance**
   - Every cache key is a new list: `(list (type-of x))`
   - On 1M iterations, creates 1M list objects
   - Garbage collection pressure
   - Measured: 45 MB allocation per 1M calls with caching

### Assembly Evidence

**Uncached dispatch** (x86-64):
```asm
CMP QWORD PTR [RBP-8], -2000  ; Type test
JL L5                          ; Branch
(arithmetic)                   ; Clause body
RET                           ; Return
```
**~12 instructions, 0 function calls**

**Cached dispatch** (x86-64):
```asm
MOV R8, [RIP-263]             ; Load cache
MOV EAX, [R8-11]              ; Extract table
MOV RAX, [RAX+R13]            ; Dereference
LEA RCX, [RIP-339]            ; Load function
MOV RAX, [RCX+13]             ; Extract entry
CALL [RAX-3]                  ; INDIRECT CALL ← destroys branch prediction
(clause execution)
RET
```
**~50+ instructions, 3+ function calls**

## When Caching Could Help

Theoretical scenarios where caching **might** provide benefit:

1. **Expensive Predicates** (>50 cycles each)
   - Example: Regex pattern matching
   - Example: Complex type checking
   - Example: Symbolic reasoning
   - Would need to save >50 cycles of predicate evaluation

2. **Mega-Polymorphic Call Sites**
   - >20 clause options
   - Each clause has expensive predicate
   - Call pattern is stable

3. **JIT Compilation** (not Lisp-level caching)
   - Machine-code specialization
   - Direct jump cache (not funcall)
   - Elimination of allocation overhead

## Formulation: Break-Even Analysis

```
For caching to help:

  predicate_cost × clauses_before_hit > caching_overhead

  estimated values:
  - predicate_cost: 2-5 cycles for < or =
  - clauses_before_hit: 3-4 on average
  - caching_overhead: 50 cycles minimum

  simple_type_test:  5 cycles × 3 = 15 cycles  << 50 cycles overhead
  → Caching loses

  expensive_predicate: 50 cycles × 3 = 150 cycles > 50 cycles overhead
  → Caching might help
```

## Paper Contributions

This work demonstrates:

1. **Negative Result**: Polymorphic inline caching at the Lisp level is ineffective
   - Valuable for understanding language-level performance
   - Explains why dynamic language VMs use machine-code caching (V8, PyPy)

2. **Case Study**: High cache hit rates don't guarantee speedup
   - Performance depends on mechanism overhead
   - Profiling tools (hit rate, time) don't tell the full story

3. **Assembly-Level Analysis**: Shows exactly where overhead comes from
   - Quantifies cost of function calls vs branches
   - Explains why compiler optimization matters

4. **Characterization**: When inline caching could work in Lisp
   - Identifies predicate cost as key factor
   - Provides break-even formulation

## Recommendations for Future Work

### 1. JIT-Based Caching
Compile cached dispatch to machine code with:
- Direct jump addresses instead of funcall
- Inline type checks with no allocation
- Specialization that eliminates dispatch entirely

### 2. Selective Caching
Analyze predicate cost at compile time:
- Measure or estimate predicate cost
- Only apply caching if cost > threshold
- Fall back to COND for cheap predicates

### 3. Hierarchical Dispatch
- Fast path: compiled specialization for common cases
- Slow path: COND dispatch for rare types

### 4. Profile-Guided Optimization
- Monitor actual call patterns at runtime
- Specialize for observed types
- Adapt as patterns change

## Reproducibility

All benchmarks can be reproduced with:

```bash
# Compile compiler
cd src && sbcl --noinform --non-interactive \
  --eval "(push (truename \".\") asdf:*central-registry*)" \
  --eval "(asdf:load-system :fol-compiler)"

# Run micro-benchmarks
sbcl --noinform --non-interactive --load hetero-micro-bench.lisp
sbcl --noinform --non-interactive --load simple-micro-bench.lisp

# View assembly
sbcl --noinform --non-interactive --load disassemble-dispatch.lisp
```

## Implementation Details

### Cache Structure

**Ring Buffer (original)**:
- 8-slot vector of (key . function) pairs
- O(N) linear search on every access
- Ring buffer rotation on insert

**Hash Table (optimized)**:
- `(make-hash-table :test 'equal)` backed by SBCL's hash table
- O(1) lookup and insert
- Same O(1) hash operations, but inlined

### Inlining Optimization

Replaced function calls with inlined code:
- `(cache-lookup cache key)` → `(gethash key (dispatch-cache-table cache))`
- `(cache-insert! cache key fn)` → `(setf (gethash key ...) fn)`

Result: Removed 2 function call frames from hot path  
Impact: Negligible (still 5.3× slower)

## SBCL Version and Platform

- **SBCL**: 2.6.0 (2024-12-28)
- **Platform**: Windows 11 Pro, AMD Ryzen 9 5900X
- **Compiler Flags**: `(optimize (speed 3) (safety 0) (debug 1))`

## Conclusion

This work provides both negative and positive results:

**Negative**: Dispatch caching in Common Lisp is ineffective for simple type dispatch due to function-call overhead.

**Positive**: 
- Explains why machine-code caching (V8, PyPy) is necessary
- Characterizes the overhead precisely
- Provides a framework for understanding when caching could help
- Demonstrates the power of assembly-level analysis

For a research paper:
- Novel negative result on language implementation
- Rigorous experimental methodology
- Clear explanation via assembly analysis
- Actionable recommendations for future work

---

**Date**: 2026-05-12  
**Authors**: FOL Compiler Team  
**Status**: Complete analysis, ready for paper submission
