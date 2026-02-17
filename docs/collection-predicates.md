# Collection Type Predicates

Collection type predicates return true if the argument is a FOL collection of the specified type, false otherwise.

## <collection>?                                                        *[function]*

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

## <ordered-collection>?                                                *[function]*

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

## <unordered-collection>?                                              *[function]*

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

## <vector>?                                                            *[function]*

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

## <list>?                                                              *[function]*

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

## <dict>?                                                              *[function]*

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

## <set>?                                                               *[function]*

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

## <bag>?                                                               *[function]*

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

## map-entry?                                                           *[function]*

```
(map-entry? x)
```

Returns true if x is a map entry. In FOL, dict entries from `collection-seq`
are cons pairs `(key . value)`, so this predicate tests for cons cells.

### Examples

```fol
(map-entry? (first (seq {:a 1})))  ; => true  (a dict entry)
(map-entry? (cons :a 1))           ; => true
(map-entry? [1 2])                 ; => false (vector)
(map-entry? 42)                    ; => false
(map-entry? nil)                   ; => false
```

---

## <array>?                                                             *[function]*

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

## <lazy-seq>?                                                          *[function]*

```
(<lazy-seq>? x)
```

Returns true if x is a FOL lazy sequence.

### Examples

```fol
(<lazy-seq>? (lazy-seq [1 2 3]))  ; => true
(<lazy-seq>? [1 2 3])             ; => false (vector)
```

---

## sequential?                                                         *[function]*

```
(sequential? x)
```

Returns true if x is a sequential collection: a list, vector, deque, or
lazy-seq (including subtypes such as array).

### Examples

```fol
(sequential? [1 2 3])             ; => true
(sequential? (list 1 2 3))        ; => true
(sequential? (deque 1 2 3))       ; => true
(sequential? {:a 1})              ; => false
(sequential? #{1 2 3})            ; => false
(sequential? 42)                  ; => false
```

---

## associative?                                                        *[function]*

```
(associative? x)
```

Returns true if x is an associative collection: a vector or dict (including
all subtypes such as array, ordered-dict, sorted-dict, int-dict, etc.).
Associative collections support key-based or index-based access via `get`
and update via `assoc`.

### Examples

```fol
(associative? [1 2 3])            ; => true
(associative? {:a 1 :b 2})        ; => true
(associative? (sorted-dict nil 1 :a))  ; => true
(associative? #{1 2 3})           ; => false
(associative? (list 1 2 3))       ; => false
```

---

## sorted?                                                             *[function]*

```
(sorted? x)
```

Returns true if x is a sorted collection: a sorted-dict or sorted-set
(including subtypes such as int-dict and int-set).

### Examples

```fol
(sorted? (sorted-dict nil :a 1))  ; => true
(sorted? (int-dict 1 :a 2 :b))   ; => true
(sorted? (sorted-set nil 1 2 3))  ; => true
(sorted? (int-set 1 2 3))         ; => true
(sorted? {:a 1})                  ; => false
(sorted? #{1 2 3})                ; => false
```

---

## counted?                                                            *[function]*

```
(counted? x)
```

Returns true if x is a counted collection (any subtype of `<collection>`).

### Examples

```fol
(counted? [1 2 3])                ; => true
(counted? {:a 1})                 ; => true
(counted? #{1 2 3})               ; => true
(counted? 42)                     ; => false
(counted? nil)                    ; => false
```

---

## reversible?                                                         *[function]*

```
(reversible? x)
```

Returns true if x is a reversible collection: a vector, sorted-dict, or
sorted-set (including subtypes such as array, int-dict, int-set).

### Examples

```fol
(reversible? [1 2 3])             ; => true
(reversible? (sorted-dict nil 1 :a))  ; => true
(reversible? (sorted-set nil 1 2 3))  ; => true
(reversible? {:a 1})              ; => false
(reversible? #{1 2 3})            ; => false
(reversible? (list 1 2 3))        ; => false
```
