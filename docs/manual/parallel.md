# Parallel Collections

`fol.lib.parallel` provides parallel versions of common collection operations. All functions dispatch element-level work to the **global work-stealing thread pool** (`fol.compiler.mutable`) and block the calling thread until every work item completes before assembling and returning the result.

---

## Threading model

- The pool has `*thread-pool-size*` workers (default 16), each with its own deque.
- `submit-work` distributes tasks round-robin across deques; idle workers steal from other deques.
- All parallel functions submit one task per element, wait for all tasks, then assemble the result serially.
- **Ordering is always by input position**, not by task completion order.
- For very small collections the thread pool overhead may exceed the computation cost. Use the serial equivalents (`filter`, `group-by`, etc.) when elements are few or the per-element work is trivial.

---

## pfilter                                                          *[function]*

```
(pfilter pred coll) → collection
```

Parallel version of `filter`. Tests each element with `pred` on the thread pool. Returns a collection of the same type as `coll` containing only elements for which `pred` returns a truthy value. Element ordering is preserved.

```fol
(pfilter odd?  [1 2 3 4 5])   ; => [1 3 5]
(pfilter even? #{1 2 3 4})    ; => #{2 4}
(pfilter pos?  [-1 2 -3 4])   ; => [2 4]
```

---

## pgroup-by                                                        *[function]*

```
(pgroup-by fn coll) → dict
```

Parallel version of `group-by`. Applies `fn` to every element on the thread pool to compute its group key, then assembles the result dict serially. Returns a dict of `{key [elements]}` where `key = (fn element)`. Element ordering within each group matches the input ordering.

```fol
(pgroup-by even? [1 2 3 4 5])
; => {nil [1 3 5]  t [2 4]}

(pgroup-by (fn [s] (first s)) ["ant" "ape" "bear" "bee"])
; => {"a" ["ant" "ape"]  "b" ["bear" "bee"]}
```

---

## ppartition                                                       *[function]*

```
(ppartition pred coll) → [matching non-matching]
```

Parallel partition by predicate. Tests each element with `pred` on the thread pool, then splits the collection into two groups. Returns a two-element vector `[matching non-matching]`, each of the same collection type as `coll`. Element ordering within each group is preserved.

> **Note:** This is Scala's `partition(pred)` — split into passing/failing — not FOL's `partition` which splits by chunk size.

```fol
(ppartition odd?  [1 2 3 4 5])   ; => [[1 3 5] [2 4]]
(ppartition pos?  [-1 2 -3 4])   ; => [[2 4] [-1 -3]]
(ppartition even? [2 4 6])       ; => [[2 4 6] []]
```

---

## pzip                                                             *[function]*

```
(pzip coll1 coll2) → vector
```

Pair corresponding elements from `coll1` and `coll2`, building each pair on the thread pool. Stops at the shorter collection. Returns a vector of two-element vectors `[a b]`.

```fol
(pzip [1 2 3] [:a :b :c])   ; => [[1 :a] [2 :b] [3 :c]]
(pzip [1 2]   [10 20 30])   ; => [[1 10] [2 20]]
(pzip []      [1 2 3])      ; => []
```

**Tip:** `pzip` is most useful when the resulting pairs will be passed to `pmap` for further parallel processing:

```fol
(pmap (fn [[a b]] (+ a b))
      (pzip weights values))
```

---

## pzip-with-index                                                  *[function]*

```
(pzip-with-index coll) → vector
```

Pair each element of `coll` with its zero-based positional index on the thread pool. Returns a vector of two-element vectors `[element index]`.

```fol
(pzip-with-index [:a :b :c])      ; => [[:a 0] [:b 1] [:c 2]]
(pzip-with-index [100 200 300])   ; => [[100 0] [200 1] [300 2]]
```

---

## pforeach                                                         *[function]*

```
(pforeach fn coll) → nil
```

Apply `fn` to every element of `coll` in parallel for side effects. All elements are dispatched to the thread pool simultaneously. Blocks until every invocation has completed. Returns `nil`.

The order in which `fn` is called across elements is **unspecified**. If the side effects must be ordered, use the serial `run!` instead.

```fol
(pforeach (fn [url] (download! url)) urls)

; Compare: serial version
(run! (fn [url] (download! url)) urls)
```

---

## pfind                                                            *[function]*

```
(pfind pred coll) → element | nil
```

Test every element of `coll` with `pred` in parallel. Return the **first element in input order** for which `pred` returns a truthy value, or `nil` if none match.

All predicate tests are submitted at once. The result is the positionally-earliest match, not the one whose test happens to finish first.

```fol
(pfind even? [1 3 4 6])   ; => 4  (not 6, even though both match)
(pfind even? [1 3 5])     ; => nil
(pfind pos?  [-1 -2 3 4]) ; => 3
```

---

## pexists                                                          *[function]*

```
(pexists pred coll) → t | nil
```

Return `t` if `pred` returns a truthy value for at least one element of `coll`, `nil` otherwise. All predicate tests run on the thread pool in parallel. Always returns a boolean `t` or `nil`.

Analogous to Scala's `.par.exists(pred)`.

```fol
(pexists even? [1 3 4 6])   ; => t
(pexists even? [1 3 5])     ; => nil
(pexists even? [])           ; => nil
```

---

## pforall                                                          *[function]*

```
(pforall pred coll) → t | nil
```

Return `t` if `pred` returns a truthy value for every element of `coll`, `nil` otherwise. All predicate tests run on the thread pool in parallel. Returns `t` vacuously for an empty collection. Always returns a boolean `t` or `nil`.

Analogous to Scala's `.par.forall(pred)`.

```fol
(pforall even? [2 4 6])   ; => t
(pforall even? [2 3 6])   ; => nil
(pforall even? [])         ; => t  (vacuously true)
```

---

## psize                                                            *[function]*

```
(psize pred coll) → integer
```

Count the elements of `coll` for which `pred` returns a truthy value. All predicate tests run on the thread pool in parallel. Returns a non-negative integer.

Analogous to Scala's `.par.count(pred)`.

```fol
(psize even? [1 2 3 4 5])   ; => 2
(psize odd?  [1 2 3 4 5])   ; => 3
(psize pos?  [-1 -2 3])     ; => 1
(psize even? [])             ; => 0
```

---

## Summary table

| Function | Serial equivalent | Returns |
|---|---|---|
| `pfilter pred coll` | `filter` | Same type as `coll`, elements in input order |
| `pgroup-by fn coll` | `group-by` | `<dict>` of `{key [elements]}` |
| `ppartition pred coll` | — | `[[passing] [failing]]` vector |
| `pzip coll1 coll2` | `(map vector coll1 coll2)` | Vector of `[a b]` pairs |
| `pzip-with-index coll` | `(map-indexed vector coll)` | Vector of `[elem idx]` pairs |
| `pforeach fn coll` | `run!` | `nil` |
| `pfind pred coll` | `some` | First matching element or `nil` |
| `pexists pred coll` | `(boolean (some pred coll))` | `t` or `nil` |
| `pforall pred coll` | `every?` | `t` or `nil` |
| `psize pred coll` | `(size (filter pred coll))` | Non-negative integer |

---

## Also see

- [reducers.md](reducers.md) — chunk-based parallel reduction (`preduce`, `fold`, `aggregate`)
- [core-async.md](core-async.md) — channel-based streaming parallelism (`pipeline`, `pipeline-async`)
