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
