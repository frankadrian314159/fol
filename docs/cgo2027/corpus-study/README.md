# ASR pattern corpus study (Clojure proxy for FOL)

Estimates how often the **aggregate-scalar-replacement (ASR) pattern** — a
persistent *record* carried as a loop accumulator and rebuilt each iteration —
occurs in real code, using a corpus of Clojure projects as a proxy for FOL.

FOL and Clojure share the constructs the pattern is built from (`defrecord` ≈
FOL `defclass`; identical `loop`/`recur`; `reduce`; `assoc`/`update`/`->Ctor`
rebuilds), so Clojure is the closest available proxy. **It is a proxy, not a
measurement of FOL**, and the numbers should be read with the caveats below.

## What counts as the pattern

For each `loop`/`recur` and each `reduce`/`reduce-kv`/`reductions`, we classify
every accumulator into one of:

- **(a) record accumulator, rebuilt** — init is a project-local record
  constructor (`->Name`, `map->Name`, `Name.`, `new Name`) **and** it is rebuilt
  at the back-edge via `assoc`/`update`/a constructor (**strong**), or passed
  into a helper call (**possible**). This is the ASR-addressable pattern.
- **(b) map accumulator, rebuilt** — a plain map (`{}`, `hash-map`, …). This is
  *transient-conversion* territory, not ASR.
- **(c) collection accumulator, grown** — vector/list/set (`[]`, `conj`, …).
  Also transients, not ASR.
- **(d) primitive-scalar loop** — all accumulators are numeric literals. This is
  the *hand-optimized* form: what a performance-aware programmer writes instead
  of threading a record. A high (d):(a) ratio is evidence the pattern is
  suppressed by its current cost.

We also split (a) by rebuild mechanism (constructor vs. `assoc`/`update`), since
FOL's current ASR fires on full reconstruction; and we report per-domain, since
the pattern concentrates in numeric/geometry/graphics code.

## Caveats (read before quoting any number)

1. **Proxy, not FOL.** Clojure ≠ FOL. Ecosystem maturity and idioms differ.
2. **Likely an undercount / lower bound.** Performance-aware Clojure deliberately
   avoids record accumulators in hot loops, using primitive `loop` locals (d)
   instead. The pattern is partly *suppressed by its current cost* — exactly the
   cost ASR removes. Read (a) as a floor and (d) as the suppressed demand.
3. **Syntactic, reader-level detection.** We read forms with
   `clojure.tools.reader` and match shapes; we do **not** macroexpand or run
   `tools.analyzer` (which would need every project's full classpath and would
   not scale across heterogeneous repos). Consequences:
   - We only recognize a record accumulator when its *init* is a syntactic
     constructor. A record produced by a helper (`(loop [p (make-thing)] …)`) is
     missed → undercount.
   - `(->Name …)` is assumed to be a record constructor for a `Name` defined in
     the same project; a same-named non-record function would be a false match
     (rare).
   - Macro-generated loops, syntax-quoted code, and unparseable files are noise;
     we count read failures for transparency.
4. **Addressable vs. covered.** (a) is the *addressable* pattern; the current ASR
   implementation's restrictions (every-field reconstruction, one-level inlining,
   no `if`-branched reconstruction) cover a subset. We report the constructor-vs-
   `assoc` split as a coverage proxy but do not claim exact firing rates.

## Usage

Requires a JVM, the Clojure CLI (`clojure`), and `git`.

```bash
cd docs/cgo2027/corpus-study

# 1. Fetch the corpus (clones repos into ./corpus, writes manifest.lock.edn
#    with the exact SHAs analyzed, for reproducibility).
clojure -M:fetch manifest.edn corpus

# 2. Analyze. Writes results.edn and prints a summary table.
clojure -M:analyze corpus manifest.edn results.edn
```

To reproduce an earlier run exactly, re-fetch from `manifest.lock.edn` (which
pins SHAs) instead of `manifest.edn`.

## Output

`results.edn` contains per-project and per-domain counts and the grand totals.
The printed summary reports, over all `loop`+`reduce` sites:

- total sites, and how many carry a record accumulator rebuilt each iteration
  (strong / possible);
- the (a)/(b)/(c)/(d) breakdown;
- the constructor-vs-`assoc` rebuild split;
- read-failure counts.

The headline number for the paper is **(a) as a fraction of loop/reduce sites,
and per KLOC**, reported per domain and overall, with the caveats above stated
explicitly and (d) reported alongside as the suppression signal.

