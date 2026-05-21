# Dispatch Cache Safety: Formal Definition and Classification

**Date**: May 14, 2026  
**Status**: Research-grade formalization of cache-safe predicates

---

## 1. Formal Definition of Cache-Safety

### Definition 1.1: Cache-Safe Predicate

A predicate `P: Object → Boolean` is **cache-safe** if and only if:

```
∀ objects o₁, o₂ ∈ Domain:
  (class-of o₁ = class-of o₂) ∧ P(o₁) = true  ⟹  P(o₂) = true
```

**Informal**: If two objects have the same class and P is true for the first, then P must be true for the second (or P must be false for both).

**Equivalently**: P depends only on the class of its argument, not on object properties or values.

### Definition 1.2: Cache-Safe Dispatch Function

A dispatch function `f: Object → Result` with guard predicates `P₁, P₂, ..., Pₙ` is **cache-safe** if:

```
For all i: Pᵢ is cache-safe
AND
For all objects o with class C:
  if Pᵢ(o) then dispatch result depends only on C, not on o's properties
```

**In FOL**: A defn with dispatch clauses is cache-safe if all guard predicates are cache-safe.

---

## 2. Classification of Predicates

### Category A: Cache-Safe (Type-Based)

These predicates depend ONLY on `(class-of arg)`:

| Predicate | Definition | Cache-Safe? | Example |
|-----------|-----------|------------|---------|
| `integer?` | `(typep x 'integer)` | ✅ YES | `(integer? 42)` → T |
| `float?` | `(typep x 'float)` | ✅ YES | `(float? 3.14)` → T |
| `vector?` | `(typep x 'vector)` | ✅ YES | `(vector? #(1 2))` → T |
| `dict?` | `(typep x '<dict>)` | ✅ YES | `(dict? {:a 1})` → T |
| `class-of` | Identity | ✅ YES | `(class-of o)` |
| `instance?` | Class membership | ✅ YES | `(instance? o MyClass)` → T |
| `satisfies` | Type spec only | ✅ YES | `(satisfies integer-predicate)` |

**Proof**: If `(class-of o₁) = (class-of o₂)`, then `type?(o₁) = type?(o₂)` by definition.

### Category B: NOT Cache-Safe (Value/Property-Based)

These predicates depend on object properties or values:

| Predicate | Depends On | Cache-Safe? | Problem |
|-----------|-----------|------------|---------|
| `(> x 100)` | Numeric value | ❌ NO | Two integers with same class may have different values |
| `(empty? coll)` | Collection size | ❌ NO | Two vectors with same class may have different sizes |
| `(= x 42)` | Specific value | ❌ NO | Only works for one value |
| `(str-contains? s "foo")` | String content | ❌ NO | Two strings with same class may have different content |
| `(> (count v) 100)` | Derived property | ❌ NO | Two vectors may have different counts |
| `custom-property?` | Custom attribute | ❌ NO | Objects with same class may have different attributes |

**Proof by counterexample**:
```lisp
(let ((v1 #(1 2 3))
      (v2 #(1 2 3 4 5 ... 101)))
  (assert (= (class-of v1) (class-of v2)))  ; Both are vectors
  (assert (not (= (> (count v1) 100)
                  (> (count v2) 100))))      ; But predicates differ!
  ;; Cache would use (class-of v1) as key, hitting wrong result for v2
)
```

### Category C: Mixed (Type + Value)

Conjunctions of type and value predicates:

```lisp
(and (vector? x) (> (count x) 100))
     ↑                   ↑
     cache-safe      NOT cache-safe
```

**Verdict**: ❌ NOT cache-safe

**Why**: The cache key `(class-of x)` identifies it as a vector, but the second conjunct depends on vector properties. Two vectors with the same class may disagree on the second clause.

**Safety analysis**:
- If ANY conjunct is NOT cache-safe, the entire predicate is NOT cache-safe
- **Rule**: A conjunction `(and P₁ P₂ ... Pₙ)` is cache-safe IFF all Pᵢ are cache-safe

---

## 3. Formal Safety Audit Algorithm

### Algorithm: Classify-Predicate-Safety

**Input**: A predicate form `P` from a dispatch clause  
**Output**: `cache-safe?` ∈ {true, false, uncertain}

