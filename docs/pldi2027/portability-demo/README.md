# CL world-guard portability demo

Addresses the second half of the "Novelty, and why an open world" claim in
`docs/pldi2027/pldi2027.tex` (§7): that the paper's mechanisms — not FOL
itself — transfer to similarly-positioned languages. The paper only ever
exercises the world-guard mechanism (`src/world.lisp`) via FOL-generated
code; nothing in the paper shows it working outside the FOL transpiler.

`cl-world-guard-demo.lisp` is **ordinary, hand-written Common Lisp**. It is
not FOL source, and no FOL compiler pass touches it. A CL programmer, using
FOL's runtime as three ordinary Lisp packages —
`fol.compiler.collection-functions` (persistent ops), `fol.compiler.collections`
(the transient protocol), `fol.compiler.world` (the guard machinery) — applies
by hand the exact transformation §"The Rewriter" applies automatically to FOL
source, and gets the same soundness and performance properties.

## Scope: what this does and doesn't corroborate

The paper's contribution has two largely independent halves:

1. **The classifier** (chain-kind, op-gates, tail-position usage analysis,
   §"The Analysis") — walks a FOL AST. Inherently FOL-compiler-specific;
   this demo does not touch it. Portability of *this* half is instead
   addressed by `docs/cgo2027/corpus-study/classify.clj`, a from-scratch
   port of the same gates to Clojure source.
2. **The world-guard mechanism** (register-region / note-redefinition /
   region-valid-p, §"Soundness under Live Redefinition") — this demo's
   target. It consults nothing but a string key and a cons cell; it does no
   reflection on the function object being guarded, requires no AST, and (as
   this demo shows) requires no transpiler. It is exactly as general as the
   CLOS live-redefinition it guards against.

So: this demo corroborates that mechanism 2 is genuinely general-purpose CL
machinery, usable by a programmer who never runs the FOL compiler. It does
**not** show a second language's classifier finding real qualifying loops
(that's the corpus study's job), and it does not show the mechanism ported to
a language other than the one FOL already transpiles to — CL is FOL's own
host, not an independent second language the way Clojure is. Read it as
"the guard mechanism is not an artifact of code generation" rather than
"the whole system has been ported to CL."

## Why a demo-local `PASSOC`, not the real `ASSOC`

The demo process has the full `fol-compiler` system loaded (needed to reach
the collection/transient/world libraries at all), and FOL's own runtime is
itself written in terms of `fol.compiler.collection-functions:assoc`.
Redefining that shared generic live, in the same process, would risk
destabilizing unrelated FOL machinery for no evidentiary gain.
`NOTE-REDEFINITION` (`src/world.lisp`) consults only a **string key** — it
does no reflection on the function object — so redefining a demo-owned
generic registered under that same string key is behaviorally identical
evidence to redefining the real `ASSOC`, without the blast radius. `PASSOC`'s
own primary method simply delegates to the real `ASSOC`, so the workload
itself (the persistent dict, the transient protocol) is exactly FOL's actual
implementation throughout; only the *redefinition target* is demo-owned.

## Running it

```bash
cd src && sbcl --noinform --non-interactive \
  --eval "(push (truename \".\") asdf:*central-registry*)" \
  --eval "(asdf:load-system :fol-compiler)" \
  --load "../docs/pldi2027/portability-demo/cl-world-guard-demo.lisp"
```

## What it showed (one run, dev machine, illustrative not rigorous)

1. **Correctness**: the hand-guarded fast path (transient dict, 200k
   `assoc!` calls) produces a dict structurally identical to the naive
   persistent-`assoc` original, across all 200,000 keys.
2. **Performance**: 3.91× speedup on the fast path (best-of-3, single-call
   timing) — the same mechanism, same order of magnitude as the paper's
   RQ2 dict-loop figure (3.35×), though not a controlled comparison
   (different machine, no warm-up/cooldown protocol, single trial set).
3. **Redefinition → invalidation → fallback**, exactly RQ8's sequence, with
   zero FOL compiler involvement:
   - Before redefinition: `world-stats` shows 1 region registered, 0
     invalidated.
   - `PASSOC` is redefined live via `define-guarded-method`, a ~3-line macro
     standing in for the hook the FOL compiler installs automatically around
     every `defn`/`defmethod` — demonstrating that hook is not itself
     transpiler magic, just a wrapper a CL programmer could write once.
   - After redefinition: `world-stats` shows 1 invalidation, 1 redefinition
     noted, 1 redefinition that actually invalidated something; the
     region's validity cell flips to `NIL`.
   - The **next** call to the guarded function takes the slow path — the
     redefined `PASSOC`'s side-effect counter increases by exactly
     `2 × 200,000` (the always-slow-path `dict-loop/original` call plus the
     now-also-slow-path `dict-loop/guarded` call), mathematically confirming
     both calls reached the redefined function — and still produces a
     correct, structurally-matching result.

No step required generating code from FOL source, running the FOL parser,
or invoking `compile-form`. Everything above is a CL programmer's own code
against three library packages.
