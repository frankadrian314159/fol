# FOL Array Layout: Column-Major (Fortran/APL Style)

**Status**: VERIFIED ✅ in `src/collection-primitives.lisp:20-32`  
**Convention**: Follows APL, Q, Julia, Fortran (NOT NumPy/C)

---

## Overview

FOL arrays use **column-major** (also called "Fortran order" or "column-minor") memory layout:

- **Leftmost index varies fastest**
- Array shape `(d0, d1, d2, ...)` stored in memory with `i0` incrementing most frequently
- Used by: APL, Q, Julia, Fortran, MATLAB (default)
- NOT used by: C/C++, NumPy (default), Java arrays

---

## The Formula

For array with shape `(d0, d1, d2, ..., dn)` and indices `(i0, i1, i2, ..., in)`:

```
flat_index = i0 + i1*d0 + i2*d0*d1 + i3*d0*d1*d2 + ... + in*d0*d1*...*d(n-1)
```

Stride for axis `k`:
```
stride[k] = d0 * d1 * ... * d(k-1)  (product of all dimensions before k)
```

---

## Example: 3×4 Matrix

### Layout in Memory

```
Array shape: (3, 4)  [3 rows, 4 columns]

Conceptual 2D array:
    col0  col1  col2  col3
row0  a     e     i     m
row1  b     f     j     n
row2  c     g     k     o

Column-major memory layout (FOL):
[a, b, c, e, f, g, i, j, k, m, n, o]
 0  1  2  3  4  5  6  7  8  9  10 11
```

### Index Calculations

Using formula: `flat_index = i0 + i1*d0` where `d0=3`

| Row | Col | Indices (row, col) | Calculation | Flat Index | Element |
|-----|-----|-------------|-----------|-----------|---------|
| 0 | 0 | (0, 0) | 0 + 0*3 = 0 | 0 | a |
| 1 | 0 | (1, 0) | 1 + 0*3 = 1 | 1 | b |
| 2 | 0 | (2, 0) | 2 + 0*3 = 2 | 2 | c |
| 0 | 1 | (0, 1) | 0 + 1*3 = 3 | 3 | e |
| 1 | 1 | (1, 1) | 1 + 1*3 = 4 | 4 | f |
| 2 | 1 | (2, 1) | 2 + 1*3 = 5 | 5 | g |
| 0 | 2 | (0, 2) | 0 + 2*3 = 6 | 6 | i |
| 1 | 2 | (1, 2) | 1 + 2*3 = 7 | 7 | j |
| 2 | 2 | (2, 2) | 2 + 2*3 = 8 | 8 | k |
| 0 | 3 | (0, 3) | 0 + 3*3 = 9 | 9 | m |
| 1 | 3 | (1, 3) | 1 + 3*3 = 10 | 10 | n |
| 2 | 3 | (2, 3) | 2 + 3*3 = 11 | 11 | o |

### Memory Stride Pattern

```
Element (row, col) → memory offset:

  Column 0: offset 0, 1, 2 (stride 1)
  Column 1: offset 3, 4, 5 (stride 1)
  Column 2: offset 6, 7, 8 (stride 1)
  Column 3: offset 9, 10, 11 (stride 1)

Reading column 0: addresses 0, 1, 2 (contiguous!)
Reading row 0: addresses 0, 3, 6, 9 (stride 3)
```

---

## Example: 3×4×5 Tensor

Shape: `(3, 4, 5)` → 60 elements

Strides:
- Stride for dimension 0: 1
- Stride for dimension 1: 3 (= 3)
- Stride for dimension 2: 12 (= 3 × 4)

Index `(i0, i1, i2)` maps to flat position:
```
flat_index = i0 + i1*3 + i2*12
```

Examples:
- `(0, 0, 0)` → 0
- `(1, 0, 0)` → 1
- `(2, 0, 0)` → 2
- `(0, 1, 0)` → 3
- `(0, 0, 1)` → 12
- `(1, 2, 3)` → 1 + 2*3 + 3*12 = 1 + 6 + 36 = 43

---

## Implication: Performance Characteristics

### Fast Operations (Contiguous Memory)

1. **Iterating along axis 0** — walks through memory sequentially
   ```lisp
   ;; Iterate down column 0: (0,0) → (1,0) → (2,0)
   ;; Addresses: 0 → 1 → 2 (stride 1, contiguous)
   ```

2. **Reducing along axis 0** (e.g., sum rows) — contiguous reads
   ```lisp
   ;; Sum down each column: highly cache-friendly
   (fold #'+ arr :axis 0)  ;; Fast!
   ```

3. **Slicing along axis 0** — sub-arrays are contiguous
   ```lisp
   ;; Extract rows 0-2 (all columns): contiguous block
   (slice arr (0 2) (0 3))  ;; Address range: 0-5, 6-11, ...
   ```

### Slower Operations (Non-Contiguous)

1. **Iterating along axis n** — jumps through memory
   ```lisp
   ;; Iterate across row 0: (0,0) → (0,1) → (0,2)
   ;; Addresses: 0 → 3 → 6 → 9 (stride 3, non-contiguous)
   ```