```
classify-safety(P):
  CASE P OF
    
    ;; Type predicates (safe)
    (integer? x) → true
    (float? x) → true
    (vector? x) → true
    (dict? x) → true
    (instance? x Class) → true
    (satisfies spec) where spec is type-only → true
    
    ;; Value predicates (unsafe)
    (= x literal) → false
    (> x value) → false
    (< x value) → false
    (empty? x) → false
    (string-contains? x str) → false
    (custom-predicate? x) → false
    
    ;; Conjunction (safe only if all conjuncts safe)
    (and P₁ P₂ ... Pₙ) → 
      all?(classify-safety(Pᵢ) == true for i in 1..n)
    
    ;; Disjunction (unsafe if any disjunct unsafe)
    (or P₁ P₂ ... Pₙ) → 
      all?(classify-safety(Pᵢ) == true for i in 1..n)
    
    ;; Negation (inverts safety)
    (not P) → classify-safety(P)
    
    ;; Composition (safe only if all function calls preserve type)
    (fn-that-returns-type? x) → true
    (expensive-check? x) where check depends on value → false
    
    ;; Unknown
    (custom-function? x) → uncertain
```

---

## 4. FOL Predicate Classification

### Built-in Type Predicates (✅ Cache-Safe)

```lisp
integer?      float?      string?      symbol?      char?
keyword?      vector?     dict?        set?         map?
list?         seq?        coll?        fn?          nil?
boolean?      number?     some?        map-entry?
```

All are safe because they check `(class-of arg)` only.

### Collection Predicates (⚠️ Mixed or Unsafe)

```lisp
empty?           → ❌ UNSAFE (checks count)
not-empty?       → ❌ UNSAFE (checks count)
count            → ❌ UNSAFE (returns property, not boolean)
sequential?      → ✅ SAFE (type property)
associative?     → ✅ SAFE (type property)
sorted?          → ⚠️ MIXED (type-safe, but some implementations check order)
counted?         → ✅ SAFE (type property)
reversible?      → ✅ SAFE (type property)
```

### Value Predicates (❌ NOT Cache-Safe)

```lisp
(> x threshold)       → ❌ UNSAFE
(< x threshold)       → ❌ UNSAFE
(= x value)           → ❌ UNSAFE
(contains? coll x)    → ❌ UNSAFE
(str-contains? s str) → ❌ UNSAFE
(matches? s pattern)  → ❌ UNSAFE
(custom-property? x)  → ❌ UNSAFE
```

---

## 5. Real FOL Code Examples

### Example 1: Safe (Type-Only)

```lisp
(defn process [x]
  (cond
    ((integer? x) (* x 2))        ; ✅ Type predicate → SAFE
    ((float? x) (* x 2.0))        ; ✅ Type predicate → SAFE
    ((string? x) (str-upper-case x))  ; ✅ Type predicate → SAFE
    ((vector? x) (reverse x))     ; ✅ Type predicate → SAFE
    (t x)))

;; Cache verdict: ✅ SAFE TO CACHE
```

### Example 2: Unsafe (Value Predicates)

```lisp
(defn classify-number [n]
  (cond
    ((> n 1000) :large)          ; ❌ Value predicate → UNSAFE
    ((> n 100) :medium)          ; ❌ Value predicate → UNSAFE
    ((> n 0) :positive)          ; ❌ Value predicate → UNSAFE
    (t :non-positive)))

;; Cache verdict: ❌ NOT SAFE TO CACHE
;; Problem: Two different numbers may have same class but different results
```

### Example 3: Mixed (Type + Value)

```lisp
(defn classify-collection [coll]
  (cond
    ((and (vector? coll) (> (count coll) 100)) :large-vec)    ; ❌ UNSAFE
    ((and (dict? coll) (> (count (keys coll)) 50)) :large-dict) ; ❌ UNSAFE
    ((vector? coll) :vec)                          ; ✅ SAFE
    ((dict? coll) :dict)                           ; ✅ SAFE
    (t :other)))

;; Cache verdict: ⚠️ PARTIALLY UNSAFE
;; Problem: Clauses 1-2 are unsafe; caching would give wrong results for large vectors
;; Solution: Restructure to safe form below
```

### Example 4: Refactored to Safe

```lisp
(defn classify-collection [coll]
  (cond
    ((vector? coll)
     ;; Safe dispatch on type; property check happens after
     (if (> (count coll) 100) :large-vec :small-vec))
    ((dict? coll)
     ;; Safe dispatch on type; property check happens after
     (if (> (count (keys coll)) 50) :large-dict :small-dict))
    (t :other)))

;; Cache verdict: ✅ SAFE TO CACHE
;; Why: Type predicates determine cache key; value checks happen in result branches
```

