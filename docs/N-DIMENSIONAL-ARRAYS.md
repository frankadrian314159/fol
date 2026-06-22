# N-Dimensional Arrays Implementation Plan

## Overview

Extend FOL's array system from 1D/2D to support arbitrary dimensions while maintaining full backwards compatibility.

## Design Decisions

### Representation: Hybrid Approach
1. **Nested Vectors** (current): `[[[1 2] [3 4]] [[5 6] [7 8]]]`
   - Backwards compatible
   - Natural syntax
   - Slower indexing (nested lookups)
   
2. **`<array>` Class** (new)
   - Flat storage with shape metadata
   - Fast indexing via stride calculations
   - Memory efficient
   - Better performance for large arrays

### Indexing: Vector Index Notation
```lisp
; Single dimension
(get arr 0)                    ; => element at index 0
(get arr [0])                  ; => same as above

; Multi-dimensional
(get arr [0 1 2])              ; => element at indices (0,1,2)
(assoc arr [0 1 2] value)      ; => update element at (0,1,2)

; Still works: nested vector style
(get (get (get arr 0) 1) 2)    ; => same result, deprecated
```

### Backwards Compatibility
- All existing nested-vector operations continue working
- New `<array>` class is opt-in
- Conversion functions between formats
- Documentation warns about performance differences

## Implementation Phases

### Phase 1: Array Class & Indexing
**Files to create/modify:**
- `src/array-class.lisp` (NEW) - `<array>` class definition
- `src/array-index.lisp` (NEW) - Index calculations and access
- `src/array-functions.lisp` (MODIFY) - Extend `get`/`assoc` for vector indices
- `src/package.lisp` (MODIFY) - New exports

**Features:**
- `<array>` class with storage/shape/stride
- `make-array` constructor
- `array-of` for easy creation
- Extend `get` to accept `[i j k]` indices
- Extend `assoc` for multi-dimensional updates
- Helper functions for index→linear conversion

**Tests:**
- Array class creation
- Vector indexing (1D, 2D, 3D, 4D)
- Stride calculations
- Bounds checking

### Phase 2: Shape & Reshape Operations
**Files to modify:**
- `src/advanced-array-operations.lisp` (MODIFY)

**Features:**
- `shape` for n-D arrays
- `rank` for n-D arrays
- `reshape` for n-D arrays with validation
- `flatten` for n-D arrays
- `as-array` converter (nested → flat)
- `as-nested` converter (flat → nested)

**Tests:**
- Shape operations on 1D, 2D, 3D, 4D arrays
- Reshape with various dimension combinations
- Conversion between representations

### Phase 3: Axis Operations
**Files to modify:**
- `src/adverbs.lisp` (MODIFY)
- `src/advanced-array-operations.lisp` (MODIFY)

**Features:**
- Update axis operations to support any dimension
- `axis` parameter now accepts any valid axis (0 to rank-1)
- `sum-axis`, `mean-axis`, `max-axis`, `min-axis` for n-D
- `fold`, `scan` for any axis

**Tests:**
- Axis operations on 3D/4D arrays
- All combinations of axes for a given rank

### Phase 4: Transposition & Permutation
**Files to modify:**
- `src/advanced-array-operations.lisp` (MODIFY)

**Features:**
- Extend `transpose` to n-D arrays
- `permute` for arbitrary axis reordering
- `swap-axes` for two-axis swapping
- Support axis specification: `(transpose arr [2 0 1])`

**Tests:**
- Transpose on 3D/4D arrays
- All permutation combinations

### Phase 5: Slicing & Concatenation
**Files to modify:**
- `src/advanced-array-operations.lisp` (MODIFY)

**Features:**
- Multi-dimensional slicing: `(slice arr [0:2 1:3 :])`
- `concat-arrays` along any axis
- `stack`, `hstack`, `vstack` generalized
- Range syntax for slicing (`:` means all, `0:2` means 0 to 1)

**Tests:**
- Slicing on 3D/4D arrays
- Concatenation along various axes
- Mixed dimension concatenation

