# Per-Generic-Function Versioning: Design & Implementation

**Date**: May 14, 2026  
**Motivation**: Fix closure-capture limitation from PL critique

---

## Problem Statement

Current implementation uses **global version counters** for dispatch caches:
- When ANY method is added anywhere, ALL caches are flushed
- This is overly conservative and defeats hybrid invalidation strategy
- Results in loss of cache benefit for unrelated functions

**Example of over-invalidation**:
```lisp
(defn process-int [x] (cond ...))          ; cache for process-int created
(defn process-str [x] (cond ...))          ; cache for process-str created
(defmethod custom-gf #(y) ...)              ; unrelated method added
;; Both process-int and process-str caches flushed, even though unrelated!
```

---

## Solution: Per-GF Version Tracking

Each generic function gets its own version counter. When a method is added to GF `foo`, only `foo`'s version increments.

### Changes Required

#### 1. Global GF Version Registry

```lisp
(defvar *gf-version-registry* (make-hash-table :test 'equal)
  "Maps generic-function-name (symbol) to version number (fixnum).
   Incremented when methods are added/removed for that GF.")
```

#### 2. Modified dispatch-cache struct

```lisp
(defstruct (dispatch-cache (:constructor make-dispatch-cache (gf-name)) (:copier nil))
  (gf-name    nil     :type symbol)            ; owning generic function
  (table      ...     :type hash-table)        ; caches
  (hits       0       :type (unsigned-byte 64))
  (misses     0       :type (unsigned-byte 64)))
```

Note: Remove global `generation` field (no longer needed).

#### 3. Per-GF Version Getter

```lisp
(defun get-gf-version (gf-name)
  "Retrieve current version for GF-NAME."
  (declare (type symbol gf-name))
  (or (gethash gf-name *gf-version-registry*) 0))

(defun increment-gf-version! (gf-name)
  "Increment version for GF-NAME (called on method add/remove)."
  (declare (type symbol gf-name))
  (setf (gethash gf-name *gf-version-registry*)
        (1+ (get-gf-version gf-name))))
```

#### 4. Modified Cache Key

Old strategy: `key = (class-of arg1 class-of arg2 ...)`

New strategy: `key = (gen . (class-of arg1 class-of arg2 ...))`

where `gen = (get-gf-version gf-name)`

```lisp
(defun make-cache-key (gf-name args)
  "Construct cache key including current GF version."
  (cons (get-gf-version gf-name) args))
```

#### 5. Invalidation Changes

**Old**:
```lisp
(defmethod cl:add-method :after ((gf cl:standard-generic-function) method)
  (flush-all-caches!))  ; global flush
```

**New**:
```lisp
(defmethod cl:add-method :after ((gf cl:standard-generic-function) method)
  ;; Increment version for THIS GF only
  (increment-gf-version! (closer-mop:generic-function-name gf)))
```

Cache misses automatically happen because:
- Old cache key: `(0 . args)` (gen=0, old version)
- Current version: `1` (just incremented)
- Lookup fails, cache miss → recompute

**No explicit flush needed** — just increment the version, and stale cache entries become unreachable.

---

## Benefits

| Aspect | Global Version | Per-GF Version |
|--------|-----------------|-----------------|
| **Invalidation scope** | All functions | Only affected functions |
| **Cache hits after unrelated method add** | Lost | Preserved |
| **Memory overhead** | None | O(num-gfs) hash-table entries |
| **Implementation complexity** | Low | Medium |
| **False negatives (unnecessary flushes)** | High | Zero |

---

## Implementation Plan

### Phase 1: Add Global Registry (non-breaking)

1. Add `*gf-version-registry*` variable
2. Add `get-gf-version` / `increment-gf-version!` functions
3. Leave `dispatch-cache` struct unchanged (keep global `generation` field)

### Phase 2: Integrate into Cache Keys (behavioral change)

1. Modify `make-cached-defn` to include version in key
2. Modify `cache-lookup` to pass version
3. Update `compile-fn-fixed-arity` to use versioned keys

### Phase 3: Remove Global Flushing

1. Remove `cache-flush!` for generation increment
2. Update MOP hooks to use `increment-gf-version!` only
3. Deprecate global `generation` field (leave for compatibility)

---

## Migration Path

**For existing code**:
- Default behavior remains safe (global flushing still works)
- Applications that need fine-grained invalidation can:
  1. Use per-GF versioning (Phase 2+)
  2. Or manually call `(increment-gf-version! 'my-gf)` after method changes
  3. Or restructure to avoid closure-capture patterns

**For new code**:
- Per-GF versioning is recommended
- Document in dispatch-caching-guidelines.md

---

## Benchmark Impact

Expected improvement in scenarios with:
- Multiple GFs modified independently
- Cache-heavy functions only indirectly related to GF changes

**Conservative estimate**: 5–10% additional cache retention in realistic multi-GF applications.

---

## Testing

New tests for per-GF versioning:

```lisp
(test per-gf-version-isolation
  "Adding method to GF A should NOT invalidate cache for GF B"
  (let ((cache-a (make-dispatch-cache 'gf-a))
        (cache-b (make-dispatch-cache 'gf-b)))
    ;; Populate both caches
    (populate-cache cache-a '((int . 1)))
    (populate-cache cache-b '((int . 2)))
    
    ;; Add method to GF A
    (increment-gf-version! 'gf-a)
    
    ;; Cache A entries now stale (version mismatch)
    ;; Cache B entries still valid (version unchanged)
    (is (cache-miss cache-a '(int)))
    (is (cache-hit cache-b '(int)))))
```

---

## Backward Compatibility

**No breaking changes** if implementation is done carefully:

1. Keep `dispatch-cache-generation` field (unused but present)
2. Keep `flush-all-caches!` function (no-op or deprecated)
3. New MOP hook behavior is transparent to callers
4. Cache keys with version are equal-comparable

---

## Future: Type-Hierarchy-Aware Versioning

Per-GF versioning solves method-addition invalidation, but class hierarchy changes still require global flush.

**Future enhancement**: Track version per type-hierarchy component:
- `*type-hierarchy-version*` incremented on `finalize-inheritance`
- Include in cache key: `(gf-gen . (type-gen . args))`
- Would further reduce false invalidations

Status: Not implemented yet; proposed for Phase 4.
