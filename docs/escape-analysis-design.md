# Escape and Uniqueness Analysis for FOL — Design Document

**Status**: In progress — Step 1 (summary vocabulary) implemented
**Target**: PLDI 2027 submission (deadline ~November 2026)
**Started**: 2026-07-03

---

## 1. Motivation

FOL's persistent-first semantics carry measured overheads of 7–114× versus mutable
CL on the benchmark suite (diff: 114×/55× memory; HSE: 23×; guards: 23×; DVI: 20×
with **900× memory** and O(N²) GC pressure; LSim: 7×). A large fraction of that
cost is allocation of intermediate values that are provably dead: functional
update chains, loop accumulators, temporary closures, and short-lived records.

One static analysis — escape + uniqueness inference — licenses a family of
optimizations ("clients"):

| Client | Property needed | Mechanism |
|---|---|---|
| Transient conversion of update chains / loop accumulators | uniqueness-at-death | rewrite `assoc`→`assoc!` inside a `transient`/`persistent!` region |
| Stack allocation | non-escape | emit `(declare (dynamic-extent x))`; SBCL does the rest |
| Scalar replacement of records | non-escape | delete the allocation, bind fields as locals |
| Multiple-values returns | non-escape past destructuring | compile returned tuples to CL `values` |
| Closure-capture safety for dispatch caching | non-escape of captured mutables | discharges the documented caching caveat |
| Node reuse (Perceus-style, future) | node-level uniqueness | in-place trie node mutation |

The paper framing: **one analysis, formalized once, evaluated across clients** —
FBIP-class in-place reuse *without ownership types*, in a latently-typed language
with CLOS dispatch and live redefinition.

## 2. The two properties

- **Escape** (may-property): can the value be reached after its scope exits —
  via return, storage into a reachable structure, closure capture, or a thread
  boundary?
- **Uniqueness-at-death** (must-property): at this program point, is this
  variable the only live reference, and is this its last use?

Structurally: `uniqueness-at-death = freshness ∧ no-aliasing ∧ liveness`, all
computable in one pass over one lattice. One analysis, two queries.

## 3. Abstraction

**Intraprocedural, flow-sensitive abstract state per variable, computed on the
FOL AST between parse and emit. All interprocedural knowledge comes from
summaries (§4), never from analysis of callee bodies.**

Per-variable lattice:

```
:unused  <  :fresh  <  :shared-local  <  :escaped
```

plus a per-use-site `last-use?` bit from a backward liveness pass.
`:fresh ∧ last-use` ⇒ unique-at-death. `≤ :shared-local` ⇒ non-escaping.

Rejected alternatives:
- *Whole-program points-to*: there is no whole program — FOL compiles per
  top-level form, REPL-style, and generic functions grow methods at runtime.
- *Julia-style inferred interprocedural summaries with backedge invalidation*:
  correct but heavy; §6 shows a cheaper layering captures the wins.

### 3.1 The root-level convention (important)

The analysis tracks **collection roots**, not interior nodes or elements.
Rationale: persistent operations (`assoc`, `rest`, `conj`) build a *fresh root*
that references the argument's *children*, never the argument's root object
itself. So at root granularity, most stdlib operations retain nothing.

This is sound for every client because:
1. **Transient client**: the transient protocol is edit-tagged copy-on-write —
   shared interior nodes are copied on first write, never mutated. Root-level
   uniqueness of the variable is exactly the precondition the protocol needs.
2. **dynamic-extent / scalar replacement**: apply to the root object bound to
   the variable; children are independent heap objects.
3. **Elements are never mutated by any client** — trie surgery replaces
   references, it does not write into elements.

The one client that needs *node-level* uniqueness is Perceus-style raw node
reuse; that is future work and will require a `:fresh-deep` refinement.

### 3.2 Transfer functions (sketch)

- **Bindings**: RHS is a literal collection / constructor / call with
  `returns-fresh-p` → `:fresh`. RHS is a variable reference → both names drop
  to `:shared-local`.
- **Calls**: consult the callee summary; apply per-argument effects (§4). No
  summary or `barrier-p` → all arguments `:escaped`.
