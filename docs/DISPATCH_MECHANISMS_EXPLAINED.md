# Dispatch Mechanisms Explained: What We Test vs. What We Don't

## Critical Distinction: Object-Level vs. Inline Caching

### What This Paper Tests: Object-Level Caching
**Definition**: Storing dispatch decisions in runtime data structures (hash tables, vectors, association lists) without JIT infrastructure.

**Implementation pattern**:
```
cache_lookup(key):
  if key in cache_table:
    return cache_table[key]  # Fast path: return cached decision
  else:
    result = evaluate_dispatch(key)  # Slow path: evaluate predicates
    cache_table[key] = result
    return result
```

**Characteristics**:
- Store (type-tuple → method/clause) mappings in hash tables
- Look up on every call via hash lookup
- Uses round-robin LRU eviction with fixed slot count
- Works with any language, even without JIT
- Incurs memory access, hash computation, and indirection overhead (~14-20 ns minimum)

**Our result**: Object-level caching **fails universally** (16/17 implementations, 4/5 mechanisms show slowdown)

---

### What We DON'T Test: Adaptive/Polymorphic Inline Caching (PIC)

**Definition**: JIT compiler embeds cached type checks directly into compiled machine code, avoiding data structure lookups entirely.

**Implementation pattern** (V8 example):
```
// Original dispatch site
foo(obj):
  if obj.type == Int:
    return int_handler(obj)
  else if obj.type == String:
    return string_handler(obj)
  else:
    return generic_dispatch(obj)

// After first call with Int
foo(obj):                    // Jump target for monomorphic Int path
  cmp [obj], Int_tag       // Direct memory comparison (1-2 cycles)
  jne slow_path            // Branch with CPU prediction
  mov rax, int_handler_addr
  jmp [rax]
slow_path:
  jmp generic_dispatch     // Falls through to slow path

// On second Int call: predicted jump succeeds, no type checking!
```

**Characteristics**:
- Type checks embedded as CPU instructions, not data lookups
- Direct jumps with CPU branch prediction (>90% accuracy)
- No memory allocation, no hash computation
- Requires JIT compiler infrastructure
- Can achieve 2-10 ns overhead instead of 20+ ns

**Result**: Inline caching **succeeds dramatically** in V8, PyPy, GraalVM (proven effective for decades)

**Our finding does NOT contradict this**—we only study object-level approaches.

---

## The Five Dispatch Mechanisms We Test

All five use **object-level caching** (not inline caching). They differ in what is being dispatched:

### 1. Single-Argument Dispatch (11.49× slowdown)

**What**: Type switch on a single parameter—dispatch based on class/type of ONE argument.

**Code pattern**:
```clojure
(defn process [x]
  (cond
    (integer? x) (handle-int x)
    (string? x)  (handle-string x)
    (list? x)    (handle-list x)
    :else        (handle-other x)))
```

**Cache key**: `(class-of x)` — single class object

**Why tested**: 
- **Most common dispatch pattern** in OO programming
- Virtual method dispatch (receiver dispatch) is single-argument
- Fundamental to polymorphism

**Why it fails worst** (11.49× slowdown):
- Baseline: 1.6 ns (ultra-fast single type check)
- Overhead: 16-20 ns (mutex + hash + indirection)
- Ratio: 10-12× overhead vs. baseline
- **Result**: Caching makes the simplest dispatch 11× slower

**Practical languages affected**:
- Ruby: `case obj; when Integer; ... when String; ... end`
- Python: type-based dispatch on single argument
- Java/C++: virtual method dispatch (single receiver)

---

### 2. Multi-Argument Dispatch (1.15× slowdown)

**What**: Type switch on MULTIPLE parameters simultaneously. Dispatch based on types of TWO OR MORE arguments.

**Code pattern**:
```clojure
(defn add [x y]
  (cond
    (and (integer? x) (integer? y)) (+ x y)
    (and (string? x) (string? y))   (str-concat x y)
    (and (list? x) (list? y))       (merge-lists x y)
    :else                           (generic-add x y)))
```