---

## 6. Compiler Integration: Automatic Safety Detection

### Proposed Compiler Enhancement

The FOL compiler could automatically detect cache-unsafe predicates:

```lisp
(defun cacheable-with-safety-check (clauses)
  "Analyze clauses for caching; warn if unsafe predicates detected."
  (let ((safe-p t))
    (dolist (clause clauses)
      (let ((guards (extract-guards clause)))
        (dolist (guard guards)
          (unless (cache-safe-predicate-p guard)
            (warn "Cache-unsafe predicate in ~A: ~A" 
                  (clause-signature clause) guard)
            (setf safe-p nil)))))
    (and safe-p (>= (length clauses) +dispatch-cache-threshold+))))
```

### Developer Warnings

```lisp
(defn classify-vec [v]
  (cond
    ((> (count v) 100) :large)  ; ⚠️ WARNING: Cache-unsafe predicate detected
    (t :small)))
    
;; Compiler message:
;; WARNING: Dispatch caching disabled for CLASSIFY-VEC
;;   Reason: Cache-unsafe predicate (> (COUNT V) 100)
;;   Solution 1: Add &rest parameter to disable caching
;;   Solution 2: Restructure as:
;;     (if (> (count v) 100) ... :large ... :small)
;;   See: docs/dispatch-cache-safety-formalism.md
```

---

## 7. Summary Table: Predicate Safety Classification

| Category | Predicates | Cache-Safe? | Why | Example |
|----------|-----------|------------|-----|---------|
| **Type Checks** | `integer?`, `vector?`, etc. | ✅ YES | Depend only on `class-of` | `(integer? x)` |
| **Type Properties** | `sequential?`, `counted?` | ✅ YES | Reflect type structure | `(sequential? x)` |
| **Value Predicates** | `(> x 100)`, `(= x 42)` | ❌ NO | Depend on object properties | `(> x 100)` |
| **Collection Size** | `empty?`, `(> (count x) N)` | ❌ NO | Depend on runtime data | `(empty? coll)` |
| **String Content** | `(contains? s "foo")` | ❌ NO | Depend on data values | `(str-contains? s "foo")` |
| **Conjunctions** | `(and type? value-check)` | ❌ NO | Unsafe if ANY conjunct unsafe | `(and (vector? x) (> (count x) 100))` |
| **Nested Dispatch** | `(if (type? x) (if (prop? x) ...) ...)` | ✅ YES | Property checks after type | `(if (vector? x) (if (> (count x) 100) ...) ...)` |

---

## 8. Proof Sketch: Why Type Predicates Are Safe

**Theorem**: For any type predicate `T`, if two objects have the same class, then `T(o₁) = T(o₂)`.

**Proof**:
1. A type predicate checks membership in a type (class)
2. By definition, `class-of` is injective on instances of the same type
3. If `(class-of o₁) = (class-of o₂)`, then `o₁` and `o₂` are instances of the same type
4. Therefore `T(o₁) = T(o₂)` (both true or both false)
5. Thus caching based on `(class-of arg)` is sound

**Corollary**: Value predicates are NOT safe because they can be true for one value and false for another value of the same type.

---

## 9. Implications for Cache Design

### Design Principle 1: Type-Based Cache Keys Are Sufficient for Type Predicates

If all dispatch guards are type predicates, using `(class-of arg)` as cache key guarantees correctness.

### Design Principle 2: Value Predicates Require Different Cache Keys

If any guard is a value predicate (e.g., `(= x 42)`), the cache key must include the value:
```lisp
;; Safe cache key for value predicate:
(cache-key-for x) = (list (class-of x) x)
;; Not: just (class-of x)
```

### Design Principle 3: Mixed Predicates Cannot Be Cached Safely

If a clause has both type and value predicates, either:
1. Disable caching for the function, OR
2. Restructure to type predicate first, then check values in the result branch

---

## Conclusion

Cache safety is a **formal property** of dispatch predicates. A predicate is cache-safe iff it depends only on `(class-of arg)`, not on object properties or values.

**Developers can use the safety audit algorithm** (Section 3) to determine if their dispatch functions are safe for caching.

**The FOL compiler could emit warnings** for cache-unsafe predicates automatically.

