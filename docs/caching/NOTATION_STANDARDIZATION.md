# Notation Standardization for Dispatch Caching Paper

**Date**: May 14, 2026  
**Purpose**: Consistent mathematical notation throughout paper (Sections 1–8)

---

## Current Issues (From Critique)

- Sometimes `CallSet(P)`, sometimes `CallSet(function)`
- Sometimes `version-of-P`, sometimes `version-of-GF`
- Some theorems use informal language, others use formal notation
- Predicate vs. generic-function naming inconsistent

---

## Standardized Notation Guide

### 1. Functions and Predicates

**Convention**: Use distinct notation for functions vs. predicates

| Concept | Notation | Example | Type |
|---------|----------|---------|------|
| **Generic Function** | `f`, `g`, `process` | `f ∈ GF` | Symbol |
| **Predicate** | `p`, `q`, `P` | `p ≡ (λx. class-of x = T)` | Function |
| **Clause/Body** | `e`, `e₁`, `e₂` | `e = (λx. f(x) + 1)` | Expression |
| **Dispatch Decision** | `dispatch(f, args)` | `dispatch(process, [5]) → clause₂` | Function |

**Rule**: Use `f` for functions, `p` for predicates. Never use `f` for predicate.

### 2. Cache-Related Notation

| Concept | Notation | Meaning |
|---------|----------|---------|
| **Cache table** | `C` or `cache(f)` | Hash-table mapping keys to values |
| **Cache key** | `k` or `key(args, gen)` | `(gen, class-of arg₁, class-of arg₂, ...)` |
| **Cache value** | `v` | Cached dispatch decision (clause ID) |
| **Hit** | `C[k] ≠ ⊥` | Lookup returns cached value |
| **Miss** | `C[k] = ⊥` | Lookup returns nil |
| **Generation counter** | `gen`, `g` | Version number for cache invalidation |

**Rule**: Always specify what the cache key includes (generation? hash? both?).

### 3. Version and Generation

| Concept | Notation | When Incremented |
|---------|----------|------------------|
| **Global generation** | `gen_global` | On ANY method add/remove (deprecated) |
| **Per-GF generation** | `gen_f` or `ver(f)` | On method add/remove for GF `f` |
| **Per-hierarchy generation** | `gen_H` | On class hierarchy change |

**Rule**: Explicitly state whether versioning is global, per-GF, or per-hierarchy.

**Example sentences** (correct):
- ✅ "For each GF `f`, we maintain a version counter `gen_f` (Definition 2.1)."
- ❌ "We maintain a version counter" (ambiguous: global or per-function?)

### 4. CallSet Notation

**Current**:
- Sometimes `CallSet(P)` — "functions called by predicate P"
- Sometimes `CallSet(f)` — "functions called by generic function f"

**Standardized**:
- `CallSet(p)` ≜ {`g` : predicate `p` evaluates `(g ...)`}
- `CallSet(f)` ≜ {`g` : clause body of `f` calls `(g ...)`}

**Rule**: Always parenthesize and define: `CallSet(·)` is a mathematical set-builder.

**Example**:
> "Given predicate `p ≡ (λx. (valid? x))`, we have `CallSet(p) = {valid?}`
> and must analyze whether `valid?` is deterministic."

### 5. Determinism and Purity

| Concept | Notation | Definition |
|---------|----------|-------------|
| **Pure** | `pure(f)` | No side effects; result depends only on arguments |
| **Deterministic** | `det(p)` | Always returns same result for same input |
| **Safe** | `safe(p)` | Depends only on (class-of arg) and value, not external state |

**Formal definition** (for Section 2):
```
det(p) ≜ ∀v₁, v₂ ∈ Value:
  v₁ ≡ v₂ (in value) ⟹ p(v₁) = p(v₂)

safe(p) ≜ ∀p ∈ CallSet(p): pure(p) ∧ det(p)
```

### 6. Soundness and Correctness Theorems

**Standard form**:
```
Theorem N.M (Name). Under assumptions A1, A2, ..., property P holds.

Proof. [sketch or full proof]
```

**Current issues**:
- Some theorems lack assumption statements
- Some use phrase "safe iff" without defining "safe"

**Corrected Example** (Theorem 1.1):

> **Theorem 1.1 (Version-Safe Caching).** Let `p` be a predicate where `safe(p)` holds (Definition 2.1).
> For all cache keys `k = (gen_f, args)` with current `gen_f` value, if `cache(f)[k] = clause_id`,
> then evaluating `dispatch(f, args)` yields the same `clause_id` as when the key was inserted.
>
> **Proof.** Since `safe(p)` holds, predicate evaluation depends only on arguments.
> Cache key includes `gen_f`: if `gen_f` has changed, key lookup fails (cache miss).
> Thus, cache entries used are only those where generation matches. QED.

### 7. Notation Glossary (For Appendix)

Create a one-page glossary:

