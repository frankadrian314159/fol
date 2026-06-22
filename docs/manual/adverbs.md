# Adverbs (Phase 2: Axis-Aware Operations)

Adverbs are higher-order operations that modify the behavior of functions on vectors and arrays. Phase 2 adverbs are axis-aware operations for reducing, scanning, and transforming multi-dimensional data.

## Overview

Adverbs operate on vectors and 2D arrays with axis-aware semantics. Most adverbs accept an `:axis` keyword argument (default: `0`) to specify which dimension to operate along.

### Axis Convention

- **Axis 0**: Vertical (rows) - operates along columns
- **Axis 1**: Horizontal (columns) - operates along rows
- **Column-major layout**: FOL arrays use column-major indexing (like Q and APL)

---

## Reduction Adverbs

Reduction adverbs collapse a dimension by combining elements along an axis.

### fold

```
(fold fn arr &key (axis 0))
```

Reduce array along specified axis using binary function.

- **Axis 0**: Reduce rows, return vector of column results
- **Axis 1**: Reduce columns, return vector of row results

The fold operation combines successive elements left-to-right along the chosen axis.

### Arguments

- `fn` - Binary reduction function (e.g., `#'+`, `#'*`)
- `arr` - Input vector or 2D array
- `axis` - Axis to reduce along (0 or 1, default: 0)

### Examples

```fol
; 1D vector: returns scalar
(fold #'+ [1 2 3])                  ; => 6 (sum all elements)
(fold #'* [1 2 3 4])                ; => 24

; 2D array with axis 0 (reduce rows):
; [[1 2 3]
;  [4 5 6]]
(fold #'+ [[1 2 3] [4 5 6]] :axis 0)
                                    ; => [5 7 9]

; 2D array with axis 1 (reduce columns):
(fold #'+ [[1 2 3] [4 5 6]] :axis 1)
                                    ; => [6 15]

; With multiplication:
(fold #'* [[1 2 3] [4 5 6]] :axis 0)
                                    ; => [4 10 18]
```

---

## Scan Adverbs

Scan adverbs compute running cumulative results along an axis.

### scan

```
(scan fn arr &key (axis 0))
```

Running reduction (cumulative application) of binary function along axis.

- **Axis 0**: Cumulative reduction down rows
- **Axis 1**: Cumulative reduction across columns
- Returns same shape as input, with cumulative results

### Arguments

- `fn` - Binary function to apply cumulatively
- `arr` - Input vector or 2D array
- `axis` - Axis to scan along (0 or 1, default: 0)

### Examples

```fol
; 1D vector: running totals
(scan #'+ [1 2 3 4])                ; => [1 3 6 10]

; 2D array with axis 0:
(scan #'+ [[1 2 3] [4 5 6]] :axis 0)
                                    ; => [[1 2 3]
                                    ;     [5 7 9]]

; 2D array with axis 1:
(scan #'+ [[1 2 3] [4 5 6]] :axis 1)
                                    ; => [[1 3 6]
                                    ;     [4 9 15]]

; Running products:
(scan #'* [1 2 3 4])                ; => [1 2 6 24]
```

---

## Iterator Adverbs

Iterator adverbs apply functions over vector elements.

### each

```
(each fn arr &key (axis 0))
```

Apply function to each element (or slice along axis).

### Arguments

- `fn` - Function to apply to each element
- `arr` - Input vector or 2D array
- `axis` - Axis to iterate along

### Examples

```fol
; Apply function to each element:
(each #'(lambda (x) (* x 2)) [1 2 3])
                                    ; => [2 4 6]

; On 2D array (axis 0: each row):
(each #'sum [[1 2 3] [4 5 6]])      ; => [6 15]

; With axis 1 (each column):
(each #'sum [[1 2 3] [4 5 6]] :axis 1)
                                    ; => [5 7 9]
```

---

### window

```
(window fn size arr &key (axis 0))
```

Apply function to sliding windows of specified size along axis.

### Arguments

- `fn` - Function to apply to each window
- `size` - Window size (number of consecutive elements)
- `arr` - Input vector or 2D array
- `axis` - Axis to slide along

### Examples

```fol
; Sliding sum over windows of size 2:
(window #'+ 2 [1 2 3 4 5])
                                    ; => [3 5 7 9] (1+2, 2+3, 3+4, 4+5)

; On 2D array:
(window #'+ 2 [[1 2 3] [4 5 6]] :axis 0)
                                    ; => [[5 7 9]] (single window per column)
```

---

### group-by

```
(group-by fn arr &key (axis 0))
```

Group elements by result of applying function, returning vector of groups.

### Arguments

- `fn` - Predicate or grouping function
- `arr` - Input vector
- `axis` - Axis to group along

### Examples

```fol
; Group numbers by parity:
(group-by #'even? [1 2 3 4 5 6])
                                    ; => [[2 4 6] [1 3 5]]

; Group by modulo:
(group-by #'(lambda (x) (mod x 3)) [1 2 3 4 5 6])
                                    ; => [[3 6] [1 4] [2 5]]
```

---

## Statistical Functions

Statistical operations compute summary statistics along axes.

### sum

```
(sum arr &key (axis 0))
```

Sum elements along axis.

### Arguments

- `arr` - Input vector or 2D array
- `axis` - Axis to sum along

### Examples