## Test Strategy

### Current Baseline
- Phase 1-2: 71 tests (array-functions)
- Phase 2: 50 tests (adverbs)
- Phase 3: 38 tests (advanced-array-operations)
- **Total: 159 tests (must maintain 100%)**

### New Tests
- Phase 1 n-D: ~40 tests (indexing, creation, conversion)
- Phase 2 n-D: ~30 tests (axis operations on 3D+)
- Phase 3 n-D: ~20 tests (slicing, concatenation on 3D+)
- Phase 4 n-D: ~20 tests (permutation variations)
- Phase 5 n-D: ~25 tests (advanced slicing patterns)
- **Target: 239 total tests (100% passing)**

## Performance Targets

### Array Class vs. Nested Vectors
- **Indexing**: 10× faster for 4D+ arrays
- **Memory**: 30% reduction for large arrays
- **Reshape**: Constant time (just change metadata)
- **Creation**: 2× faster using `make-array`

### Backwards Compatibility Cost
- No performance regression for existing nested-vector code
- Optional migration path to `<array>` class for hot paths

## API Examples

### Creation
```lisp
; Nested vectors (backwards compatible)
(def arr [[[1 2] [3 4]] [[5 6] [7 8]]])

; New array class (optional, performant)
(def arr (make-array [2 2 2] :initial-value 0))
(def arr (array-of 1 2 3 4 5 6 7 8 :shape [2 2 2]))
```

### Indexing
```lisp
; Single element
(get arr [0 1 1])                   ; => 4

; Slicing (if implemented)
(slice arr [[0 2] [1 3] :])         ; => 2×2×2 subarray

; Modification
(assoc arr [0 1 1] 99)              ; => new array with updated element
```

### Operations
```lisp
; Shape operations
(shape arr)                         ; => [2 2 2]
(reshape arr [4 2])                 ; => new 4×2 array

; Axis operations
(sum-axis arr 0)                    ; => sum along dimension 0
(mean-axis arr 1)                   ; => mean along dimension 1

; Transposition
(transpose arr [2 0 1])             ; => permute axes
```

## Compatibility Matrix

| Operation | 1D Vector | 2D Nested | 2D Array | 3D+ Nested | 3D+ Array |
|-----------|-----------|-----------|----------|------------|-----------|
| `get`     | ✓         | ✓         | ✓        | ✓          | ✓         |
| `assoc`   | ✓         | ✓         | ✓        | ✓          | ✓         |
| `shape`   | ✓         | ✓         | ✓        | ✓          | ✓         |
| `reshape` | ✓         | ✓         | ✓        | ✓          | ✓         |
| `sum-axis`| ✓         | ✓         | ✓        | ✓ (new)    | ✓         |
| `transpose` | -       | ✓         | ✓        | ✓ (new)    | ✓         |
| `slice`   | ✓         | ✓         | ✓        | ✓ (new)    | ✓         |

## Timeline & Milestones

- **Week 1**: Phases 1-2 (array class, indexing, shape ops)
- **Week 2**: Phases 3-4 (axis ops, transposition)
- **Week 3**: Phase 5 (slicing, concatenation)
- **Week 4**: Testing, documentation, performance tuning

## Risk Mitigation

1. **Compatibility Risk**: Keep nested vectors as primary; `<array>` opt-in
2. **Test Coverage**: Maintain 100% pass rate throughout
3. **Documentation**: Clear examples for both representations
4. **Migration Path**: Provide conversion tools between formats

## Documentation Updates

Files to update:
- `docs/manual/FOL-MANUAL.md` - Section 22 (Array Programming)
- `docs/manual/array-operations.md` - Add n-D section
- `docs/manual/adverbs.md` - Update axis parameter docs
- `docs/manual/collections.md` - Document `<array>` class
- Create `docs/manual/n-dimensional-arrays.md` - Comprehensive guide

---

**Status**: Planning Phase  
**Target Completion**: Post-Phase 3  
**Breaking Changes**: None (full backwards compatibility)
