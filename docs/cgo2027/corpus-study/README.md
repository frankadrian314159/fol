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
