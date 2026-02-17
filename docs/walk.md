# Tree Walking (fol.walk)

Functions for walking and transforming nested data structures. Based on
Clojure's `clojure.walk` namespace, adapted for FOL's persistent collection
types.

---

## walk                                                            *[function]*

```
(walk inner outer form)
```

The fundamental tree-walking building block. Applies `inner` to each element
of `form` (if it is a collection), then applies `outer` to the rebuilt result.
Non-collection values are passed directly to `outer`.

For dicts, each entry is presented to `inner` as a 2-element vector
`[key value]`, and `inner` must return a 2-element vector.

### Examples

```fol
;; Double each element of a vector
(walk (fn [x] (* x 2)) identity [1 2 3])      ; => [2 4 6]

;; Apply outer to rebuilt collection
(walk identity (fn [x] (size x)) [1 2 3])      ; => 3

;; Walk dict entries (each is a [key value] vector)
(walk (fn [entry]
        [(first entry) (* (second entry) 10)])
      identity
      {:a 1 :b 2})                              ; => {:a 10 :b 20}

;; Non-collections go directly to outer
(walk identity (fn [x] (* x 2)) 5)             ; => 10
```

---

## prewalk                                                         *[function]*

```
(prewalk f form)
```

Performs a depth-first, pre-order traversal of `form`. Calls `f` on each
sub-form *before* walking into its children. This means parent forms are
transformed before their children are visited.

### Examples

```fol
;; Increment all numbers (parent transformed first)
(prewalk (fn [x] (if (number? x) (inc x) x))
         [1 [2 3] 4])
; => [2 [3 4] 5]

;; Replace keywords with values
(prewalk (fn [x]
           (case x
             :a 1
             :b 2
             x))
         [:a [:b :c]])
; => [1 [2 :c]]
```

---

## prewalk-demo                                                    *[function]*

```
(prewalk-demo form)
```

Demonstrates the order of a depth-first pre-order walk by printing each
sub-form as it is visited. Returns the original form unchanged.

### Examples

```fol
(prewalk-demo [1 [2 3]])
;; Prints:
;;   [1 [2 3]]    ; outer vector first
;;   1             ; then first element
;;   [2 3]         ; then nested vector
;;   2             ; then nested elements
;;   3
```

---

## prewalk-replace                                                 *[function]*

```
(prewalk-replace smap form)
```

Replaces values in `form` using the substitution map `smap` (a dict).
Replacement happens in pre-order: parent forms are replaced *before*
their children are visited, so a replacement can prevent its children
from being walked.

### Examples

```fol
;; Simple keyword replacement
(prewalk-replace {:a 1 :b 2} [:a :b [:a :b]])
; => [1 2 [1 2]]

;; Parent replacement prevents child walking
(prewalk-replace {[1 2] :replaced} [[1 2] [3 4]])
; => [:replaced [3 4]]
```

---

## postwalk                                                        *[function]*

```
(postwalk f form)
```

Performs a depth-first, post-order traversal of `form`. Walks the children
first, then calls `f` on the rebuilt result. This means leaf values are
transformed before their containing collections.

### Examples

```fol
;; Increment all numbers (children transformed first)
(postwalk (fn [x] (if (number? x) (inc x) x))
          [1 [2 3] 4])
; => [2 [3 4] 5]

;; Transform structure types
(postwalk (fn [x]
            (if (vector? x)
                (conj x :visited)
                x))
          [1 [2 3]])
; => [1 [2 3 :visited] :visited]
```

---

## postwalk-demo                                                   *[function]*

```
(postwalk-demo form)
```

Demonstrates the order of a depth-first post-order walk by printing each
sub-form as it is visited. Returns the original form unchanged.

### Examples

```fol
(postwalk-demo [1 [2 3]])
;; Prints:
;;   1             ; leaf elements first
;;   2
;;   3
;;   [2 3]         ; then nested vector
;;   [1 [2 3]]     ; then outer vector last
```

---

## postwalk-replace                                                *[function]*

```
(postwalk-replace smap form)
```

Replaces values in `form` using the substitution map `smap` (a dict).
Replacement happens in post-order: children are walked and replaced
*before* their parent is examined.

### Examples

```fol
;; Simple keyword replacement
(postwalk-replace {:a 1 :b 2} [:a :b [:a :b]])
; => [1 2 [1 2]]

;; Child replacement happens first
(postwalk-replace {:x 10 :y 20} [:x [:y :z]])
; => [10 [20 :z]]
```

---

## Prewalk vs Postwalk

The key difference between prewalk and postwalk is *when* the transformation
function is applied relative to recursion into children:

| | Prewalk | Postwalk |
|---|---------|----------|
| **Order** | Parent first, then children | Children first, then parent |
| **Use case** | Replace whole subtrees | Transform leaf values up |
| **Replace semantics** | Replacement can prevent child walking | Children replaced before parent lookup |

### Example showing the difference

```fol
(def data [1 2])
(def smap {[1 2] [3 4], 1 99})

(prewalk-replace smap data)
; => [3 4]   — [1 2] replaced before children walked

(postwalk-replace smap data)
; => [99 2]  — 1 replaced with 99 first, then [99 2] has no match
```

---

## Supported Collection Types

`walk` dispatches on the type of `form`:

| Type | Behavior |
|------|----------|
| `<vector>` | Walk each element, rebuild vector |
| `<dict>` | Walk each entry as `[key value]` vector, rebuild dict |
| `<set>` | Walk each element, rebuild set |
| `<list>` | Walk each element, rebuild list |
| Other | Pass directly to `outer` (atoms, strings, numbers, keywords, etc.) |
