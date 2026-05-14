# FOL Schema Evolution: Edge Cases and Guarantees

**Date**: May 14, 2026  
**Status**: Production Ready

## Overview

FOL's lazy schema migration with alias chains provides declarative slot renaming and recovery, but the system has edge cases that developers should understand. This document specifies:

- Migration guarantees (what FOL commits to)
- Edge cases (what behavior to expect)
- Limitation boundaries (where manual intervention is needed)

## 1. Alias Chain Execution

### Circular Alias Prohibition

FOL prevents cycles in alias maps to ensure deterministic migration.

**Rule**: An alias cannot form a cycle.  
**Example (REJECTED)**:
```lisp
(defclass <point> []
  [[x] [y :alias x]])  ; Error: cycle detected (x -> y -> x)
```

**When Checked**: At `reinitialize-instance` time (first redefinition or post-redefinition mutation).  
**Error Type**: Runtime error via DFS cycle detection in the alias-map construction.  
**Migration Confluence Property**: Enforced at redefinition time; prevents cycles from being silently created.

### Multi-Hop Chain Replay

FOL composes alias maps across multiple redefinitions, allowing an old instance to be migrated through several schema versions in a single pass.

**Example**:
```lisp
;; Schema v0
(defclass <sensor> [] [[reading] [timestamp]])

;; Schema v1: rename reading -> val
(defclass <sensor> [] [[val :alias reading] [timestamp]])

;; Schema v2: rename timestamp -> ts
(defclass <sensor> [] [[val :alias reading] [ts :alias timestamp]])

;; Instance created at v0, accessed at v2
(let ((obj (make-<sensor> :reading 42 :timestamp 123)))
  ;; obj stored with :reading and :timestamp slots
  ;; At first access post-v2, chain replay:
  ;;   v0->v1: reading -> val
  ;;   v1->v2: timestamp -> ts
  ;;   Result: two rewrites in one pass
  (get obj :val))  ; Returns 42
```

**Guarantee**: All hops are composed in a single pass; intermediate versions are not created.  
**Cost**: $O(alias\_depth)$ rewrites, linearly bounded by the number of redefinitions.

### Multi-Level Alias Chains

Aliases can be chained transitively:
```lisp
(defclass <sensor> []
  [[current-val :alias val :alias reading]])
```

This creates a chain: `current-val -> val -> reading`.  
The system will follow the chain transitively, but this is **not recommended** for readability.

**Guarantee**: Transitive alias chains are resolved correctly (the full path is traversed).  
**Limitation**: Cycle detection applies to the full transitive closure, not just direct aliases.

## 2. Instance Versioning and Stale Instances

### Schema Version Stamping

Every instance carries a `%schema-version` stamp indicating which class version it was created with.

**How It Works**:
```
Instance created: v0 (reads/writes use v0 layout)
    ↓
Class redefined to v1: instance is dormant (v0 stamp in memory)
    ↓
Instance first touched post-v1: migration replay to v1 layout
    ↓
Class redefined to v2: instance is now at v1 (re-migrated on next touch)
```

**Guarantee**: The version counter is atomic; an instance's stamp cannot become out-of-sync with its actual data layout.

**Caveat**: After migration to v1, subsequent mutations occur in v1's layout. If the class redefines to v2, the instance is now "old" at v1 and must be re-migrated on next access.

### Forward Compatibility

**What if I delete an old schema version from my codebase?**

If a dormant instance was created at schema v0, the class has evolved to v1→v2→v3, and you delete v0's migration code, attempting to access that instance at v3 will **fail to migrate** because the replay logic requires the v0→v1 transformation definition.

**Workaround**: Never delete old migration code. Archive it in comments if necessary, or provide a clean-up phase that touches all dormant instances to migrate them forward before you delete old versions.

**Limitation**: FOL does not provide automatic garbage-collection of old schema definitions; you must maintain them.

## 3. Concurrent Redefinition and Migration

### Atomicity Guarantees

**Scenario**: Thread A accesses an instance while Thread B redefines the class.

**Behavior**:
1. Thread A: Acquires the instance lock for reading
2. Thread B: Calls `reinitialize-instance` (defines new class version, bumps version counter)
3. Thread A: Continues reading from the instance; may be at old layout
4. Thread A: Later mutation will trigger re-migration if needed

**Guarantee**: Instance data is never corrupted; mutation atomicity is maintained via `update-instance-for-redefined-class` hooks.