- **Closures (`fn-node`)**: v1 — every captured variable → `:escaped`.
  Refinement (phase 2): captures survive if the closure is itself `:fresh` and
  flows only into `:invoked` positions of summarized HOFs.
- **`loop/recur`**: loop params seeded from inits; body iterated to a fixed
  point (lattice height 3 ⇒ ≤4 iterations). At each `recur`, the incoming
  accumulator value is dead after rebinding — uniqueness telescopes through
  iterations. This is the DVI/LSim accumulation pattern.
- **Return position, `def`, thread-spawn** → `:escaped`.
- **`eval` / `compile-form`** → barrier: everything in scope `:escaped`.

Results live in a side table (`eq` hash on AST node identity), not in new
slots on `ast-node`.

### 3.3 Transient-client usage restriction (updated for step 3.5)

Since step 3.5, dict and vector transients are **edit-tagged in-place
structures** (`<transient-dict>`/`<transient-vector>` over the token-COW
`transient-hamt` and `transient-%vec-t` primitives) with O(1)/O(32)
boundaries and mid-session read support (`get`/`nth`/`count`/`size`/`empty?`).
The usage restriction is therefore per-representation, enforced by
`init-supports-p` at conversion time:
- **dict**: writes {assoc!, dissoc!}, whitelisted reads OK
- **vector**: writes {conj!}, whitelisted reads OK
- **set** (still a wrapper representation): writes {conj!, disj!}, no reads

Reads are sanctioned only when the accumulator is the *collection* argument
(position 0) of a whitelisted op — an accumulator used as a key or default
would change value semantics. The historical audit obligation (verify bang
ops genuinely mutate) was discharged 2026-07-03/04 with ownership tests:
sources are preserved across transient generations.

## 4. Summaries and the three tiers

A summary describes what a callee does with each argument:

```lisp
(defstruct escape-summary
  name            ; string, for reporting
  param-effects   ; simple-vector of :none | :invoked | :shared-with-result | :retained
  rest-effect     ; effect for &rest args (nil = extra args default to :retained)
  returns-fresh-p ; result is a fresh root, uniquely owned by the caller
  barrier-p)      ; may call eval/compile-form/defmethod → full barrier
```

Effect meanings (conservative linear order `:none < :invoked <
:shared-with-result < :retained`):
- `:none` — read only; neither stored nor reachable through the result.
- `:invoked` — called as a function but not retained (HOF parameters).
- `:shared-with-result` — reachable through the return value only (stored as an
  element, or possibly returned itself). Escapes iff the result escapes;
  v1 treats it as `:shared-local` on the argument.
- `:retained` — may be reachable from anywhere after the call. Argument
  `:escaped`.

Arity rule: arguments beyond `param-effects` use `rest-effect`; if there is no
`rest-effect`, they conservatively get `:retained`.

**Tier 0 — unknown calls**: every argument `:escaped`. Sound unconditionally.

**Tier 1 — the standard library** (`src/summaries.lisp`, ~55 hand-verified
entries): `assoc`, `conj`, `get`, `mapv`, `reduce`, arithmetic, comparisons,
predicates, string ops. Protected not by invalidation but by **SBCL package
locks** on the implementation packages — a locked definition cannot change, so
Tier-1 summaries cannot go stale. Note: `fol.core` itself **cannot** be locked
(transpiled user code interns and defines symbols there); the locks go on the
implementation packages (`fol.compiler.collection-functions` etc.).

**Tier-1 matching is by NAME, mirroring the compiler** (discovered during
step 2): `fol.core` exports *zero* symbols, so in user packages `assoc` reads
as `CL:ASSOC` and `conj` interns as a fresh package-local symbol. The FOL
compiler itself resolves stdlib calls by name at emit/load time (`emit-call`'s
`+standard-fol-functions+` uses `string-equal`; printed output re-reads in the
target package). `LOOKUP-SUMMARY` therefore matches by home package first,
then by symbol name (`*resolve-by-name*`), excluding names defined by the
current compilation unit (`*name-exclusions*`, bound from the compiler's
`*file-function-defs*` — the same precedence emit-call applies). The homonym
hazard of name matching is exactly the hazard the compilation model already
has; the analysis is faithful to it, not weaker than it.

