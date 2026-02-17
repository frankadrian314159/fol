# Relational Functions

The `fol.compiler.relational` package provides Clojure-style relational algebra functions that operate on sets of maps. These functions are useful for manipulating data structures in a relational manner.

## Functions

### `join`
`(join xrel yrel)`
`(join xrel yrel km)`

Performs a natural join between two relations `xrel` and `yrel`. Returns a set of maps formed by merging elements from both relations that share common keys with the same values.
If `km` (a key map) is provided, it performs a join based on the aliases defined in `km`.

### `select`
`(select pred xset)`

Returns a set of the maps in `xset` for which `(pred map)` returns true. Similar to `filter` but ensures the result is a set.

### `project`
`(project xset keys)`

Returns a set of the maps in `xset` with only the specified `keys`. Equivalent to SQL `SELECT keys FROM xset`.

### `union`
`(union s1 s2)`

Returns the union of two sets `s1` and `s2`.

### `difference`
`(difference s1 s2)`

Returns a set containing elements from `s1` that are not present in `s2`.

### `intersection`
`(intersection s1 s2)`

Returns the intersection of two sets `s1` and `s2`.

### `index`
`(index xset keys)`

Returns a sorted map (`<sorted-dict>`) indexing the elements of `xset` by the values of the specified `keys`.
This uses `universal-compare` to ensure that dictionary keys are grouped by value, not identity.

### `rename`
`(rename xset kmap)`

Returns a set of the maps in `xset` with keys renamed according to the mapping `kmap`.
