# FOL Pattern Dispatch Specificity Levels

This document describes the priority ordering used when matching multiple pattern clauses in FOL functions, methods, and macros.

## Specificity Levels

When multiple patterns could match a given set of arguments, FOL selects the **most specific** pattern. Higher specificity levels take precedence over lower ones.

| Level | Type | Syntax Example | Description |
|-------|------|----------------|-------------|
| **3** | Predicate | `(x (< 10))`, `(n (= 0))`, `(v (even?))` | Arbitrary predicate test on argument value |
| **2** | Type | `(x <number>)`, `(s <string>)` | Type specialization (class name) |
| **2** | Type-Predicate | `((<number>? x))` | Type predicate function as specializer |
| **1** | Sequence | `[a b c]`, `[x & rest]` | Vector/list destructuring pattern |
| **0** | Any | `x`, `_` | Matches any value (no constraint) |

**Note:** Type specializers `(x <type>)` and type-predicate specializers `((<type>? x))` are at the **same** specificity level (2), since both perform type checking. When both match, first-defined wins.

## Specificity Comparison Rules

1. **Higher level wins**: A level-3 pattern always beats a level-2 pattern, which beats level-1, etc.

2. **Same level, first match wins**: When patterns have identical specificity, the first defined pattern is tried first.

3. **Sequence sub-specificity**: For sequence patterns (level 1), additional rules apply:
   - More elements = more specific: `[a b c]` beats `[a b]`
   - Element specificity matters: `[(x <number>) y]` beats `[x y]` because the first element has higher specificity

## Examples

### Predicate vs Type (Level 3 vs 2)

```fol
(defn check
  ([(x (= 5))] :exact-five)    ; Level 3 - predicate
  ([(x <number>)] :any-number)) ; Level 2 - type

(check 5)   ; => :exact-five (predicate is more specific)
(check 10)  ; => :any-number (predicate doesn't match, falls through to type)
```

### Type vs Type-Predicate (Same Level 2)

```fol
(defn process
  ([(x <string>)] :type-match)       ; Level 2 - type specializer
  ([((<string>? x))] :pred-match))   ; Level 2 - type predicate

;; When both match, first-defined wins
(process "hello")  ; => :type-match (first defined at same level)
```

### Type vs Any (Level 2 vs 0)

```fol
(defn process
  ([(x <string>)] :string)  ; Level 2
  ([x] :other))             ; Level 0

(process "hello")  ; => :string
(process 42)       ; => :other
```

### Sequence Element Specificity

```fol
(defn match-pair
  ([(x (< 0)) y] :neg-first)    ; Level 1 seq, but element 0 is level 3
  ([[x <number>] y] :num-first) ; Level 1 seq, but element 0 is level 2
  ([[x y]] :any-pair))          ; Level 1 seq, elements are level 0

(match-pair [-5 10])  ; => :neg-first (predicate on first element wins)
(match-pair [5 10])   ; => :num-first (type on first element wins)
(match-pair ["a" "b"]) ; => :any-pair (no constraints match)
```

### Multiple Predicates (Same Level)

```fol
(defn classify
  ([(n (= 0))] :zero)      ; Level 3 - first defined
  ([(n (< 0))] :negative)  ; Level 3 - second defined
  ([(n (> 0))] :positive)) ; Level 3 - third defined

(classify 0)  ; => :zero (first matching predicate)
(classify -5) ; => :negative
(classify 5)  ; => :positive
```

## Implementation Notes

The specificity system is implemented in `fol-mop.lisp`:

- `pattern-specificity-level` returns the numeric level (0-3)
- `pattern-more-specific-p` compares two signatures
- Patterns are sorted by arity first, then by specificity (most specific first)
- At runtime, patterns are tried in sorted order until one matches

## Pattern Types Not in Specificity Hierarchy

These pattern features don't affect specificity directly:

| Feature | Syntax | Notes |
|---------|--------|-------|
| Rest args | `& rest` | Affects arity matching, not specificity |
| `:as` binding | `:as name` | Doesn't affect pattern matching at all |
| `:or` defaults | `:or {x 0}` | Runtime default, not pattern matching |
| `:keys` destructuring | `{:keys [a b]}` | Desugars to map access, specificity depends on key constraints |