```
Notation Glossary
─────────────────────────────────────────────────────────────
f, g, h         Generic functions
p, q, P, Q      Predicates (unary boolean functions)
e, e_body       Expressions / clause bodies
args, (x, y)    Arguments to functions
v, w            Values at runtime
k, key(...)     Cache keys
C, cache(f)     Cache table for function f
C[k]            Cache lookup (⊥ if miss)
gen_f, ver(f)   Version counter for GF f
CallSet(·)      Set of functions called by predicate/function
det(p)          Deterministic: same input → same output
safe(p)         Safe for caching: depends only on class/value
pure(f)         Pure: no side effects
dispatch(f, args)  Evaluate predicates of f, select clause
─────────────────────────────────────────────────────────────
```

### 8. Consistency Rules for Paper Revision

**When writing about caching**:
1. Always use `cache(f)` or `C` for caches, not "the cache"
2. Always specify cache key contents: e.g., `key = (gen_f, class-of arg)`
3. When discussing predicates, use `p`, `q` (not `f`)
4. When discussing generic functions, use `f`, `g` (not `p`)
5. Define `safe(p)` before using it (Section 2)
6. Define `CallSet(·)` before using it (Section 3)

**Example revision** (current text):
> "The CallSet-based approach flushes the cache for process when any method changes."

**Corrected**:
> "When a method is added to GF `process`, we increment `gen_process` (Definition 3.2).
> For all cached entries with stale `gen_process` values, subsequent lookups miss the cache,
> forcing recomputation via the updated dispatch decision (Theorem 4.1)."

### 9. Formal Language Consistency

**Current**:
- Sections 2–4: Mix of informal and formal
- Section 5–7: Mostly informal
- Section 8: Informal

**Improved**:
- Sections 1–2: Formal definitions (Definitions 1.1, 2.1, 2.2, ...)
- Sections 2–4: Formal theorems (Theorems with proofs)
- Sections 5–7: Informal with notation (use Def./Thm. references)
- Section 8: Informal overview

**Example structure** (Section 2):

```markdown
### 2.1 Cache Safety Definition

Definition 2.1 (Safe Predicate). A predicate p is safe iff ...

### 2.2 Determinism and Purity

Definition 2.2 (Deterministic). A predicate p is deterministic iff ...

### 2.3 Main Result

Theorem 2.3 (Predicate Safety is Sufficient). If safe(p) holds, then ...
Proof. [sketch]

Definition 2.4 (CallSet Analysis). For predicate p, CallSet(p) ≜ ...

Corollary 2.5. If all f ∈ CallSet(p) are pure, then safe(p) holds.
```

### 10. Notation for Concurrent Updates

Add to Section 3 or Appendix:

| Notation | Meaning |
|----------|---------|
| `atomic(x++)` | Atomic increment of x (hardware primitive) |
| `lock(C)` | Lock cache table before update |
| `∥` (in pseudocode) | Parallel execution |
| `⇒` vs `→` | `⇒` for "leads to" (temporal), `→` for function notation |

---

## Revision Checklist

### For Section 1 (Introduction)
- [ ] Replace "the cache" with `cache(f)` when specific
- [ ] Replace "version counter" with `gen_f` or `gen_global` (be specific)
- [ ] Define CallSet in intro preview (forward reference to Def. 3.1)

### For Section 2 (Formal Framework)
- [ ] Add Definition 2.1 (Safe predicate)
- [ ] Add Definition 2.2 (Deterministic)
- [ ] Add Definition 2.3 (CallSet)
- [ ] Update Theorem 2.2 statement to include `safe(p)` assumption
- [ ] Use `cache(f)`, `key(args, gen_f)`, `C[k]` notation consistently

### For Section 3 (Hybrid Invalidation)
- [ ] Add Definition 3.1 (CallSet analysis algorithm)
- [ ] Add Theorem 3.1 proof using `CallSet(f)` notation
- [ ] Replace "version counter" with `gen_f` consistently
- [ ] Define `gen_global` (deprecated) vs. `gen_f` (recommended)

### For Section 4 (Empirical Validation)
- [ ] Use `hit-rate(workload)` notation instead of percentages
- [ ] Table 3: Add column header `gen_f usage` (yes/no)
- [ ] Reference Definition 2.1 when explaining why caching is safe

### For Section 5–8
- [ ] Consistent reference format: "Definition 2.1" not "Def 2.1"
- [ ] Use `safe(p)` notation when discussing closures (Section 5)
- [ ] Section 7: Formalize "temporal locality" as ρ parameter to hit-rate model

---

## Implementation

These changes should be applied to:
1. `docs/DISPATCH_CACHING_PAPER_v4.md` (main paper)
2. Appendix (add Notation Glossary section)
3. `docs/OPERATIONAL_SEMANTICS.md` (newly created, already uses this notation)

**Estimated effort**: 2–3 hours to revise all sections with search-and-replace + verification.

---

## Example: Before and After

### Before (Current)
> "The version number in the cache key prevents invalid hits.
> When a method is added to a generic function, we increment the version.
> This causes predicates to recompute.
> The CallSet determines which caches to flush."

### After (Standardized)
> "The cache key `k = (gen_f, class-of arg₁, ...)` includes the version `gen_f` for GF `f`.
> When a method is added to GF `f`, we increment `gen_f` (Definition 3.2).
> Subsequent lookups in `cache(f)` with old `gen_f` values miss the cache,
> forcing recomputation of the dispatch decision.
> The CallSet analysis (Definition 3.1) identifies which other functions' caches may be affected."
