# Dispatch Caching Implementation Status

## Completed (Phase 1 + Core Phase 2)

### ✅ Dispatch Cache Infrastructure (`src/dispatch.lisp`)
- Ring-buffer dispatch cache structure (8 slots)
- `cache-lookup` and `cache-insert!` operations
- `cache-flush!` for invalidation with generation tracking
- MOP hooks for automatic flushing:
  - `add-method :after` hook
  - `remove-method :after` hook  
  - `finalize-inheritance :after` hook
- GF registry (`*gf-cache-registry*`) for coordinated cache management
- `pred-key` helper for value-based cache keys (fixnum/char/symbol self-key, others class-of)

### ✅ Dispatch Caching Helpers in compiler.lisp
- `+dispatch-cache-threshold+`: Constant (4) for minimum clause count
- `*fol-type-predicates*`: Whitelist of FOL type predicates
- `type-dispatch-cond-p`: Detects pure type-dispatch COND forms
- `predicate-dispatch-cond-p`: Detects value-predicate COND by clause count
- `value-key-expr`: Generates cache key expressions using `pred-key`
- `cacheable-defn-p`: Returns :type/:value/nil for cache mode decision
- `make-cached-defn`: Transforms named defn into cached dispatcher
- `make-cached-fn`: Transforms unnamed lambda into cached closure

### ✅ Caching Applied to Named defn (`emit-defn`)
- Automatically applies dispatch caching to multi-clause defns
- Hoists clause helpers and cache defparameter to top level
- Preserves metadata assignment logic

### ✅ Caching Applied to Anonymous fn (`emit-fn`)  
- Unnamed multi-clause fns with fixed arity use caching
- Hoists helpers and cache defvar via progn form
- Direct lambda return without labels wrapping

### ✅ Debug Cleanup
- Removed debug format statements from `emit-defmethod`

## Not Yet Implemented (Phase 2 Extensions)

### ❌ Method Caching (`defmethod`)
**Status**: Planned infrastructure in place, integration incomplete
**Blocker**: Complex paren management when wrapping CLOS defmethod forms

**Required:**
- `cacheable-method-p`: Detect cacheable multi-clause defmethods
- `make-cached-method`: Transform defmethod COND body into cached dispatcher
- `*method-cache-counter*`: Unique cache var naming
- `emit-defmethod` wiring: Apply caching to multi-clause defmethods
- Testing: Verify method redefinition invalidates caches

**Considerations:**
- Method qualifiers (`:around`, `:before`, `:after`) complicate the structure
- Cache registration with GF registry needed for MOP invalidation
- Lambda-list manipulation for CLOS compatibility

### ❌ Defgeneric Multi-Pattern Caching  
**Status**: No implementation attempted
**Reason**: Requires compound (arity . types) keys and complex dispatcher generation

**Required:**
- Gate: Check if enough distinct (arity, specializer) patterns exist
- Compound cache key: `(cons (length args) (mapcar #'class-of args))`
- Dispatcher modification: Insert cache lookups before case/cond dispatch
- Per-pattern cache insertion on miss

### ❌ Value-Predicate Reference-Type Handling
**Status**: Partially designed, not implemented
**Gap**: No explicit handling for value predicates on same reference type

**Examples needing fixes:**
```lisp
(defn compare-refs
  ([x obj1] "A")
  ([x obj2] "B"))
; If obj1 and obj2 are same class, cache would conflict
; Current behavior: safe (misses fall through to COND), not optimized
```

## Testing & Verification

### ✅ Compiler Loading
- System loads successfully with all Phase 1 code
- No syntax errors in dispatch infrastructure

### ⚠️ Test Suite Status
- Pre-existing TYPE-ERROR in test suite (persistence.lisp SBCL issue)
- Cannot fully verify all 2898 tests due to unrelated infrastructure issue
- defn and fn caching successfully demonstrated in earlier runs

## Recommendations for Completing Phase 2

### For defmethod Caching (Priority 1)
1. **Simplest approach**: Don't modify `emit-defmethod`, just ensure it compiles
2. **Medium approach**: Cache only non-:around methods (simpler COND structure)
3. **Full approach**: Handle all qualifiers with proper cache registration

### For defgeneric Caching (Priority 2)
1. **Simple gate**: Only cache if 4+ distinct patterns
2. **Key strategy**: Compound key as (length args . class-tuple)
3. **Fallback**: Non-cached dispatcher if compound keys aren't supported

### For Value-Predicate Safety (Priority 3)
1. Detect reference-type value predicates explicitly
2. Either: Skip caching for mixed value+type predicates
3. Or: Use EQL-based fallback when same-class conflicts detected

## Architecture Notes

**Correctness Guarantees:**
- Type-dispatch caching: Safe (class-of key is injective per type)
- Value-predicate caching on eql-comparable: Safe (value is its own key)
- Value-predicate caching on reference types: Safe but non-optimized (misses are harmless)

**Invalidation Model:**
- `defn` redefinition: Handled via `defparameter` re-eval  
- `defmethod` addition/removal: Hooked via MOP
- Class hierarchy changes: Handled via `finalize-inheritance` hook
- Anonymous fn: Fresh cache per closure instance

**Performance Expectations:**
- Cache lookup: ~15ns (8-slot ring buffer with EQ comparison)
- Break-even: 4-6 clauses depending on clause check overhead
- Estimated speedup: 1.0-1.5× at 6 clauses, 1.5-2.0× at 8+

## Files Modified

- ✅ `src/dispatch.lisp` - Created (dispatch cache infrastructure)
- ✅ `src/compiler.lisp` - Modified (helpers + emit-fn/emit-defn integration)
- ✅ `src/fol-compiler.asd` - Modified (dispatch.lisp dependency)
- ✅ `src/package.lisp` - Modified (fol.compiler.dispatch package exports)
- ✅ Cleanup: Removed debug statements from emit-defmethod

## Next Steps

1. Decide on defmethod caching approach (simple vs. full)
2. Implement `cacheable-method-p` and `make-cached-method` carefully with paren-balanced code
3. Test method redefinition invalidation scenarios  
4. Add defgeneric multi-pattern caching (optional optimization)
5. Document cache hit rates in practice via instrumentation