**Tier 2 — user functions, by contract**: a `sealed` pragma promises no
redefinition; the compiler then infers and trusts the function's summary.
`letfn`-local functions are sealed automatically (CL `labels` — statically
closed by construction).

Deliberately absent from the base design: silently trusted inferred summaries
for arbitrary user code. That tier (L3) is what §6's machinery makes sound.

## 5. Soundness under redefinition

**Threat model**: `g` was optimized assuming summary S(f); `f` is redefined so
S(f) no longer holds; `g`'s compiled code stack-allocates or mutates something
that now escapes → memory corruption or silent wrong answers. The bar is
higher than the dispatch cache's (which at worst calls an old method).

### 5.1 Batch mode (the free case)

`compile-file` transpiles a whole file from one source snapshot; every summary
and every consumer come from the same snapshot, so staleness is impossible.
Batch-compiled, cold-loaded, non-self-modifying programs need **no guards at
all** (`*sealed-world*` flag skips guard emission). Runtime self-modification
(`eval`, runtime `defmethod`) is handled by the barrier rule; the theorem
carries a "does not redefine summarized functions at runtime" premise,
discharged syntactically for programs that avoid those forms.

### 5.2 Live image (the ladder)

The invariant: *every instruction of optimized code executes under a definition
world in which its summaries hold.* Mechanism — *world ages, implemented in the
transpiler*:

1. **Optimized regions with entry guards.** Optimize function bodies /
   loop bodies, emitted dual-path:
   `(if (car <region-cell>) <optimized> <fallback>)` — one load + branch,
   amortized over the region.
2. **World snapshot at region entry.** Inside a region, calls to summarized
   callees go through function objects captured at entry
   (`(let ((f# (fdefinition 'f))) … (funcall f# …))`), so a mid-region
   redefinition never reaches in-flight code. In-flight regions complete in
   their birth world; the next entry sees the new world. Snapshot calls also
   remove the per-call `fdefinition` load — roughly paying for the guard.
3. **Dependency map + monotonicity fast path.** Compile time records
   "region R consumed S(f)". Redefinition protocol: infer the new summary;
   if `summary<= new old`, swap and do nothing (the common case — measured as
   `*monotonic-redefs*`); else nil-out dependent region cells.
4. **Escaping closures**: compiled as their own guarded regions.
   Non-escaping closures (proved by the analysis itself) need nothing —
   they cannot outlive their region.
5. **Threads**: a region runs in its entry world; redefinitions become visible
   at the thread's next region boundary. Visibility latency, not unsoundness.

Implementation ladder (each rung sound alone):
**L-panic** (one global cell, any redefinition kills all optimized paths) →
**L-perfn** (per-region cells + dep map) → **L-mono** (fast path) →
**L-snapshot** (full world-age semantics + tripwire recompilation).
Rung 4 is cuttable if the deadline looms.

## 6. Theorem shape

Small-step semantics for the FOL core with an explicit heap; the analysis as an
abstract interpretation. Main lemma (*conservative escape*): if the analysis
judges `x` non-escaped at point *p*, no heap location reachable from outside
the frame refers to `x`'s value at *p*. Transient theorem: replacing a
persistent op on a unique-at-death value with its transient counterpart yields
a bisimilar program. Redefinition enters as world-indexing: a region is valid
in world *w* iff its summaries hold in *w*; guards ensure entry only when
valid; snapshots confine execution to the entry world. Cite and delta against
Belyakova et al., *World Age in Julia* (OOPSLA 2020): our protected facts are
escape/uniqueness summaries, we add the monotonicity fast path, and the
analysis proves its own deoptimization boundaries (closures).

## 7. File inventory

| File | Contents | Status |
|---|---|---|
| `src/summaries.lisp` | summary struct, effect lattice, Tier-1 table, name resolution, package locks, transient op map | **done (steps 1–2)** |
| `src/escape-analysis.lisp` | AST traversal, tail-sensitive accumulator classifier, chain recognition, audit mode | **done (step 2)** |
| `src/world.lisp` | region cells, dep map, redefinition protocol, worlds | step 4 |
| `src/compiler.lisp` changes | audit hook **done**; `emit-guarded-region`, snapshot calls, client gating pending | steps 3–5 |
| `src/transients.lisp` audit | verify `!`-ops mutate/CoW rather than copy | step 3 gate |
| `src/tests/test-escape-summaries.lisp` | vocabulary + name-resolution tests | **done** |
| `src/tests/test-escape-analysis.lisp` | classifier/chain/coverage tests (35 checks) | **done (step 2)** |
| `src/tests/test-redefinition-soundness.lisp` | adversarial staleness suite | step 4 |