```fol
; Sum all elements:
(sum [1 2 3 4 5])                   ; => 15

; Sum along axis 0 (down rows):
(sum [[1 2 3] [4 5 6]] :axis 0)     ; => [5 7 9]

; Sum along axis 1 (across columns):
(sum [[1 2 3] [4 5 6]] :axis 1)     ; => [6 15]
```

---

### mean

```
(mean arr &key (axis 0))
```

Compute mean (average) along axis.

### Examples

```fol
; Mean of vector:
(mean [1 2 3 4 5])                  ; => 3.0

; Mean along axis 0:
(mean [[1 2 3] [4 5 6]] :axis 0)    ; => [2.5 3.5 4.5]

; Mean along axis 1:
(mean [[1 2 3] [4 5 6]] :axis 1)    ; => [2.0 5.0]
```

---

### variance

```
(variance arr &key (axis 0))
```

Compute statistical variance along axis.

### Arguments

- `arr` - Input vector or 2D array
- `axis` - Axis to compute variance along

### Examples

```fol
; Variance of symmetric data:
(variance [1 2 3 4 5])              ; => 2.0

; Variance along axis 0:
(variance [[1 1 1] [5 5 5]])        ; => [4.0 4.0 4.0]
```

---

### std-dev

```
(std-dev arr &key (axis 0))
```

Compute standard deviation (square root of variance) along axis.

### Examples

```fol
; Standard deviation:
(std-dev [1 2 3 4 5])               ; => 1.414... (sqrt of 2.0)

; Std-dev along axis 0:
(std-dev [[1 1 1] [5 5 5]] :axis 0)
                                    ; => [2.0 2.0 2.0]
```

---

## Transformation Adverbs

Transformations reshape or reorder array data.

### array-reverse

```
(reverse arr &key (axis 0))
(my-reverse arr &key (axis 0))
```

Reverse elements along axis.

### Examples

```fol
(reverse [1 2 3 4])                 ; => [4 3 2 1]

; Reverse along axis 0 (flip rows):
(reverse [[1 2 3] [4 5 6]] :axis 0)
                                    ; => [[4 5 6] [1 2 3]]

; Reverse along axis 1 (flip columns):
(reverse [[1 2 3] [4 5 6]] :axis 1)
                                    ; => [[3 2 1] [6 5 4]]
```

---

## Mapping and Combining

### map-array

```
(map-array fn arr)
```

Alias for `mapv`: Apply function to each vector element.

### Examples

```fol
(map-array #'(lambda (x) (* x 2)) [1 2 3])
                                    ; => [2 4 6]

(map-array #'sqrt [1 4 9 16])       ; => [1.0 2.0 3.0 4.0]
```

---

### zip

```
(zip & arrays)
```

Transpose/interleave multiple vectors into a vector of tuples.

### Examples

```fol
(zip [1 2 3] [4 5 6])               ; => [[1 4] [2 5] [3 6]]

(zip [1 2] [3 4] [5 6])
                                    ; => [[1 3 5] [2 4 6]]

; Unzip (transpose back):
(transpose (zip [1 2 3] [4 5 6]))
                                    ; => [[1 2 3] [4 5 6]]
```

---

## Partitioning Adverbs

### array-partition

```
(array-partition n arr &key (axis 0))
```

Partition vector into chunks of size `n`.

### Examples

```fol
(partition 2 [1 2 3 4 5 6])         ; => [[1 2] [3 4] [5 6]]

(partition 3 [1 2 3 4 5 6 7 8 9])   ; => [[1 2 3] [4 5 6] [7 8 9]]
```

---

### array-take

```
(array-take n arr &key (axis 0))
```

Take first `n` elements along axis.

### Examples

```fol
(take 3 [1 2 3 4 5])                ; => [1 2 3]

; Take first 2 rows:
(take 2 [[1 2 3] [4 5 6] [7 8 9]])
                                    ; => [[1 2 3] [4 5 6]]
```

---

### array-drop

```
(array-drop n arr &key (axis 0))
```

Drop first `n` elements along axis.

### Examples

```fol
(drop 2 [1 2 3 4 5])                ; => [3 4 5]

; Drop first row:
(drop 1 [[1 2 3] [4 5 6] [7 8 9]])
                                    ; => [[4 5 6] [7 8 9]]
```

---

## Composition Patterns

Adverbs can be composed for complex array operations.

### Example: Column Means with Filtering

```fol
; Get means of columns where all values > 0
(let [arr [[1 2 3] [4 5 6]]]
  (map-array #'mean (filter #'(lambda (col) (every #'pos? col))
                             (transpose arr))))
```

### Example: Running Totals by Group

```fol
; Scan with grouping
(let [data [[1 2 3] [4 5 6] [7 8 9]]]
  (map-array #'(lambda (row) (scan #'+ row))
             data))
```

---

## Performance Characteristics

- **fold / scan**: O(n) for 1D, O(n*m) for 2D where n, m are dimension sizes
- **each / window**: O(n*k) where k is window size or function cost
- **sum / mean**: Optimized using CL:REDUCE with numeric kernels
- **zip**: O(n) for vectors of length n

---

## See Also

- [[array-operations.md]] - Phase 1: Generic operators (+, -, *, /, comparisons, etc.)
- [[sequences.md]] - Sequence operations (map, filter, reduce)
- [[collections.md]] - Collection predicates and constructors
