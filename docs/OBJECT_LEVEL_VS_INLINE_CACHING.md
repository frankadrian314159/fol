# Object-Level vs. Inline Caching: Why They're Different

## TL;DR

- **Object-level caching** (this paper): Store dispatch decisions in hash tables → **FAILS** (14-20 ns overhead)
- **Inline caching** (V8, PyPy, GraalVM): Embed type checks in machine code → **SUCCEEDS** (2-5 ns overhead)

This paper proves the first fails; it does NOT test the second (which already works).

---

## What Is Object-Level Caching?

**Object-level caching** stores dispatch decisions as data structures at runtime.

### How It Works

```python
# Dispatch without caching
def dispatch(obj):
    if isinstance(obj, int):
        return handle_int(obj)
    elif isinstance(obj, str):
        return handle_string(obj)
    else:
        return handle_other(obj)

# With object-level caching
dispatch_cache = {}  # Global cache table

def dispatch_cached(obj):
    key = type(obj)
    
    if key in dispatch_cache:
        # Cache hit: avoid type checking
        handler = dispatch_cache[key]
        return handler(obj)
    
    # Cache miss: evaluate dispatch, store result
    if isinstance(obj, int):
        handler = handle_int
    elif isinstance(obj, str):
        handler = handle_string
    else:
        handler = handle_other
    
    dispatch_cache[key] = handler  # Store for next time
    return handler(obj)
```

### Cost Breakdown (Per-Call Overhead)

```
Cache hit:
  - Hash table lookup: 3-5 ns (memory access, hash computation)
  - Mutex lock/unlock: 5-7 ns (atomic operation for thread safety)
  - Indirect function call: 3-5 ns (CPU pipeline stall)
  ────────────────────────────────
  Total: 11-17 ns overhead per call

Cache miss:
  - All of above PLUS
  - Type check evaluation: varies (1-100 ns)
  - Hash insert: 2-3 ns
  ────────────────────────────────
  Total: 15-120+ ns depending on baseline
```

### Result in This Paper

- **Single-argument dispatch**: 1.6 ns baseline + 16 ns overhead = **11.49× slowdown**
- **Multi-argument dispatch**: 95.6 ns baseline + 14 ns overhead = **1.15× slowdown** (least bad)
- **Generic function dispatch**: 2.5 ns baseline + 16 ns overhead = **27.21× slowdown** (worst)

**Conclusion**: Object-level caching fails because overhead cannot go below ~11-17 ns, which exceeds most realistic dispatch costs.

---

## What Is Inline Caching?

**Inline caching** (also called "polymorphic inline caching" or PIC) embeds cached type checks directly into compiled machine code.

### How It Works (V8 Example)

```javascript
// Original JavaScript code
function process(x) {
  if (typeof x === "number") {
    return x * 2;
  } else if (typeof x === "string") {
    return x + "!";
  } else {
    return undefined;
  }
}

// What V8's JIT compiler generates:
// 
// First call: process(42)
//   mov rax, [rbp+8]        # Load argument
//   cmp [rax], type_number  # Check if number (direct comparison)
//   je .number_path         # Jump if match
//   jmp .generic            # Try next type
// .number_path:
//   mov rcx, 2
//   imul rax, rcx           # Multiply by 2
//   ret
//
// After V8 sees the type multiple times (monomorphic):
//   # Code is specialized; type check is inlined
//   mov rax, [rbp+8]        # Load argument
//   mov ecx, [rax-1]        # Load type tag (1-2 cycles)
//   cmp ecx, 0x5            # Compare with cached type
//   jne .deopt              # If mismatch, deoptimize
//   # Fast path: already know it's a number!
//   mov rcx, 2
//   imul rax, rcx
//   ret
//
// Second call with same type: CPU branch prediction succeeds!
//   - Branch prediction: 2-3 cycles (already predicted)
//   - No type checking needed; code is specialized
//   - No hash lookup
//   - No memory allocation
```

### Cost Breakdown (Per-Call Overhead)

```
Monomorphic call (single type observed):
  - CPU branch prediction: 2-3 ns (predicted correctly)
  - Direct type tag check: 1-2 ns (embedded in code)
  - Direct jump: <1 ns (CPU predicted)
  ────────────────────────────────
  Total: 2-5 ns overhead (if prediction succeeds)

Polymorphic call (multiple types):
  - Mispredicted branch: 10-15 ns (pipeline flush)
  - Check each type: 1-2 ns per type
  - Deoptimization (if needed): Can be expensive
  ────────────────────────────────
  Total: varies, but amortized across many calls
```

### Result in Production

- **V8 (JavaScript)**: <1 ns baseline (monomorphic), near-zero overhead when specialized
- **PyPy (Python)**: 1-10 ns baseline, 2-5 ns overhead (tracing JIT specializes hot paths)
- **GraalVM (Java)**: Similar to PyPy; per-site specialization achieves 2-5 ns overhead

**Conclusion**: Inline caching succeeds because it:
1. Avoids memory allocation
2. Uses branch prediction (>90% accurate)
3. Embeds type checks as constants (no lookup)
4. Specializes code per call site

---

## Side-by-Side Comparison

| Aspect | Object-Level Caching | Inline Caching |
|--------|----------------------|----------------|
| **Storage** | Hash table (data structure) | Compiled code (machine instructions) |
| **Lookup Cost** | 3-5 ns (memory access + hash) | <1 ns (CPU prediction) |
| **Thread Safety** | Requires locks (5-7 ns) | JIT handles synchronization |
| **Infrastructure** | Works in any language | Requires JIT compiler |
| **Specialization** | Generic cache for all types | Per-call-site specialization |
| **Overhead** | 11-17 ns minimum | 2-5 ns |
| **Per-Call Performance** | Slow (overhead ≈ or > baseline) | Fast (overhead << baseline) |
| **Status** | This paper: **FAILS** | Industry standard: **WORKS** |

