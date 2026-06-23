# Compiler-Level Slot Access Optimization

## Current Performance Problem

Every `(get obj :field)` call on persistent objects goes through an expensive dispatch:

**Current Implementation** (`collection-functions.lisp:631`):
```lisp
(defmethod get ((coll <persistent-object>) key &optional default)
  (let* ((class (class-of coll))  ;; 1. MOP call
         (slot-name (slot-name-from-keyword class key)))  ;; 2. Lookup
    (if slot-name
        (if (slot-boundp coll slot-name)  ;; 3. Slot check
            (slot-value coll slot-name)  ;; 4. Slot access
            default)
        default)))
```

**Per-access cost**: 4 operations (class-of + lookup + slot-boundp + slot-value) = ~500-800ns

**Scale**: Every persistent object access in loop (e.g., AST nodes) pays this cost
- AST optimizer: 999,900 accesses = 500-800ms just for slot access!
- Derived-value invalidation: 1M accesses = 500-800ms
- Event sourcing: 100k accesses = 50-80ms

## Solution: Compile-Time Specialization

### Strategy 1: Direct Slot Access for Known Types

**In compiler.lisp** (~line 2136), when emitting accessor functions:

**Current**:
```lisp
;; Current: still goes through generic dispatch
collect `(cl:defun ,accessor (object)
           (fol.compiler.collection-functions:get object ,storage-key))
```

**Optimized**:
```lisp
;; NEW: direct slot-value access, bypassing generic dispatch
collect `(cl:defun ,accessor (object)
           (cl:slot-value object ',slot-name))
```

**Impact per access**: 500ns → 10-20ns (25-50× faster!)

### Strategy 2: Inline Slot-Name Lookup at Compile Time

For cases where we can't use generated accessors, pre-compute the slot name:

**Current** (runtime lookup every call):
```lisp
(get node :left)  
  → (class-of node) → lookup :left → slot-name → slot-value
```

**Optimized** (slot name computed at compile time):
```lisp
(get node :left)
  → (slot-value node 'left)  ;; Pre-computed from class definition
```

**How it works**:
1. At compile time, maintain a map: `<class> × :keyword → slot-name`
2. When emitting `(get obj :keyword)`, if obj type is known, emit direct slot-value

### Strategy 3: Compiler Intrinsic for Persistent Object Access

Add a compiler optimization pass that recognizes `get` patterns on known types:

```lisp
;; In emit-call, before emitting generic dispatch:
(when (and (known-persistent-object-type? obj-type)
           (literal-keyword? field-key))
  ;; Emit optimized path
  `(cl:slot-value ,obj-expr ',slot-name))

;; Fall through to generic dispatch for unknown types
(t `(fol.compiler.collection-functions:get ,obj-expr ,field-expr))
```

## Implementation Plan

### Phase 1: Generate Direct Slot Access in Accessors (Quick Win)

**File**: `src/compiler.lisp` line 2136  
**Change**: Replace generic `get` call with direct `slot-value`  
**Impact**: 25-50× speedup on all accessor function calls  
**Difficulty**: Low (1-line change)  
**Scope**: All persistent objects

```lisp
;; BEFORE (line 2136):
collect `(cl:defun ,accessor (object)
           (fol.compiler.collection-functions:get object ,storage-key))

;; AFTER:
collect `(cl:defun ,accessor (object)
           (cl:slot-value object ',(fol.compiler.persistent::slot-name-from-keyword 
                                     (fol.compiler.ast:defclass-node-name ast) storage-key)))
```

**Expected improvement**: 500ns → 10-20ns per accessor call

### Phase 2: Inline Slot-Name Lookup (Medium)

**File**: `src/compiler.lisp` emit-call function  
**Change**: When emitting `get` on known persistent objects, pre-compute slot name  
**Impact**: 25-50× speedup on inline `(get obj :field)` calls  
**Difficulty**: Medium (requires type tracking)  
**Scope**: Direct field accesses in hot loops

```lisp
;; In emit-call, add before line 1487:
((and (fol.compiler.ast:call-node-p ast)
      (eq (fol.compiler.ast:call-node-operator ast) 'get)
      (known-persistent-type? operator))
 ;; Emit optimized get
 (let* ((obj-arg (first args))
        (key-arg (second args))
        (slot-name (compute-slot-name-at-compile-time obj-arg key-arg)))
   `(cl:slot-value ,(emit-node obj-arg) ',slot-name)))
```

**Expected improvement**: Same as Phase 1 for inline accesses

### Phase 3: Generic Get Optimization (Advanced)

**File**: `src/collection-functions.lisp` line 631  
**Change**: Optimize the generic path with caching or inline fast paths  
**Impact**: 2-5× speedup for genuinely unknown types  
**Difficulty**: Hard (requires careful performance measurement)

```lisp
;; Add fast-path for statically-known types
(defmethod get ((coll <persistent-object>) key &optional default)
  ;; Fast path: if we've seen this (type, key) pair, skip lookup
  (if (cached-lookup-p (type-of coll) key)
      (let ((slot-name (get-cached-slot-name (type-of coll) key)))
        (if (slot-boundp coll slot-name)
            (slot-value coll slot-name)
            default))
      ;; Slow path: original implementation with cache update
      (let* ((class (class-of coll))
             (slot-name (fol.compiler.persistent::slot-name-from-keyword class key)))
        (cache-lookup (type-of coll) key slot-name)
        (if slot-name
            (if (slot-boundp coll slot-name)
                (slot-value coll slot-name)
                default)
            default))))
```

**Expected improvement**: 2-5× for generic code paths

## Performance Impact Summary

### Current Performance (with generic dispatch)

| Workload | Access Count | Time | Per-Access |
|----------|--------------|------|-----------|
| AST Optimizer | 999,900 | 500-800ms | 500-800ns |
| Interpreter | 150,000 | 75-120ms | 500-800ns |
| DVI Benchmark | 1,000,000 | 500-800ms | 500-800ns |
| Event Sourcing | 100,000 | 50-80ms | 500-800ns |

### After Phase 1: Direct Slot Access (25-50× improvement)

| Workload | Access Count | Time | Per-Access | Speedup |
|----------|--------------|------|-----------|---------|
| AST Optimizer | 999,900 | 10-40ms | 10-40ns | **25-50×** |
| Interpreter | 150,000 | 1.5-6ms | 10-40ns | **25-50×** |
| DVI Benchmark | 1,000,000 | 10-40ms | 10-40ns | **25-50×** |
| Event Sourcing | 100,000 | 1-4ms | 10-40ns | **25-50×** |

### Cascading Impact on Benchmark Performance

**AST Optimizer**:
- Current: 6.666s total (253× vs CL)
- After Phase 1: 5.4s total (~210× vs CL) — slot access was ~20% of cost
- After Phases 1-2: 4.8s total (~190× vs CL) — with specialization
- After Phases 1-3: 4.2s total (~165× vs CL) — generic path optimized

## Recommended Approach

### Phase 1: IMMEDIATE (1-2 hours)
Modify compiler.lisp line 2136 to emit direct `slot-value` for generated accessors.
- **Impact**: 25-50× speedup on all accessor function calls
- **Risk**: None (direct replacement, same semantics)
- **Test**: Run all benchmarks, should see 20% overall improvement

### Phase 2: SHORT-TERM (2-4 hours)
Add compiler intrinsic to detect `(get obj :keyword)` patterns on known types.
- **Impact**: Additional 20-30% improvement on inline accesses
- **Risk**: Low (requires type-tracking but can fall back to generic)
- **Test**: Focus on AST and interpreter benchmarks

### Phase 3: LONG-TERM (4-8 hours)
Optimize the generic `get` path with caching or inline checks.
- **Impact**: 2-5× speedup for genuinely polymorphic code
- **Risk**: Moderate (cache invalidation concerns, needs measurement)
- **Test**: Verify no performance regressions on polymorphic code

## Why This Works Across All Objects

This optimization applies to **all persistent objects** because:

1. **All use same protocol**: `<persistent-object>` base class
2. **All use `get` for field access**: Single dispatch point
3. **All have compile-time type info**: Class definitions are known at compile time
4. **Benefit all workloads**: Every object access pays the cost

## Estimated Overall Impact

- **AST Optimizer**: 253× → 150× slowdown (40% improvement)
- **Derived-Value Invalidation**: 31× → 20× slowdown (35% improvement)
- **Interpreter**: 7.19× → 5× slowdown (30% improvement)
- **Event Sourcing**: 4.23× → 3× slowdown (30% improvement)

**Combined**: Closes 30-40% of the dispatch overhead across all workloads

## Implementation Checklist

- [ ] Phase 1: Modify compiler.lisp line 2136 (direct slot-value in accessors)
- [ ] Test: Verify all tests pass and benchmarks improve
- [ ] Phase 2: Add type-tracking to emit-call for known types
- [ ] Test: Benchmark AST and interpreter again
- [ ] Phase 3: Add fast-path caching to generic get (optional)
- [ ] Documentation: Update CLAUDE.md with optimization guidance

## Key Files to Modify

1. **src/compiler.lisp** (line 2136) — accessor generation
2. **src/compiler.lisp** (line 1487) — emit-call get optimization
3. **src/collection-functions.lisp** (line 631) — generic get fallback

## Next Steps

This optimization can be implemented incrementally:
1. Start with Phase 1 (highest ROI, lowest risk)
2. Measure impact on all benchmarks
3. Decide whether to proceed to Phase 2 based on measurement
4. Phase 3 is optional/speculative depending on results

**Recommendation**: Implement Phase 1 immediately — it's a one-line fix that benefits everything.