## A second, gate-faithful pass (`classify.clj`) — for the PLDI 2027 paper

`analyze.clj` above (and the (b)/(c) categories it reports) is a **syntactic-
shape** proxy: it checks whether a loop/reduce accumulator's *init* looks
like a map/vector/set and its *update* looks like an `assoc`/`conj` call. It
does not check freshness, does not check that every use of the accumulator
is sanctioned, and does not check the per-representation op-gate. The PLDI
2027 paper ("Transients Without Tears") originally cited this proxy's (b)+(c)
total — 34.6% of 1,442 sites — as an *upper-bound, necessary-condition*
estimate of how often the transient-conversion pattern occurs in real code,
with the explicit caveat that "the qualifying fraction is smaller, by an
unmeasured amount."

`classify.clj` ports the actual gates `src/escape-analysis.lisp` and
`src/summaries.lisp` apply — chain recognition (`chain-kind`), tail-position-
sensitive usage classification (`classify-loop-param`), per-representation
op-gates, and the freshness rule (`transient-eligible-init-p`) — as closely
as reader-level (non-macroexpanded) Clojure analysis allows, and reports what
fraction of sites the *real* rules would actually accept. It is self-tested
(`selftest/classify_selftest.clj`) against cases mirroring the paper's own
worked examples, including a hand-check that its verdict on the paper's own
DVI-style helper-threading example matches §7's admission that FOL itself
does not convert that pattern.

```bash
clojure -M:classify corpus manifest.edn results-classify.edn
```

Run against the same locked corpus (29 projects, 2,905 files, manifest.lock.edn),
this measures — not merely bounds — the qualifying fraction:

| granularity | sites | qualified | vs. syntactic-shape proxy |
|---|---|---|---|
| per loop/reduce **form** (comparable to analyze.clj's 1,442) | 1,166 | 102 (8.75%) | proxy said 34.6% |
| per accumulator **binding** (finer-grained) | 1,830 | 105 (5.74%) | — |

The dominant disqualifying reason by far is **freshness**, not chain shape or
op-gate mismatch (0% op-gate failures): 76–84% of syntactically map/vector/
set-shaped accumulators fail because their init is not a literal or a known-
fresh stdlib constructor call — they are threaded from an existing
collection (a function parameter, a `vec`/`into`/`merge` result, a helper
call), which the technique's freshness precondition cannot reach regardless
of how clean the update chain is. This is a real, corpus-measured version of
the "quicksort-swap"-style refusal the paper demonstrates by hand in §6.

**Not all of that 76–84% means the same thing, though.** `init-nonfresh-reason`
(`classify.clj`) categorizes *why* each no-fresh-init binding failed:

- **`:aliased-reference`** — the init is a bare variable/parameter (exactly
  the quicksort-swap shape). This is **structurally unfixable**: the value
  comes from outside the loop by construction, so no amount of extending
  *this* analysis could ever prove it fresh.
- **`:nonfresh-stdlib-call`** / **`:helper-call`** — the init is a call FOL's
  Tier-1 table doesn't credit as fresh (`vec`, `into`, `merge`, ...) or a
  project-local constructor. These are **analysis gaps**: the value may well
  *be* fresh at runtime, just not provably so by this classifier — headroom
  for a more thorough Tier-1 table or Tier-2 inference (§`sec:tier2`), not a
  fundamental limit.
- **`:other`** — neither of the above; mostly non-collection scalar loop
  counters swept up by classifying every binding in a loop form (e.g. the
  `i` in `(loop [acc {} i 0] ...)`), noise for this question, not a failed
  accumulation attempt.

Excluding `:other` (425 of 1,537 no-fresh-init bindings, 28%) as noise, the
remaining 1,112 genuine collection-init failures split roughly in half:
**574 (51.6%) are truly aliased** — the real structural ceiling — and
**538 (48.4%) are analysis gaps** (439 helper calls, 99 non-fresh stdlib
calls). Read together: aliased-mutation code is real and irreducible, but
it's roughly half of what freshness rules out, not the whole 76–84% — the
other half is headroom a more capable (not fundamentally different)
analysis could still capture.

**Read this number as a lower bound, for reasons documented in
`classify.clj`'s header, all pushing toward undercount (never overcount):**
1. No macroexpansion (same constraint as `analyze.clj`) — `when-let`/`if-let`
   bodies and macro-generated loops are invisible.
2. No helper inlining — a loop threading its accumulator through a
   project-local helper function is scored `:usage-disqualified` exactly as
   an un-inlined FOL loop would be (§`sec:chains`'s "DVI gap"), even though
   full FOL with helper inlining enabled might convert it.
3. No Tier-2 (inferred-summary) freshness for user-defined 0-ary
   constructors — only literals and stdlib constructors with a direct FOL
   Tier-1 analogue (`hash-map`, `vector`, `hash-set`) count as fresh, so
   `(loop [acc (make-thing) ...] ...)` is always scored `:no-fresh-init`
   here even though FOL's Tier-2 path (§`sec:tier2`, RQ3) can convert it.
4. Multi-arity `fn` literals, destructuring loop/reduce params, and
   `reduce-kv`'s 3-argument callback are treated as unrecognized shapes
   (conservatively non-qualifying), matching FOL's own `:pattern-param`/
   shadowed-bind conservatism — this is also why the per-form site count
   (1,166) is lower than `analyze.clj`'s 1,442: those forms are excluded
   from the denominator entirely rather than scored `:no-fresh-init`.

So the honest bracket for "how much of real Clojure code does the *actual*
classifier accept," given this corpus: **at least 5.7–8.75%, and at most
34.6%** (the syntactic-shape necessary condition). Both numbers are proxies
for FOL, not measurements of it (§`analyze.clj`'s caveat 1 applies equally
here); the FOL-specific mechanisms this port omits (helper inlining, Tier-2
constructor freshness) are exactly the mechanisms items 2–3 above describe,
so the true FOL-side fraction likely sits somewhat above 8.75% but well
below 34.6%.

## A third, gate-faithful pass for ASR itself (`classify_asr.clj`) — for the CGO 2027 paper

`classify.clj` above is gate-faithful for FOL's *transient*-conversion
mechanism (map/vector/set accumulators) — a different technique from the
one this paper is actually about. Until now, the CGO 2027 paper's own
record-accumulator pattern had **no** gate-faithful pass of its own: only
`analyze.clj`'s syntactic upper bound (8 of 1,442 sites, 0.55%) was
measured, and the "3 strong hits" reported in the paper's Discussion section were
hand-audited one at a time rather than gate-checked at corpus scale.
`classify_asr.clj` closes that gap: it ports the *actual* gates
`src/compiler.lisp`'s loop-carried ASR pass applies —
`INFER-TYPE-FROM-CONSTRUCTOR`/`%SR-CTOR-FIELDS`/`%SR-FIELDS-MATCH` for
candidate identification, `EXPAND-ACC`'s full reconstruction-shape
dispatch (constructor / `assoc` / single-form `let`-or-`do` peel /
`if`/`cond`/`case`-branched), and `RW`'s field-read/bare-escape/nested-
loop/shadow rules — as closely as reader-level (non-macroexpanded)
Clojure analysis allows. It is self-tested (`selftest/`
`classify_asr_selftest.clj`, 21 hand-authored cases) against direct/
`assoc`/branch-shaped/`let`-peeled reconstructions, dot-interop
(`deftype`) and keyword-style field reads, nested-loop reads and
shadowing, closure capture (including the two ways a `fn` literal
mentioning the accumulator's name can be *safe* — shadowing and
non-reference — vs. genuinely capturing it), and both disqualification
shapes (`field-mismatch`, `no-record-init`).

```bash
clojure -M:classify-asr corpus manifest.edn results-classify-asr.edn
```

Run against the same locked corpus (29 projects, 2,905 files), scoped to
`loop`/`loop*` forms only — FOL's loop-carried ASR pass hooks the
`RECUR-NODE-P` case specifically and has no `reduce`-shaped analogue to
port faithfully (unlike the transients technique, which has its own
dedicated `REDUCE-ACC-QUALIFIED-P`), so `reduce`/`reduce-kv`/`reductions`
forms are outside this pass's scope entirely, not scored:

| granularity | sites | qualified |
|---|---|---|
| per loop **form** | 678 | 1 (0.15%) |
| per accumulator **binding** (finer-grained) | 1,342 | 1 (0.07%) |

**The one qualifying site is a real, already-known result, not a new
find**: `fastmath/src/fastmath/fields/d.clj`'s `rr` (a `Vec2`)
accumulator, read inside a nested `loop` via the dot-interop accessor
`(.x rr)` — exactly the "nested-loop `Vec2` read" case
the paper's Discussion section already reports independently hand-ported and measured
(159× allocation reduction, 2.72× wall-time, Table `tab:reitit` row 3).
Finding *only* this one site, and no others, when the real gates are run
mechanically over the whole corpus rather than by hand, is a clean
confirmation that the paper's own hand-audit was complete for this
corpus, not merely representative.

**The other two of the three hand-audited "strong" hits do not qualify
under this pass, for two distinct, precise, corpus-verified reasons —
not because the pass is being lenient or because they're out of scope:**

- **`fastmath/src/fastmath/calculus.clj`'s Neville extrapolation**
  (`f0+err+invc`, a `Vec3`) is `:usage-disqualified`: its own outer
  `loop` reconstructs the accumulator via `(recur (m/inc i) nh minimal
  res)`, where `minimal`/`res` come from a nested `reductions` call and a
  `reduce` over its own result — neither a constructor call, an `assoc`,
  nor any other `EXPAND-ACC`-recognized shape, so this is the
  `reductions`-escapes fundamental limit Figure 1 in the paper's
  Discussion section already documents, now confirmed by running the
  real gate rather than asserted by inspection.
- **`datascript/src/datascript/pull_parser.cljc`'s pull-pattern
  accumulator** (`result`, a `PullPattern`) is `:field-mismatch`, a
  **more precise finding than "hidden behind a macro" alone**: reading
  the real `(defrecord PullPattern [attrs first-attr last-attr
  reverse-attrs wildcard?])` declaration (5 fields) against the loop's
  own pre-loop init, `(map->PullPattern {:attrs [] :reverse-attrs []
  :wildcard? nil})`, shows the init supplies only 3 of 5 fields —
  `%SR-FIELDS-MATCH`'s exact-field-set requirement would reject this
  candidate at the very first gate, before the macro-hidden `assoc`
  update (the limitation originally cited in the paper's Discussion
  section) is ever reached.
  This is consistent with, not contradicting, the paper's own
  methodology note that none of the nine hand-ported sites (CPython
  appendix) or these three (Clojure) port verbatim — the independently
  measured 11.6× speedup used an *adapted*, field-complete shape, not
  this exact call.

**Two more sites qualify as record-shaped candidates but correctly
disqualify for reasons unrelated to either finding above** (both
`data.avl`'s `AVLTransientMap.`-initialized accumulators, in the
`.clj` and `.cljs` sources of the same sorted-map-by builder): these use
`assoc!` (transient, in-place mutation) to update, and return the
accumulator wrapped in `(persistent! out)` rather than bare — genuinely a
*transient*-technique accumulator that happens to be built from a
`defrecord`-backed transient map type, not an ASR candidate at all, and
correctly declined for that reason rather than a false positive needing
explanation. And `datascript/src/datascript/query.cljc`'s `rel`
(a `Relation`) reconstructs via a helper call (`sum-rel`), the same
undercount-by-design "no interprocedural inlining" limitation
`classify.clj` already documents for the transients side.

**Read this number as faithful, not merely a lower bound**, with the
scope cuts below all pushing toward undercount, same discipline as
`classify.clj`'s own caveats:
1. No macroexpansion (same constraint as `analyze.clj`/`classify.clj`).
2. No interprocedural inlining — a loop reconstructing its accumulator
   through a project-local helper call is `:usage-disqualified` here
   exactly as an un-inlined FOL loop would be (confirmed live in this
   corpus: `datascript`'s `query.cljc`, above).
3. `map->Name` is only credited with a *literal* map argument supplying
   exactly the declared field set; a non-literal argument cannot be
   verified field-complete without running code.
4. `loop`/`loop*` only (see above) — `reduce`-shaped record accumulators
   remain a syntactic-only proxy via `analyze.clj`, since FOL's own ASR
   pass has no `reduce`-specific hook to port.

Combined with `analyze.clj`'s own syntactic upper bound (8 of 1,442
sites, 0.55%; scoped to `loop`/`reduce` together, of which 678 are
`loop`-only), the honest picture for ASR specifically, restricted to
`loop`/`loop*` sites: **the real, gate-faithful qualifying rate is 1 of
678 (0.15%)** — at the noise floor, exactly as the paper's Discussion
section's own hand-audit already concluded, now measured rather than
estimated from three manually-read examples.