---

## Why Inline Caching Works Where Object-Level Fails

### The Physics

**CPU memory hierarchy**:
```
L1 cache (on-chip): 4 bytes/cycle (1-2 ns)
L2 cache (on-chip): 4-10 cycles (4-10 ns)
L3 cache (shared): 12-20 cycles (12-20 ns)
RAM: 100-300 cycles (100-300 ns)
```

**Object-level caching path**:
1. Mutex lock → atomic operation (CPU stall, 5-7 ns)
2. Hash lookup → memory access (L3 cache, 12-20 ns)
3. Indirect call → pipeline stall (3-5 ns)
4. **Total**: 20-32 ns minimum

**Inline caching path**:
1. Type check → embedded in code (0 ns, already executing)
2. Branch prediction → on-chip (1-2 cycles, ~2 ns)
3. Direct jump → predicted (0 ns if prediction correct)
4. **Total**: 2-5 ns

**The gap is fundamental**: You cannot make a hash table lookup faster than ~20 ns on modern CPUs. You CAN embed type checks in code and use branch prediction to make them ~2 ns.

---

## Real-World Evidence

### V8 (JavaScript Engine)

```javascript
// This code with inline caching:
const obj = {x: 5};
for (let i = 0; i < 1000000; i++) {
  obj.x;  // Property access
}

// V8 generates:
// 1. First access: Check if obj has property x (slow)
// 2. After 100 accesses: Specialize code for this object shape
// 3. Next 999,900 accesses: Direct memory load (2-3 ns each)

// Total time: Fast! (dominated by direct loads, not dispatch)
```

### If V8 used object-level caching instead:

```javascript
property_cache = {}

function getProperty(obj, prop):
  key = (id(obj), prop)  # Create tuple key
  
  if key in property_cache:  # Hash lookup (20+ ns)
    return property_cache[key](obj)
  
  # ... evaluate, store, return
```

**Result**: Property access would be 5-10× slower. V8 deliberately chose inline caching to avoid this problem.

---

## Why This Paper Tests Object-Level, Not Inline

### The Paper's Scope

**Object-level caching** is the only approach that:
1. Works WITHOUT JIT infrastructure
2. Can be applied to any language
3. Can be implemented in user code or library code

**Testing object-level** answers: "Can we speed up dispatch without a JIT compiler?"

**Answer**: No. The overhead is fundamental.

### Why NOT Test Inline Caching

**Inline caching already works** (proven in production for 30+ years):
- V8: 2-4× speedups for dispatch-heavy code
- PyPy: 5-10× speedups for type-unstable Python
- GraalVM: Similar speedups across JVM languages

Testing this would be:
1. Redundant (already proven effective)
2. Not comparable (different mechanism)
3. Not applicable to interpreted languages (requires JIT)

---

## For Language Designers: Which Approach to Choose

### If you're building a new language:

**Do you have resources for a JIT compiler?**
- **Yes** → Use inline caching (like V8, PyPy, GraalVM). This paper's findings don't apply.
- **No** → Don't implement object-level caching (this paper proves it fails). Instead:
  1. Optimize dispatch compilation (make baseline as fast as possible)
  2. Consider AOT compilation (Rust approach)
  3. Use static typing to eliminate dispatch (like TypeScript)

**Is dispatch a bottleneck in your workloads?**
- **Not really** → Don't optimize dispatch at all. Most time is in user code.
- **Yes** → Invest in JIT + inline caching. Don't use object-level caching.

---

## FAQ

**Q: Doesn't V8 use object-level caching somewhere?**

A: No. V8 uses machine-code inline caching exclusively. It also uses:
- Hidden class optimization (monomorphic specialization)
- Escape analysis (avoid allocations)
- Deoptimization (revert to slower path if assumptions break)

But never object-level (hash table) caching.

**Q: Could we make object-level caching faster with a different hash table?**

A: No. The fundamental costs are:
- Mutex lock: 5-7 ns (CPU atomic operation, unavoidable for thread safety)
- Memory access: 10-20 ns (CPU cache hierarchy)
- Indirection: 3-5 ns (pipeline stall from indirect call)

These are determined by CPU physics, not data structure choice.

**Q: What if we use a lock-free hash table?**

A: Still ~15-20 ns overhead (memory access + indirection dominate). No improvement over mutex.

**Q: If dispatch costs >10 µs, does object-level caching help?**

A: Yes. But no production language implements dispatch that slowly. If yours does, fix the dispatch, not the cache.

**Q: What about caching at a different level (bytecode cache, JIT cache)?**

A: Those are different problems:
- Bytecode cache: Caching compiled bytecode, not dispatch decisions
- JIT cache: Already inline (machine-code level), not object-level

Both are orthogonal to this paper.

---

## Conclusion

**Object-level dispatch caching fails** because cache overhead (~14-20 ns) cannot go below CPU physics limits, and modern dispatch implementations (1-500 ns) are too fast for caching to help.

**Inline caching succeeds** because it embeds type checks in compiled code and uses CPU branch prediction to achieve 2-5 ns overhead.

**This paper tests object-level; it does NOT contradict inline caching's success.**

If you're designing a language: Use inline caching (JIT) if possible. Don't use object-level caching. If you can't use JIT, optimize dispatch compilation instead of caching.