**Cache key**: `(list (class-of x) (class-of y))` — tuple of class objects

**Why tested**: 
- **Original paper's main test case** (reason for benchmark choice)
- Important for operator overloading (e.g., arithmetic on heterogeneous types)
- Example: `(+ 3 4.5)` dispatches on (integer, float)

**Why it fails less severely** (1.15× slowdown):
- Baseline: 95.6 ns (multiple type checks)
- Overhead: 14-20 ns
- Ratio: 15% overhead vs. baseline
- **Result**: Caching is nearly neutral; overhead is small fraction of baseline

**Practical languages affected**:
- Clojure/Common Lisp: multimethods with multiple dispatch
- Python: `@singledispatch` on multiple arguments (e.g., `@functools.singledispatch`)
- Julia: multiple dispatch system

---

### 3. Generic Function Dispatch (27.21× slowdown)

**What**: Multi-method dispatch testing multiple PREDICATES in sequence until one matches. Tests conditions in order; first match wins.

**Code pattern**:
```clojure
(defgeneric classify
  ([x (even?)]     :even-number)     ; Test predicate first
  ([x (< x 0)]     :negative)        ; Test predicate
  ([x (< x 100)]   :small-positive)  ; Test predicate
  ([x]             :large-positive)) ; Fallback
```

**Cache key**: `(list (class-of x))` for type part, but tests predicates in sequence.

**Why tested**: 
- **Beyond standard CLOS methods** (predicate-based dispatch)
- Used in Clojure's `defmulti` with guards
- Julia's multiple dispatch with predicates
- More expressive than simple type dispatch

**Why it fails catastrophically** (27.21× slowdown, WORST CASE):
- Baseline: 2.5 ns (ultra-fast predicate sequence)
- Overhead: 16-20 ns
- Ratio: 6-8× overhead vs. baseline
- **Result**: Caching makes generic dispatch 27× slower (WORST in entire study!)

**Practical languages affected**:
- Clojure: defmulti dispatch with guards
- Julia: multiple dispatch with conditions
- Racket: predicate dispatch

---

### 4. Property-Based Dispatch (15.63× slowdown)

**What**: Protocol/trait/structural dispatch. Dispatch based on CAPABILITY or PROTOCOL MEMBERSHIP, not nominal type.

**Code pattern**:
```clojure
(defprotocol Drawable
  (draw [this]))

(extend-protocol Drawable
  Integer
  (draw [x] (print-int x))
  
  String
  (draw [x] (print-string x)))

(draw 42)         ; Dispatch: Is 42 Drawable? (yes, via Integer)
(draw "hello")    ; Dispatch: Is "hello" Drawable? (yes, via String)
```

**Cache key**: `(class-of x)` — but checking protocol membership, not static type

**Why tested**: 
- **Different from type-based dispatch** (structural vs. nominal)
- Fundamental to Clojure protocols, Rust trait dispatch, Python duck typing
- Represents capability-based dispatch model

**Why it fails** (15.63× slowdown):
- Baseline: 1.3 ns (type assertion for protocol)
- Overhead: 16-20 ns
- Ratio: 12× overhead vs. baseline
- **Result**: Failure is NOT specific to type-based dispatch; applies to all structural dispatch

**Practical languages affected**:
- Clojure: protocols (structural dispatch)
- Rust: trait dispatch
- Python: protocol checking (typing.Protocol)
- Go: interface satisfaction checking

---

### 5. Hash Dispatch (0.95× speedup) ★ BREAK-EVEN POINT

**What**: Direct dictionary/hash table lookup of handlers. Already a form of caching.

**Code pattern**:
```lua
-- Lua: direct table lookup (IS caching already)
function dispatch(method, obj)
  local handler = methods[obj.type][method]
  return handler(obj)
end

-- OR: JavaScript property lookup
function dispatch(obj, method) {
  return obj[method]()
}
```

**Cache key**: N/A (this IS a cache, not dispatch per se)

