# Metadata

FOL supports Clojure-style metadata on symbols, persistent objects, and collections.
Metadata is arbitrary data (typically a dict or plist) associated with an object
without affecting its value semantics.

## Reader Syntax

The `^` reader macro attaches metadata to the next form:

```fol
;; Dict metadata
^{:doc "A useful function" :added "1.0"} (defn foo [x] x)

;; Keyword shorthand: ^:kw => ^{:kw true}
^:private (defn helper [x] (* x x))

;; Type shorthand: ^Type => ^{:type Type}
^String name
```

---

## meta                                                                *[generic]*

```
(meta obj)
```

Returns the metadata associated with obj, or nil if none.
Works on symbols, persistent objects, and collections.

### Examples

```fol
(def sym 'my-var)
(with-meta sym {:doc "A variable"})
(meta sym)                    ; => {:doc "A variable"}

(meta 42)                     ; => nil (no metadata support)
(meta (vector 1 2 3))         ; => nil (no metadata set)
```

---

## with-meta                                                          *[generic]*

```
(with-meta obj m)
```

Returns an object of the same type and value as obj, with its metadata
set to m. For symbols, mutates in place (symbols are mutable in CL).
For persistent objects and collections, returns a new instance sharing
structure with the original.

### Examples

```fol
;; On a vector
(def v [1 2 3])
(def v2 (with-meta v {:source "test"}))
(meta v2)                     ; => {:source "test"}
(meta v)                      ; => nil (original unchanged)

;; On a symbol
(with-meta 'my-fn {:doc "Does stuff"})
(meta 'my-fn)                 ; => {:doc "Does stuff"}

;; On a dict
(def d (with-meta {:a 1} {:tag "config"}))
(meta d)                      ; => {:tag "config"}
```

---

## vary-meta                                                          *[function]*

```
(vary-meta obj f & args)
```

Returns an object with `(apply f (meta obj) args)` as its metadata.
Useful for updating metadata functionally.

### Examples

```fol
(def v (with-meta [1 2 3] {:version 1}))
(def v2 (vary-meta v (fn [m] (assoc m :version (inc (:version m))))))
(meta v2)                     ; => {:version 2}
(meta v)                      ; => {:version 1}
```

---

## alter-meta!                                                        *[generic]*

```
(alter-meta! obj f & args)
```

Atomically alters the metadata of obj by applying `(apply f current-meta args)`.
Works on symbols (mutates the symbol's plist).

### Examples

```fol
(with-meta 'counter {:hits 0})
(alter-meta! 'counter (fn [m] (update m :hits inc)))
(meta 'counter)               ; => {:hits 1}
```

---

## reset-meta!                                                        *[generic]*

```
(reset-meta! obj new-meta)
```

Atomically resets the metadata of obj to new-meta.
Works on symbols (mutates the symbol's plist).

### Examples

```fol
(with-meta 'my-sym {:old true})
(reset-meta! 'my-sym {:new true})
(meta 'my-sym)                ; => {:new true}
```

---

## doc                                                                 *[function]*

```
(doc name)
```

Returns the `:doc` entry from the metadata of name. Works with both
plist-style and dict-style metadata.

### Examples

```fol
(with-meta 'my-fn {:doc "Computes the answer"})
(doc 'my-fn)                  ; => "Computes the answer"

(doc 'no-meta-fn)             ; => nil
```

---

## Type Annotations for Optimization

The `^Type` metadata syntax can be used to add compile-time type hints that enable SBCL optimizations.

### Reader Syntax

```fol
;; Add type annotation to function
(defn ^cl:fixnum factorial [n]
  (if (<= n 1) 1 (* n (factorial (dec n)))))

;; SBCL generates:
;; (declare (ftype (function (t) cl:fixnum) factorial))
```

### Common Types

| Type | Meaning | Example |
|------|---------|---------|
| `cl:fixnum` | 60-bit signed integer | `^cl:fixnum n` |
| `cl:integer` | Arbitrary-precision integer | `^cl:integer count` |
| `cl:double` | 64-bit float | `^cl:double value` |
| `cl:single-float` | 32-bit float | `^cl:single-float x` |
| `cl:vector` | Sequence/array | `^cl:vector items` |
| `(cl:function (arg-types...) ret-type)` | Function type | Advanced |

### Examples

```fol
;; Simple type annotation
(defn ^cl:fixnum add-one [^cl:fixnum n]
  (cl:+ n 1))

;; Multi-clause with types
(defn ^cl:number compute
  ([^cl:fixnum x]
   (cl:+ x 1))
  ([^cl:double x]
   (cl:* x 2.0)))

;; Return type only (for complex functions)
(defn ^cl:vector process-data [items]
  (map inc items))
```

### Performance Impact

Type annotations enable SBCL to:
- Eliminate redundant type checks
- Use specialized machine operations
- Perform better register allocation
- Inline type-checked code

Expected improvements: **5-30%** on heavily-typed numerical code

See [Optimization Guide](./optimization-guide.md) for detailed performance tuning strategies.

---

## find-doc                                                            *[function]*

```
(find-doc re-string)
```

Searches all accessible symbols for those with `:doc` metadata matching
re-string (case-insensitive regex). Returns a list of `(symbol . doc)` pairs.

### Examples

```fol
(find-doc "compute")          ; => list of symbols with "compute" in their doc
(find-doc "(?i)string")       ; => list of symbols with "string" in their doc
```

---

## test                                                                *[function]*

```
(test name)
```

Returns the `:test` entry from the metadata of name. Typically used to
store a test function associated with a symbol.

### Examples

```fol
(with-meta 'my-fn {:test (fn [] (assert (= 4 (my-fn 2))))})
(funcall (test 'my-fn))       ; runs the test
```