2. **Reducing along axis 1** (e.g., sum columns) — scattered memory access
   ```lisp
   (fold #'+ arr :axis 1)  ;; Slower (cache misses)
   ```

3. **Transpose** — metadata only! (shape swap)
   ```lisp
   ;; Transpose (3,4) to (4,3): just swap dimensions!
   ;; No data movement needed (until later indexing)
   (transpose arr)  ;; O(1), not O(n)
   ```

---

## Comparison: Row-Major (C/NumPy)

**Row-major layout** (for reference; FOL does NOT use this):

```
Array shape: (3, 4)

Row-major memory layout (C):
[a, e, i, m, b, f, j, n, c, g, k, o]
 0  1  2  3  4  5  6  7  8  9 10 11

Formula: flat_index = i0*d1 + i1
         (rightmost index varies fastest)

Contiguous reads: rows (fast)
Scattered reads: columns (slow)
```

---

## Verification: Current FOL Implementation

**File**: `src/collection-primitives.lisp:20-32`

```lisp
(defun %column-major-idx (dimensions indices)
  "Computes a linear index into a vector from array dimensions and indices.
   Uses column-major indexing: index = i0 + i1*d0 + i2*d0*d1 + ..."
  (declare (optimize (speed 3) (safety 0)))
  (let ((idx 0)
        (stride 1))
    (loop for i fixnum from 0 below (length indices)
          for dim fixnum = (aref dimensions i)
          for index fixnum = (aref indices i)
          do (progn
              (incf idx (* index stride))
              (setf stride (* stride dim))))
    idx))
```

**Status**: ✅ CORRECT column-major implementation

---

## Array Constructor Usage (FOL)

### Creating a 3×4 array

```lisp
(make-instance '<array>
  :dimension '(3 4)
  :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
            '(a b c e f g i j k m n o)))
```

**Memory layout**: Column-major
- Element (0,0) = a → flat[0]
- Element (1,0) = b → flat[1]
- Element (2,0) = c → flat[2]
- Element (0,1) = e → flat[3]
- ...and so on

### Accessing element (row, col)

```lisp
(let* ((dims (vector 3 4))
       (indices (vector row col))
       (flat-pos (fol.compiler.collection-primitives::%column-major-idx dims indices)))
  (aref storage flat-pos))
```

---

## Guidelines for Implementing Array Functions

### Do's ✅

1. **Always use `%column-major-idx`** for converting ND indices to flat positions
2. **Use `linearize-shape`** to precompute strides before looping
3. **Iterate axis 0 contiguously** when you want cache-friendly code
4. **Make transpose free** (just swap shape metadata, don't copy data)
5. **Document axis semantics** in docstrings (e.g., "axis 0 = iterate columns")

### Don'ts ❌

1. **Don't use row-major indexing** — will break array semantics
2. **Don't physically transpose** unless absolutely necessary
3. **Don't assume row iteration is contiguous** — it's not in column-major
4. **Don't ignore the stride pattern** when optimizing
5. **Don't mix up "column" and "row"** terminology — be explicit about which axis

---

## Testing Column-Major Semantics

### Test Pattern: Verify Index Calculation

```lisp
(deftest test-column-major-3x4
  "Verify column-major indexing for 3×4 array"
  (let ((shape (vector 3 4)))
    ;; Test (0,0) → 0
    (is (= 0 (%column-major-idx shape (vector 0 0))))
    ;; Test (2,0) → 2
    (is (= 2 (%column-major-idx shape (vector 2 0))))
    ;; Test (0,1) → 3
    (is (= 3 (%column-major-idx shape (vector 0 1))))
    ;; Test (2,3) → 11
    (is (= 11 (%column-major-idx shape (vector 2 3))))
    ))
```

### Test Pattern: Verify Axis Slicing

```lisp
(deftest test-fold-axis-0
  "Verify fold along axis 0 uses contiguous memory (column-major)"
  (let ((arr (make-instance '<f64-array>
               :dimension '(3 4)
               :storage ...)))
    ;; Fold along axis 0 → sum each column
    ;; Should be fast (contiguous memory reads)
    (let ((result (fold #'+ arr :axis 0)))
      (is (equal (array-dimension result) '(4)))  ;; 4 columns
      ;; Verify sums are correct
      )))
```

---

## Migration Guide (If Needed)

If in future FOL switches to row-major:

1. **Change `%column-major-idx`** to use row-major formula: `i0*d1*d2*... + i1*d2*... + ...`
2. **Update all docstrings** and axis documentation
3. **Reverse all axis semantics** (axis 0 = rows, axis n-1 = columns)
4. **Reorder all test expectations**
5. **Expect significant performance regression** for traditional APL-style operations

---

## References

- APL Semantics: https://en.wikipedia.org/wiki/APL_(programming_language)#Multidimensional_arrays
- Q Language: https://kx.com/developers/documentation/
- Fortran Array Layout: https://en.wikipedia.org/wiki/Row-_and_column-major_order
- Julia Arrays: https://docs.julialang.org/en/v1/arrays/arrays/

