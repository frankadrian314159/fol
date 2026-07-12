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
