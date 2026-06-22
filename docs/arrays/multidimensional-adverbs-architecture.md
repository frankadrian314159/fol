# Multi-Dimensional Adverbs: APL-Style Implementation Architecture

## Core Problem: Adverbs Need Axis Specification

In pure q (1D vectors only), adverbs are simple:
```q
+/ 1 2 3 4           / sum (fold from right) = 10
+\ 1 2 3 4           / cumulative sum = 1 3 6 10
f' (1 2 3; 4 5 6)    / apply f to each sublist
```

With multi-dimensional arrays, every aggregating adverb needs to specify **which axis/dimension** to operate on:

```apl
+/[0] matrix         / sum along axis 0 (collapse rows, keep columns)
+/[1] matrix         / sum along axis 1 (collapse columns, keep rows)
+/ matrix            / sum all elements (no axis = full reduction)
```

---

## Adverb Categories & Changes

### Category 1: Element-wise Operations (NO CHANGE)
These don't change with multi-dimensional arrays—they just broadcast across all elements.

| Operation | 1D Behavior | Multi-D Behavior | Change |
|-----------|-------------|------------------|--------|
| `+` (add) | `1 2 3 + 10` → `11 12 13` | `matrix + 10` → element-wise add | ✓ No change |
| `*` (multiply) | `2 * (1 2 3)` → `2 4 6` | `2 * matrix` → element-wise mul | ✓ No change |
| Broadcasting | Scalar broadcasts to list | Scalar broadcasts to all dims | ✓ No change |

**Implementation**: These work automatically; the storage is still flat `<vector>`, shape just affects indexing.

---

### Category 2: Reduction Adverbs (MAJOR CHANGE)

These fundamentally change behavior:

#### Fold/Over (`/`)
**1D q:**
```q
+/ 1 2 3 4                    / → 10 (single result)
```

**Multi-D APL:**
```apl
+/[0] (2 3 ⍴ 1..6)           / sum axis 0 → 3-element vector (row sums)
+/[1] (2 3 ⍴ 1..6)           / sum axis 1 → 2-element vector (column sums)
+/ (2 3 ⍴ 1..6)              / sum all → 21 (scalar)
```

**Implementation Impact:**
- Signature changes from `(function list) → scalar` to `(function array axis) → array`
- Must track input shape, output shape, intermediate results along axis
- Requires explicit axis parameter OR smart inference (default to last axis)

**Example signature in FOL:**
```lisp
(defun fold (fn array &optional (axis :last))
  "Fold FN along AXIS. 
   - axis = :last (default): reduce last dimension
   - axis = :all: reduce all dimensions (full fold)
   - axis = N: reduce specific axis N")
```

#### Scan (`\`)
**1D q:**
```q
+\ 1 2 3 4                    / → 1 3 6 10 (cumulative)
```

**Multi-D APL:**
```apl
+\[0] (2 3 ⍴ 1..6)           / cumulative sum along axis 0 → 2×3 array
+\[1] (2 3 ⍴ 1..6)           / cumulative sum along axis 1 → 2×3 array
```

**Implementation Impact:**
- Output shape = input shape (scan preserves dimensionality, unlike fold)
- Must iterate along axis, maintaining intermediate results
- More complex state tracking than fold

---

### Category 3: Each (`'`) - SUBTLE CHANGE

**1D q behavior** (applies to each element):
```q
f' (1 2 3)                    / apply f to 1, 2, 3
f' (1 2 3; 4 5 6)             / apply f to (1 2 3) and (4 5 6)
```

**Multi-D APL**: Must distinguish "rank" (how deep to apply):

```apl
f⍤0 matrix                    / apply f to each scalar (deepest)
f⍤1 matrix                    / apply f to each row
f⍤2 matrix                    / apply f to each 2D subarray
```

**Implementation Impact:**
- `Each` needs a **rank parameter** (default to last dimension?)
- Signature: `(function array rank) → array`
- Must partition array into sub-arrays at specified rank, apply function, reconstruct

**Example FOL signature:**
```lisp
(defun each (fn array &optional (rank :innermost))
  "Apply FN to each sub-array at RANK.
   rank = :innermost (default): apply to innermost elements
   rank = N: apply to N-dimensional sub-arrays")
```

---

### Category 4: Window/Scan Along Dimension (NEW COMPLEXITY)

**1D q:**
```q
(+/)': 2 (1 2 3 4 5)          / sliding windows of size 2, sum each
```

**Multi-D APL:**
```apl
(+/)': [0] 2 (3 4 ⍴ 1..12)    / sliding windows along axis 0, size 2
(+/)': [1] 2 (3 4 ⍴ 1..12)    / sliding windows along axis 1, size 2
```

**Implementation Impact:**
- Window adverb must specify:
  - Window size
  - Which axis to slide along
  - Stride (overlap or step)
- Output shape depends on input shape, window size, stride

---

### Category 5: Group By (SHAPE COMPLEXITY)

**1D q:**
```q
group 1 2 1 3 2               / → dict {1:(0 2), 2:(1 4), 3:(3)}
```

**Multi-D APL** (grouping by sub-arrays along an axis):
```apl
group[0] (2 4 ⍴ ...)          / group rows by equality
group[1] (2 4 ⍴ ...)          / group columns by equality
```

**Implementation Impact:**
- Group along an axis produces nested structure
- Output is a dict/hash mapping unique sub-arrays → indices
- May need to specify grouping depth (scalars vs vectors vs higher-rank)

---

## Implementation Strategy

### Level 1: Axis-Explicit Syntax (Clearest)
All adverbs take explicit axis parameter:

