# Collection Type Predicates

Collection type predicates return true if the argument is a FOL collection of the specified type, false otherwise.

## <collection>?

```
(<collection>? x)
```

Returns true if x is any FOL collection (vector, list, dict, set, bag, array, or lazy-seq).

### Examples

```fol
(<collection>? [1 2 3])           ; => true
(<collection>? {:a 1 :b 2})       ; => true
(<collection>? #{1 2 3})          ; => true
(<collection>? '(1 2 3))          ; => false (CL list, not FOL list)
(<collection>? 42)                ; => false
```

---

## <ordered-collection>?

```
(<ordered-collection>? x)
```

Returns true if x is an ordered collection (vector, list, array, or lazy-seq).

### Examples

```fol
(<ordered-collection>? [1 2 3])   ; => true
(<ordered-collection>? {:a 1})    ; => false (dict is unordered)
(<ordered-collection>? #{1 2 3})  ; => false (set is unordered)
```

---

## <unordered-collection>?

```
(<unordered-collection>? x)
```

Returns true if x is an unordered collection (dict, set, or bag).

### Examples

```fol
(<unordered-collection>? {:a 1})  ; => true
(<unordered-collection>? #{1 2})  ; => true
(<unordered-collection>? [1 2])   ; => false (vector is ordered)
```

---

## <vector>?

```
(<vector>? x)
```

Returns true if x is a FOL vector.

### Examples

```fol
(<vector>? [1 2 3])               ; => true
(<vector>? [])                    ; => true
(<vector>? '(1 2 3))              ; => false
(<vector>? {:a 1})                ; => false
```

---

## <list>?

```
(<list>? x)
```

Returns true if x is a FOL list (persistent linked list).

### Examples

```fol
(<list>? (make '<list> 1 2 3))    ; => true
(<list>? [1 2 3])                 ; => false (vector)
(<list>? '(1 2 3))                ; => false (CL list)
```

---

## <dict>?

```
(<dict>? x)
```

Returns true if x is a FOL dict (persistent hash map).

### Examples

```fol
(<dict>? {:a 1 :b 2})             ; => true
(<dict>? {})                      ; => true
(<dict>? [1 2 3])                 ; => false
```

---

## <set>?

```
(<set>? x)
```

Returns true if x is a FOL set (persistent hash set with unique elements).

### Examples

```fol
(<set>? #{1 2 3})                 ; => true
(<set>? #{})                      ; => true
(<set>? [1 2 3])                  ; => false
```

---

## <bag>?

```
(<bag>? x)
```

Returns true if x is a FOL bag (multiset that allows duplicate elements).

### Examples

```fol
(<bag>? (make '<bag> 1 1 2 2 3))  ; => true
(<bag>? #{1 2 3})                 ; => false (set)
```

---

## <array>?

```
(<array>? x)
```

Returns true if x is a FOL array (multi-dimensional array).

### Examples

```fol
(<array>? (make '<array> 3 3))    ; => true
(<array>? [1 2 3])                ; => false (vector)
```

---

## <lazy-seq>?

```
(<lazy-seq>? x)
```

Returns true if x is a FOL lazy sequence.

### Examples

```fol
(<lazy-seq>? (lazy-seq [1 2 3]))  ; => true
(<lazy-seq>? [1 2 3])             ; => false (vector)
```