## 8. Build order and decision gates

1. ✅ **Vocabulary** (`summaries.lisp`).
2. ✅ **Analysis in audit mode** (2026-07-03). Audit results:
   - **LSim** (lsim.fol + lsim-pq.fol + 32x32x32 circuit): 70 functions,
     17 loops, 9 accumulator candidates, **8 qualified**. Tier-1 covers 54.8%
     of 542 call sites; residual Tier-0 is genuine user code. The one
     disqualification is the hot one: `lh-pop-batch`'s `acc` exits inside a
     vector literal `[acc q]` — a precision gap (§8.1 item 1), not unsafety.
   - **DVI**: 0 candidates — the accumulation is *interprocedural*
     (`loop → add-item → assoc`) and the accumulator is *read* every
     iteration (`cart-total`, `sum-reads`). Intraprocedural chain rewriting
     cannot capture DVI; it needs Tier-2 summaries + reads-capable
     (edit-tagged) transients, or scalar replacement of the record.
   - **Decision-gate verdict**: proceed, with the step-3 scope revised to
     include the reduce-lambda client (§8.1), because LSim's *hot* path
     accumulates through `reduce` lambdas, not `loop/recur`.
3. ✅ **Transient client** (2026-07-03). Implemented, opt-in via
   `fol.compiler.escape-analysis:*transient-loops*` (default OFF; sound under
   batch-compilation assumptions until step-4 guards land):
   - **Transients gate passed**: `conj!`/`assoc!`/`persistent!` round-trips
     verified from CL for vector/dict/set; the persistent dict matches fresh
     `equal` strings (comparator-based), so the transient hash-table `:test
     'equal` is the correct match. Vector `assoc!` extended to append at
     `index == count` for persistent parity.
   - **Classifier extensions**: exit-position collection literals
     (`:exit-in-literal`), if-branched chains in `chain-kind`, plus two
     soundness tightenings the emit work exposed: `:recur-reset` (recur arg
     at own position not rooted at the accumulator) and
     `:recur-in-complex-context` (recur under node types the rewriter shares
     verbatim) — keeping classifier and rewriter aligned by construction.
   - **Loop client**: `maybe-transient-loop` called from `emit-loop`;
     qualifying accumulators with literal inits get `(transient init)`,
     bang-op chains at recur positions, `persistent!` at every exit
     (bare / chain / in-literal).
   - **Reduce client**: `maybe-transient-reduce` called from `emit-call`;
     `(reduce (fn [acc x] <linear>) <literal> coll)` becomes
     `(persistent! (reduce (fn [acc x] <bang>) (transient <literal>) coll))`.
   - **Correctness**: 26 new checks, optimized == unoptimized on every
     shape (dict/vector loops, tuple exits, if-branches, `->` chains, reduce,
     plus non-conversion of read/reset/non-literal cases). Full suite
     **3,192 checks, 100%**.
   - **Micro-benchmarks** (SBCL, best of 3): dict loop 200k assocs **2.3×**
     (223→52 MB consed); vector loop 1M conjs **5.6×** (352→40 MB);
     reduce 500k conjs **5.05×** (183→28 MB).
   - **LSim re-audit: 9/9 accumulators qualify** (exit-in-literal unlocked
     `lh-pop-batch`); conversion dry-run over lsim + lsim-pq + 32x32x32
     circuit converts **6 loops + 6 reduces**, including the hot-path
     `get-input-states`. Qualified-but-unconverted params have variable
     (non-literal) inits — correctly skipped.
   - **End-to-end validation (8bit-100 and 8x32-900, 2026-07-03)**:
     simulation results **byte-identical** with the flag on (876 and 281,248
     gate evals; histories string-identical), 2 loops + 2 reduces converted
     in the engine. Performance **neutral** (0.97–0.99×, within noise).
     Diagnosis: LSim's converted accumulators are *small-N per boundary*
     (2–3 entries per `get-input-states` call, a few events per batch) —
     the wrapper transient's O(n) copy-in/copy-out boundary cost cancels the
     per-op savings that dominate at large N (micro-benchmarks: 2.3–5.6× at
     200k–1M ops per boundary). Batch/fan-in size doesn't grow with circuit
     size, so this holds at every scale.
   - **Implication (step-3.5 candidate)**: LSim-class wins require
     **edit-tagged in-place transients** (transient = O(1) root wrap,
     persistent! = O(1) tag flip) replacing the wrapper representation —
     which also lifts the no-reads usage restriction and unlocks DVI-style
     read-heavy accumulators. Alternative/complement: a profitability
     heuristic (runtime size threshold before choosing the transient path).