```lisp
(fold #'+ array :axis 0)           ; sum rows
(fold #'+ array :axis 1)           ; sum columns
(fold #'+ array :axis :all)        ; sum all
(scan #'+ array :axis 1)           ; cumulative sum along axis 1
(each #'sqrt array :rank 0)        ; apply sqrt to each element
```

**Pros**: Unambiguous, clear semantics  
**Cons**: Verbose, not as elegant as q

### Level 2: Smart Axis Inference (More q-like)
Default axis to last dimension; :all for full reduction:

```lisp
(fold #'+ array)                   ; defaults to :axis :last
(fold #'+ array :axis :all)        ; full reduction
(scan #'+ array)                   ; scan last dimension
```

**Pros**: More concise  
**Cons**: Implicit behavior, harder to debug

### Level 3: Rank-Based Each (APL-like)
Special `each` with rank operator:

```lisp
(each #'sqrt array 0)              ; rank 0 (scalars)
(each #'sum array 1)               ; rank 1 (vectors/rows)
(each #'matrix-mult array 2)       ; rank 2 (matrices)
```

**Pros**: Powerful, matches APL semantics  
**Cons**: Learning curve, more complex

---

## Data Structure Impact

### Shape Tracking Required

Current `<array>` already has `dimension` slot:
```lisp
(defclass <array> (<vector>)
    ((dimension :initarg :dimension
                :initform '(1)
                :reader array-dimension)))
```

With adverbs, **shape manipulation becomes critical**:

1. **Fold along axis 0** of shape `(3 4 5)`:
   - Input: `(3 4 5)` array
   - Output: `(4 5)` array (axis 0 collapsed)
   - Must update dimension slot

2. **Scan along axis 1** of shape `(3 4 5)`:
   - Input: `(3 4 5)` array  
   - Output: `(3 4 5)` array (shape preserved)
   - Dimension slot unchanged

3. **Each with rank 1** on shape `(3 4 5)`:
   - Input: `(3 4 5)` array
   - Output: Apply function to each `(4 5)` sub-array
   - Result depends on function's output shape

### Index Translation

Current `<array>` uses `%column-major-idx` for 2D:
```lisp
(%column-major-idx (array-dimensions coll) key)
```

With N-dimensional arrays, **generalize to N-D index translation**:
```lisp
(defun nd-index-to-flat (nd-indices shape)
  "Convert multi-dimensional index to flat position.
   (nd-index-to-flat '(1 2 3) '(4 5 6)) → position in flat storage")

(defun flat-to-nd-index (flat-pos shape)
  "Inverse: convert flat position back to multi-dimensional index.")
```

---

## Concrete Example: Sum Along Axis

### Current (1D):
```lisp
(fold #'+ #(1 2 3 4))
; → 10
```

### With Multi-D (Axis 0):
```lisp
(let ((arr (make <f64-array> 
              :dimension '(2 3)
              :storage (vector 1 2 3 4 5 6))))
  (fold #'+ arr :axis 0))
; Input shape: (2 3)
; Output shape: (3,)
; Result: (+ 1 4) (+ 2 5) (+ 3 6) = [5 7 9]
```

### Implementation Steps:
1. **Partition** input into "slices" along axis 0
   - Slice 0: [1 2 3]
   - Slice 1: [4 5 6]
2. **Fold** along orthogonal axes
   - Sum slice 0: 6
   - Sum slice 1: 15
3. **Collect** into output array with shape (3,)

---

## Challenges

### 1. Broadcasting Rules
Element-wise operations need NumPy-like broadcasting:
```lisp
(+ (array :shape (2 3 4))
   (array :shape (3 4)))       ; broadcast to (2 3 4)
```

### 2. Output Shape Inference
After applying an adverb, what's the output shape?
- Depends on input shape + operation + axis parameter
- Must validate before execution

### 3. Memory Layout
- Flat storage with multi-D indexing requires consistent layout (row-major vs column-major)
- All operations must agree on layout

### 4. Performance
- Striding along non-contiguous axes can destroy cache locality
- May need specialized implementations for common cases (e.g., sum axis 0 vs axis 1)

---

## Recommendation: Phased Implementation

### Phase 1: Element-wise + Full Reduction
- Implement basic adverbs without axis parameter
- Fold/scan only support full reduction (`:axis :all`)
- Each only applies to innermost elements

```lisp
(fold #'+ array)               ; sum all → scalar
(each #'sqrt array)            ; apply to each element → same shape
```

### Phase 2: Single-Axis Operations
- Add explicit axis parameter
- Fold/scan support axis specification
- Each gets rank operator

```lisp
(fold #'+ array :axis 0)       ; sum along axis 0
(each #'+ array :rank 1)       ; apply to each 1D sub-array
```

### Phase 3: Advanced Operations
- Multi-axis operations
- Complex broadcasting
- Optimized implementations for common patterns

---

## Modified Adverb Reference

See [q-functions-adverbs-reference.md](q-functions-adverbs-reference.md) for original q-style adverbs.

**Updated for multi-D:**

| Adverb | 1D Signature | Multi-D Signature | Example |
|--------|--------------|-------------------|---------|
| Fold | `(fn, list)` | `(fn, array, axis)` | `(fold + matrix :axis 0)` |
| Scan | `(fn, list)` | `(fn, array, axis)` | `(scan + matrix :axis 1)` |
| Each | `(fn, list)` | `(fn, array, rank)` | `(each sqrt matrix :rank 0)` |
| Window | `(size, fn, list)` | `(size, fn, array, axis)` | `(window 2 + matrix :axis 0)` |
| Group | `(list)` | `(array, axis)` | `(group matrix :axis 0)` |