**Why tested**: 
- **Break-even validation** (only mechanism where caching helps)
- Validates the mathematical theory
- Shows that when baseline ≈ overhead, caching can marginally help
- Common in scripting languages (Lua, JavaScript)

**Why it marginally succeeds** (0.95× speedup, 5% faster):
- Baseline: 9.0 ns (hash lookup)
- Cached lookup: 8.5 ns
- Ratio: 0.95× (5% faster)
- **Result**: When baseline and overhead are comparable (~10 ns), caching breaks even

**Practical languages affected**:
- Lua: table dispatch
- JavaScript: property lookup (already heavily optimized by V8)
- Python: dict dispatch

**Key insight**: Hash dispatch validates the theoretical break-even point at ~10 ns. For caching to be beneficial, dispatch must be SLOWER than ~10 µs (10,000 ns)—but no production language implements dispatch that slowly.

---

## Summary Table: Mechanisms by Complexity and Failure Severity

| Mechanism | Baseline | Overhead % | Failure | Common? |
|-----------|----------|-----------|---------|---------|
| Generic Function | 2.5 ns | ~600% | 27.21× | Moderate (predicates) |
| Single-Argument | 1.6 ns | ~1000% | 11.49× | **Very high** (all OO) |
| Property-Based | 1.3 ns | ~1200% | 15.63× | High (protocols/traits) |
| Multi-Argument | 95.6 ns | ~15% | 1.15× | Moderate (multimethods) |
| Hash Dispatch | 9.0 ns | ~5% | 0.95× | Moderate (scripting) |

**Pattern**: Overhead is ~constant (14-20 ns); failure ratio inversely proportional to baseline cost.

---

## What This Teaches Language Implementers

### For implementers considering object-level caching:

1. **Don't do it.** Object-level caching adds 14-20 ns overhead that cannot be reduced (determined by CPU physics: atomic operations, memory access, pipeline stalls).

2. **If you must optimize dispatch**:
   - Use machine-code inline caching (JIT-based) instead
   - V8, PyPy, GraalVM all use this approach successfully
   - Object-level caching cannot compete

3. **For interpreted languages** (no JIT): 
   - Optimize dispatch compilation (make baseline as fast as possible)
   - Don't try to cache dispatch at the object level
   - Better to specialize bytecode or use threaded code

4. **For expensive predicates** (>10 µs):
   - Object-level caching MIGHT help
   - But no language implements dispatch this slowly
   - If you have 10+ µs predicates, fix the predicates, not the dispatch

---

## Distinction from Related Work

### What we DON'T study:

1. **Method lookup caching** (CLOS metaclass cache, vtable cache)
   - Already ubiquitous and effective
   - Different problem: caching which method to call (done once per class definition)
   - Not what we're testing

2. **Memoization** (caching function results)
   - Different problem: cache outputs, not dispatch decisions
   - Orthogonal to our findings

3. **Inline caching** (JIT-based)
   - Different mechanism: embedded in machine code
   - Already proven effective
   - Not what we're testing

### What we DO study:

**Object-level dispatch decision caching**: Storing (type-tuple → method) mappings in hash tables and looking them up on every call.

---

## For Readers

**If you're reading this paper because you want to know whether to implement object-level dispatch caching in your language:**

**Answer**: Don't. The overhead (14-20 ns) exceeds the benefit for any realistic dispatch cost. Use machine-code caching (JIT) instead.

**If you're reading this to understand the limits of different dispatch mechanisms:**

**Key insight**: Failure severity is inversely proportional to baseline cost. Single-argument dispatch (most common) fails worst (11.49×) because it's ultra-fast (1.6 ns) and 14 ns overhead dominates. Multi-argument dispatch (slower baseline, 95.6 ns) fails less (1.15×) because overhead is a smaller percentage.

**If you're implementing a language:**

1. For fast languages (compiled, JIT): Don't cache dispatch at object level
2. For slow languages (interpreted): Optimize dispatch compilation; don't cache
3. For very slow predicates (>10 µs): Caching might help, but fix predicates instead