3.5. ✅ **Edit-tagged in-place transients** (2026-07-04). The primitive layer
   already existed (token-based COW `transient-hamt` + Clojure-style
   `transient-%vec-t` with owned tail); what was missing and added:
   - `find-node-transient`/`hamt-get-transient` + `%transient-vec-t-ref` —
     reads through in-progress transient nodes (plain `find-node` silently
     returns nil on edited subtrees).
   - `<transient-dict>`/`<transient-vector>` CLOS classes over the structs;
     `transient`/`persistent!`/bang methods rewired (O(1)/O(32) boundaries,
     freeze proportional to edited nodes). **Sets remain wrapper transients.**
   - Read methods on `get`/`nth`/`count`/`size`/`empty?` for both classes.
   - Classifier: `:read-ok` sanctioning — position-0 argument of a
     whitelisted read op (`+transient-readable-ops+`, kept in sync with the
     methods) or keyword accessor. Reads elsewhere (accumulator as key)
     still disqualify (value-semantics hazard).
   - **Per-init op gate** (`init-supports-p` + `*chain-ops*` collection in
     `chain-kind`): dict → {assoc!, dissoc!} + reads; vector → {conj!} +
     reads; set → {conj!, disj!}, no reads. Incompatible chains are left
     unconverted rather than failing at runtime.
   - Ownership soundness tested: sources preserved across generations,
     mid-session reads correct across tail boundaries. Suite **3,212
     checks, 100%**.
   - **Micro-benchmarks**: dict 200k **4.14×** (was 2.3× on wrapper; 223→26
     MB), vector 1M **7.52×** (was 5.6×; 352→32 MB); small-N 3-assoc-per-
     boundary **1.16×** (was neutral), small-N with reads **1.38×**
     (previously unconvertible).
   - **LSim end-to-end**: still byte-identical; 8bit-100 **1.02×**,
     8x32-900 **1.04×** and −106 MB/run (both were ~0.97–0.99× on wrapper).
   - **Remaining hot costs identified**: (a) `new-events`' nested reduce
     threads the outer accumulator as the inner reduce's *init* —
     `:escape-call` today; sanctioning "reduce-threaded" linear inits is the
     next precision step; (b) leftist-heap node churn (`lh-merge`/
     `lh-insert`) — Perceus-style node reuse territory, not transients.
4. ✅ **World machinery** (2026-07-04), `src/world.lisp` +
   `fol.compiler.world` package. Implemented rungs:
   - **Rung 1 (panic switch)**: `invalidate-all-regions`.
   - **Rung 2 (per-region cells + dependency map)**: converted loops and
     reduces are emitted **dual-path** —
     `(if (car (load-time-value (register-region '("ASSOC" ...)))) <optimized> <original>)`
     — with the cell indexed under every summarized name the conversion
     assumed (spine ops + sanctioned read ops + REDUCE, collected via
     `*chain-ops*`/`*read-ops*`). `note-redefinition` is emitted (in
     optimizer mode only, so flag-off output is unchanged) as a
     `prog1`-trailer on defn/defn-/definline/defmethod and fires at
     **load/eval time**, flipping exactly the dependent cells. In-flight
     iterations complete on their entry path — sound because converted
     regions touch the accumulator only through compiler-owned ops.
   - **Rung 3 (monotonic fast path)**: deferred to L3 — it needs user-summary
     inference; the per-name dependency map already gives "redefinitions of
     unassumed names invalidate nothing" (measured via `world-stats`).
   - **Rung 4 (snapshot calls + tripwire)**: future work.
   - `*sealed-world*` skips guards + notes for batch snapshots.
   - Verified: guarded fallback produces identical results after
     invalidation; defn eval notifies; LSim 8bit with guards **1.02×**,
     byte-identical (guard cost unmeasurable). Suite **3,229 checks, 100%**.