**Note**: Concurrent redefinition is safe but may cause a read to see a transitional state. Use explicit synchronization if you need to coordinate redefinition with readers.

## 4. Alias Map Semantics

### Partial Aliases

An alias is **optional**: if the source slot doesn't exist in an old instance, the alias is not applied.

**Example**:
```lisp
(defclass <point> [] [[x] [y]])
(let ((p (make-<point> :x 1 :y 2)))
  ;; Redefine with alias
  (defclass <point> [] [[x] [y :alias z]])  ; z was never in the old instance
  ;; Accessing :z returns nil (no migration needed; z didn't exist)
  (get p :z))  ; nil
```

**Guarantee**: Missing source slots in aliases do not cause errors; they silently resolve to nil.

### Bidirectional Alias Reads

Aliases work for **reads** (recovery of renamed slots). For **writes**, you must use the new slot name.

**Example**:
```lisp
(defclass <sensor> [] [[val :alias reading]])

(let ((s (make-<sensor> :reading 42)))
  (get s :reading)  ; OK: migrated to :val on first access
  (get s :val)      ; OK: reads directly from :val
  (assoc s :reading 100)  ; ERROR: :reading doesn't exist as a writable slot
  (assoc s :val 100))     ; OK: writes directly to :val
```

**Guarantee**: Old slot names are read-only (via alias recovery); new slot names are the canonical write targets.

## 5. Overflow Slot Evolution

If a class evolves such that the number of user-defined slots exceeds $T=26$ (after system overhead), the instance transitions from native-only to hybrid native/trie storage.

**Example**:
```lisp
(defclass <big-obj> []
  [[s1] [s2] ... [s26]])  ; Exactly T=26, fits in native slots

(defclass <big-obj> []
  [[s1] [s2] ... [s26] [s27]])  ; Now 27 > 26, requires trie overflow
```

**Behavior**: On first post-redefinition mutation, the instance allocates an overflow trie and reorganizes its slots.

**Guarantee**: Slot access latency changes (native ${\approx}10$\,ns → trie ${\approx}100-500$\,ns), but correctness is preserved.

**Implication**: Monitor slot counts if you're performance-sensitive; avoid adding many slots to high-traffic classes.

## 6. Testing and Validation

### How to Verify Migration Correctness

1. **Check version stamps**:
   ```lisp
   (let ((obj (make-<sensor> :reading 42)))
     (defclass <sensor> [] [[val :alias reading]])
     ;; obj is now at v0; accessing it triggers migration
     (get obj :val)  ; Migrates to v1
     ;; Both should return 42 (same data, migrated)
     (eq (get obj :val) 42))
   ```

2. **Check transitive aliases**:
   ```lisp
   (defclass <point> [] [[old-coord]))
   (defclass <point> [] [[coord :alias old-coord]))
   (defclass <point> [] [[new-coord :alias coord :alias old-coord]))
   ;; All three names should resolve to the same value
   ```

3. **Stress test with concurrent mutations**:
   ```lisp
   (with-threading
     (thread-1 (loop repeat 10000 do (assoc obj :field (random 100))))
     (thread-2 (loop repeat 10000 do (defclass <obj> [] [[field] [field2]]))))
   ```

## 7. Known Limitations

| Limitation | Workaround |
|-----------|-----------|
| Cannot track external dependencies (GC old schemas) | Maintain schema versions in comments; tag releases |
| Cannot rename slots while preserving write access | Use new slot name for writes; old name is read-only |
| Aliases don't apply to writes | Manually migrate at write time if needed |
| Cycle detection is O(alias_depth); deep chains are slow | Limit alias depth to <5 hops |
| Cannot rollback to old schema | Create new instances with desired schema version |

## 8. Future Work

1. **Automatic dead-schema cleanup**: Identify instances that have fully migrated past a version and archive old definitions
2. **Composite aliases**: Allow `(slot :alias [s1 s2 s3])` to combine multiple slots
3. **Conditional aliases**: Aliases that apply only if source slot exists (currently implicit)
4. **Reverse migration**: Tool to downgrade instances to earlier schema versions for export

---

## References

- `src/compiler.lisp` — Class definition compilation, alias-map building
- `src/oop.lisp` — `update-instance-for-redefined-class` hooks
- Table~2 in the ELS 2026 paper — MOP protocol adaptation
