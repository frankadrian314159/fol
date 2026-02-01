# FOL Zipper Functions

Zippers are a functional programming technique for navigating and editing immutable tree structures. They maintain a "focus" on a node while tracking the path back to the root, enabling efficient local updates in a purely functional way.

FOL's zipper implementation follows the Clojure `clojure.zip` API.

## Creating Zippers

### `(zipper branch-fn children-fn make-node-fn root)`             *[function]*

Creates a new zipper structure.

**Parameters:**
- `branch-fn` - A function that, given a node, returns true if it can have children
- `children-fn` - A function that, given a branch node, returns a seq of its children
- `make-node-fn` - A function that, given an existing node and a seq of children, returns a new branch node with the supplied children
- `root` - The root node of the tree

**Example:**
```clojure
(zipper <vector>?
        seq
        (fn [node children] (apply vector children))
        [1 [2 3] 4])
```

### `(seq-zip root)`                                               *[function]*

Returns a zipper for nested sequences (lists/seqs). Branches are seqs, children are elements of the seq.

**Example:**
```clojure
(seq-zip '(1 (2 3) 4))
```

### `(vector-zip root)`                                            *[function]*

Returns a zipper for nested vectors. Branches are vectors, children are elements of the vector.

**Example:**
```clojure
(vector-zip [1 [2 3] 4])
```

## Accessors

### `(node loc)`                                                   *[function]*

Returns the node at the current location.

### `(branch? loc)`                                                *[function]*

Returns true if the node at the current location is a branch (can have children).

### `(children loc)`                                               *[function]*

Returns a seq of the children of the node at loc. The node must be a branch.

### `(make-node loc node children)`                                *[function]*

Returns a new branch node, given an existing node and new children. Used internally for editing operations.

### `(path loc)`                                                   *[function]*

Returns a seq of nodes leading from the root to this location.

### `(lefts loc)`                                                  *[function]*

Returns a seq of the left siblings of the node at this location.

### `(rights loc)`                                                 *[function]*

Returns a seq of the right siblings of the node at this location.

## Navigation

### `(down loc)`                                                   *[function]*

Returns the location of the leftmost child of the node at this location, or nil if no children.

**Example:**
```clojure
(-> (vector-zip [1 [2 3] 4])
    down
    node)
; => 1
```

### `(up loc)`                                                     *[function]*

Returns the location of the parent of the node at this location, or nil if at the top.

### `(left loc)`                                                   *[function]*

Returns the location of the left sibling of the node at this location, or nil.

### `(right loc)`                                                  *[function]*

Returns the location of the right sibling of the node at this location, or nil.

**Example:**
```clojure
(-> (vector-zip [1 [2 3] 4])
    down
    right
    node)
; => [2 3]
```

### `(leftmost loc)`                                               *[function]*

Returns the location of the leftmost sibling of the node at this location, or self if already there.

### `(rightmost loc)`                                              *[function]*

Returns the location of the rightmost sibling of the node at this location, or self if already there.

### `(root loc)`                                                   *[function]*

Returns the root node of the tree, reflecting any changes made through the zipper.

**Example:**
```clojure
(-> (vector-zip [1 [2 3] 4])
    down
    right
    down
    (replace 99)
    root)
; => [1 [99 3] 4]
```

## Traversal

### `(next loc)`                                                   *[function]*

Moves to the next location in the hierarchy using depth-first traversal. When reaching the end, returns a distinguished location detectable via `end?`.

**Example:**
```clojure
(loop [loc (vector-zip [1 [2 3] 4])]
  (if (end? loc)
    :done
    (do
      (print (node loc))
      (recur (next loc)))))
; Prints: [1 [2 3] 4] 1 [2 3] 2 3 4
```

### `(prev loc)`                                                   *[function]*

Moves to the previous location in the hierarchy using depth-first traversal. Returns nil if at the root.

### `(end? loc)`                                                   *[function]*

Returns true if loc represents the end of a depth-first walk.

## Editing

All editing functions return a new zipper with the modification applied. The original zipper is unchanged (immutable).

### `(replace loc node)`                                           *[function]*

Replaces the node at this location with a new node, without moving.

**Example:**
```clojure
(-> (vector-zip [1 2 3])
    down
    (replace :a)
    root)
; => [:a 2 3]
```

### `(edit loc f & args)`                                          *[function]*

Replaces the node at this location with the value of `(f node args)`.

**Example:**
```clojure
(-> (vector-zip [1 2 3])
    down
    (edit inc)
    root)
; => [2 2 3]
```

### `(insert-child loc item)`                                      *[function]*

Inserts item as the leftmost child of the node at this location, without moving.

**Example:**
```clojure
(-> (vector-zip [1 [2 3] 4])
    down
    right
    (insert-child :a)
    root)
; => [1 [:a 2 3] 4]
```

### `(append-child loc item)`                                      *[function]*

Inserts item as the rightmost child of the node at this location, without moving.

**Example:**
```clojure
(-> (vector-zip [1 [2 3] 4])
    down
    right
    (append-child :z)
    root)
; => [1 [2 3 :z] 4]
```

### `(insert-left loc item)`                                       *[function]*

Inserts item as the left sibling of the node at this location, without moving.

**Example:**
```clojure
(-> (vector-zip [1 2 3])
    down
    right
    (insert-left :a)
    root)
; => [1 :a 2 3]
```

### `(insert-right loc item)`                                      *[function]*

Inserts item as the right sibling of the node at this location, without moving.

**Example:**
```clojure
(-> (vector-zip [1 2 3])
    down
    (insert-right :a)
    root)
; => [1 :a 2 3]
```

### `(zip-remove loc)`                                             *[function]*

Removes the node at loc, returning the location that would have preceded it in a depth-first walk.

Note: This function retains the `zip-` prefix to avoid conflict with the collection `remove` function.

**Example:**
```clojure
(-> (vector-zip [1 2 3])
    down
    right
    zip-remove
    root)
; => [1 3]
```

## Common Patterns

### Walking a tree and collecting values

```clojure
(defn collect-leaves [root]
  (loop [loc (vector-zip root)
         leaves []]
    (if (end? loc)
      leaves
      (recur (next loc)
             (if (branch? loc)
               leaves
               (conj leaves (node loc)))))))

(collect-leaves [1 [2 [3 4]] 5])
; => [1 2 3 4 5]
```

### Transforming all nodes

```clojure
(defn transform-all [root f]
  (loop [loc (vector-zip root)]
    (if (end? loc)
      (root loc)
      (recur (next (edit loc f))))))

(transform-all [1 [2 3] 4] inc)
; => [2 [3 4] 5]
```

### Finding a node

```clojure
(defn find-node [root pred]
  (loop [loc (vector-zip root)]
    (cond
      (end? loc) nil
      (pred (node loc)) loc
      :else (recur (next loc)))))

(-> (find-node [1 [2 3] 4] (fn [n] (= n 3)))
    node)
; => 3
```

## Implementation Notes

- Zippers are implemented as a class `<zipper>` with slots for the current node, navigation context, and tree-construction functions
- The zipper is fully functional/immutable - all navigation and editing operations return new zipper instances
- The `path` slot maintains the path from root to current location for reconstruction
- The `changed` slot tracks whether modifications have been made, enabling lazy reconstruction