5. ✅ **Step 5** (2026-07-04): reduce init-threading + dynamic-extent
   closures. Suite **3,248 checks, 100%**.
   - **Reduce init-threading**: `chain-kind` now treats
     `(reduce (fn [a x] <linear>) <chain> coll)` as an `:update` chain link
     when the lambda qualifies under reduce-client rules and does not
     capture the outer accumulator (`%linear-reduce-lambda`); the rewriter
     rewrites the lambda in `:reduce` mode and threads the init spine.
     Inner-lambda ops/reads flow into `*chain-ops*`/`*read-ops*`, so the
     init-type gate applies transitively (`%reads-present-p`). This
     converts LSim's per-gate `new-events` nested reduce: **3 reduces
     convert** (was 2), allocation −180 MB/run (1.10× less) on 8x32-900,
     wall ~1.03×, results still byte-identical.
   - **Dynamic-extent closures** (`*stack-closures*`, opt-in): a literal
     `fn` at position 0 of a hand-verified non-retaining eager HOF
     (`+dx-invoked-ops+` = mapv/filterv/reduce/every/some — all verified to
     invoke-without-retaining, all fn-at-0 so hoisting preserves eval
     order) is bound with `(declare (dynamic-extent ...))`, world-guarded
     dual-path (a retaining redefinition would dangle a stack closure).
     Micro: eliminates exactly the closure allocation (−6.2 MB at 200k
     iterations), time-neutral; a size/frequency-proportional win.
   - **Deferred with rationale**: scalar replacement (needs Phase-2 type
     registry integration and a per-binding non-escape analysis — the
     lattice generalization); classifier closure read-refinement (reads of
     an accumulator inside `:invoked`-only closures — subsumed for the hot
     cases by init-threading); world rungs 3–4.

### 8.1 Emit-side work items (from the step-2 audit)

1. **Exit-position collection literals** (unlocks `lh-pop-batch`): an
   accumulator appearing directly inside a tail-position vector/dict literal
   is an exit use — wrap that occurrence in `persistent!` at emit. Small
   classifier extension + emit rule.
2. **Reduce-accumulator client** (unlocks LSim's hot path): recognize
   `(reduce (fn [acc x] ...) init coll)` where the lambda's accumulator
   parameter is linearly consumed by transient-safe ops into the lambda's
   return position — same classifier, with "recur at own position" replaced
   by "lambda tail position". LSim's per-gate `get-input-states` (assoc-
   reduce) and `new-events` (conj-reduce) match this shape.
3. **If-branched chains**: `(if p (conj a x) a)` in recur/lambda-return
   position — appears three times in LSim's hot path; extend `chain-kind`
   over `if-node` branches.
4. **Priority-3 emit machinery restoration**: `detect-accumulation-chain` /
   `emit-transient-accumulation` from commit 11fd8f8 were removed in cleanup;
   rebuild gated on the classifier verdicts.
Not addressable by transients: DVI's interprocedural read-heavy accumulator
(needs Tier-2 + edit-tagged transients, or scalar replacement), and LSim's
leftist-heap node churn (`lh-insert`/`lh-merge` — Perceus-style node reuse).

## 9. Open questions

- Node-level uniqueness (`:fresh-deep`) for the Perceus-style reuse client.
- Replacing wrapper transients with edit-tagged tries to relax the
  usage-restriction on converted regions.
- GF summary joins across methods with differing arities (current join pads
  conservatively; revisit when Tier-2 GF summaries land).
- Whether `not-empty`-style identity-returning functions merit a distinct
  `:returned` effect (v1 folds it into `:shared-with-result`).
