---
marp: true
---

# FOL: A Functional Object Lisp
## Closing the Gap Between CLOS and Clojure

**Presenter:** Frank Adrian  
**Conference:** European Lisp Symposium 2026  
**Location:** Krakow, Poland

---

## The Vision: Best of Both Worlds

*   **CLOS:** 
    *   Powerful Metaobject Protocol (MOP)
    *   Extensible Method Combinations
    *   Constraint: Rooted in mutable state
*   **Clojure:**
    *   Persistent Data Structures
    *   Value-centric programming
    *   Constraint: Protocol-based dispatch lacks MOP introspection
*   **FOL:** Every object is a CLOS instance *and* a persistent record.

**Speaker Notes:** 
*   **The Problem:** Lisp has always had two powerful but separate "mountains": the CLOS/MOP mountain (imperative, meta-powerful) and the Clojure mountain (pure, functional, persistent). 
*   **The Idea:** FOL is a synthesis. It’s not just "Clojure in CL," but a rethink: what if the CLOS instance *itself* was the persistent record?
*   **Key Pitch:** We want the versioning power of Clojure (history, time-travel, safety) with the architectural "superpowers" of the CLOS MOP (introspective slots, method combinations, protocol extensions).

---

## Why Another Lisp?

*   **The Problem with Libraries:**
    *   `FSet` and friends provide structures but don't integrate easily with `defclass`.
    *   Standard CLOS `:around` methods can't easily roll back state.
*   **The FOL Approach:**
    *   Persistence is a property of the **Metaclass**, not the user code.
    *   Transparently intercepting slot access to ensure immutability.
    *   Enforcing invariants that library-based approaches in CL cannot guarantee.

**Speaker Notes:** 
*   **Context:** Most CL libraries for persistence (like FSet or libraries that wrap structs) require the developer to manually manage state or use a different set of macros. They feel "bolted on."
*   **MOP Advantage:** By using a custom metaclass, we change the "physics" of the object itself. Slot access isn't just memory access anymore; it's a meta-operation.
*   **Discipline vs. Enforcement:** In standard Lisp, persistence is "by convention" (don't use `setf`). In FOL, `setf` is a runtime error. This guarantees that your history is truly immutable, similar to how Clojure's core structures work.

---

## Internal Structures: The Hybrid Layout

*   **Identity vs. Value:**
    *   Identity refers to an **Epoch** (a specific version).
    *   `assoc` creates the "next" identity value.
*   **Storage Strategy ($T=8$):**
    *   **Native Path:** $\le 8$ slots use native CLOS slots (Speed).
    *   **Overflow Path:** $> 8$ slots utilize a Persistent Vector Trie (Scalability).
*   **Structural Sharing:** Only modified branches are reallocated.
*   **Collections:**
    *   Sets, Maps, Vectors: Persistent by default.
    *   Vectors: 32-way tries.
    *   Sets, Maps: 32-way HAMTs.
    *   Ordered collections: 32-way B-Trees.

**Speaker Notes:** 
*   **Hybrid Layout:** Why do we do this? Because a pure HAMT for every object is slow. If a class has 3 slots, building a 32-way trie is overkill.
*   **The 8-Slot Threshold:** We found that 8 is the "sweet spot." Below 8, we use native CLOS slots—fast even with the MOP overhead. Above 8, we transition to a HAMT to avoid $O(N)$ copy-on-write costs for wide objects.
*   **Structural Sharing:** Emphasize that when you `assoc` a wide object, you aren't copying the whole thing. You're path-copying a trie node. This is where the efficiency comes from.
*   **Collections:** Mention that our Vectors, Maps, and Sets are built using the same underlying primitive (HAMTs/Tries) to ensure consistent performance.

---

## FOL by Example

```lisp
;; Define a persistent class
(defclass <sensor> [] [[id] [val]])

;; Create and update
(def s1 (make <sensor> :id 101 :val 22.5))
(def s2 (assoc s1 :val 23.1)) ; s1 is unchanged

;; Multi-pattern predicate dispatch
(defn alert [({:keys [val]} (>= 35))
  (print "ALERT: Critical Temperature Exceeded! Shutting down system.")
  (shutdown-system)]
            [({:keys [val]} (< 35))
  (print "ALERT: Critical Temperature!")]
            [({:keys [val]} (< 30))
  (print "WARNING: Elevated Temperature!")]
            [({:keys [val]} (< 20))
  (print "Normal Temperature")])

;; Predicate dispatch on (obj (fn arg0 arg1 ...)) evaluates as (fn obj arg0 arg1 ...)


```

**Speaker Notes:** 
*   **Walkthrough:** Point out that `defclass` looks like CLOS, but `assoc` is the only way to "modify" it. 
*   **Syntax:** We borrowed Clojure's destructuring syntax (`{:keys [val]}`) because it's concise and readable. 
*   **Dispatch:** The `alert` example shows the real power: multiple dispatch where the "specializer" is a predicate (`(>= 30)`).
*   **Semantics:** Note that `(obj (pred))` is basically "shorthand" for a function call. It’s dynamic, it’s late-bound, and it’s extremely expressive.

---

## The Specificity Calculus

Predicate dispatch is undecidable in general. We solve this via:

**4-Level Category Precedence:**
1.  **Predicates:** `(x (even?))` (Highest)
2.  **Types:** `(x <integer>)`
3.  **Destructuring:** `[x y]`
4.  **Wildcards:** `x` (Lowest)

*   **Tie-breaking:** Definition order.
*   **Result:** Predictive, inspectable, and decidable dispatch.

**Speaker Notes:** 
*   **The Conflict:** Predicate dispatch is "The Holy Grail" of OO, but it's hard because logical subsumption (A implies B) is undecidable.
*   **The FOL Trade-off:** We use "Syntactic Specificity." Instead of proving logic, we look at the *form* of the constraint. 
*   **The 4 Levels:** Walk through them—Predicates are the most specific, Wildcards the least. 
*   **Tie-breaking:** We use definition order. It’s a "modularity hazard" (order matters), but it follows the Lisp tradition of interactive, iterative development.
*   **Result:** You get a system that is predictable. You can look at two patterns and know which one wins without needing a theorem prover.

---

## MOP Extensions for Persistence

*   **Intercepting the Protocol:**
    *   `slot-value-using-class`: Routes between Native/Trie.
    *   `(setf slot-value-using-class)`: Specialized on `persistent-class` to signal `mutation-error`.
*   **Bootstrap Safety:**
    *   `%metadata` and `%persistent-vector` slots remain native.
    *   Prevents infinite recursion in the introspection logic.

**Speaker Notes:** 
*   **Bootstrapping:** How do you implement persistence using a mutable MOP? You have to be careful. 
*   **Slot-Value-Using-Class:** This is where the magic happens. We specialization this generic function for our `persistent-class`. 
*   **Read Path:** We check slot index. If $< 8$, we read the native slot. If $> 8$, we look in the `%persistent-vector` (the hidden trie).
*   **Write Path:** We specialized the `(setf ...)` method to simply `error`. This is the "Immutability Guard."
*   **Native Anchors:** Explain that some slots (like the trie itself) *must* be native, otherwise the metaclass would try to `assoc` itself an infinite number of times.

---

## Lazy Schema Evolution

*   **Immutable Snapshots:** Existing instances are frozen Schema V1 records.
*   **JIT Migration:**
    *   Definitions can change (renames, additions).
    *   Functional updates (`assoc`) allocate Schema V2 instances.
    *   **`:alias` Protocol:** Renamed slots pull from legacy data during the copy.
*   **Safety:** Single-hop resolution only (Prevents $O(N)$ lookup chains).

**Speaker Notes:** 
*   **Immortal Snapshots:** In traditional CLOS, you change a class and all instances migrate (and potentially lose data). In FOL, a Schema V1 instance *is* a value. It never changes. 
*   **JIT Migration:** Migration is a "lazy" side effect of `assoc`. When you update a V1 instance, the new instance is allocated as a V2.
*   **Aliasing:** Mention `:alias reading`. It allows for smooth renaming without breaking old code that still has "old" snapshots.
*   **Architecture:** This approach turns "Database Migration" into "Function Application." It’s much safer for distributed or long-lived systems.

---

## Engineering the Threshold ($T=8$)

*   **The Micro-Overhead:**
    *   2 Native Slots: **33x** slower than `setf`.
    *   128 Slots: **447x** slower than `setf`.
*   **Why $T=8$?**
    *   HAMT path base-cost is ~106ns (4x native element copy).
    *   Object studies (Muschevici et al.) show 90% of classes have $\le 12$ fields.
    *   $T=8$ maximizes the "Native Fast Path" for the majority of use cases.

**Speaker Notes:** 
*   **Transparency:** Don't hide the cost. Persistence is a "tax." Construction and update are significantly slower than `setf`.
*   **Measurement:** We measured 33x–447x overhead. That sounds terrifying, but remember: we're comparing a complex meta-dispatch + trie-copy against a single memory write.
*   **Why 8?** Cite the Muschevici study. Most objects are small. By making 8 slots native, we ensure that the "Common Case" survives the tax with only the construction/dispatch penalty, not the trie penalty.
*   **Trie Construction:** Mention that building a HAMT path costs ~106ns, which is roughly the cost of copying 4-5 native slots. This is the engineering basis for the threshold.

---

## Suitability: The Performance Envelope

*   **When to AVOID FOL:**
    *   Tight imperative mutation loops (e.g., in-place Quicksort).
*   **When to USE FOL:**
    *   State-heavy logic (Simulations, Event Sourcing).
*   **The LSim Results:**
    *   4,000-gate simulation: **1.27x** parity with native CL.
    *   Memory Pressure: **0.59x** of CL (Structural sharing beats deep-copy).

**Speaker Notes:** 
*   **Adversarial Case:** In-place Quicksort is the "Best Way to Kill FOL." If your algorithm depends on thousands of tight mutations, don't use a pure persistent object. 
*   **The Escape Hatch:** Mention "Transients." They allow you to "unlock" an object, perform a batch of mutations at 5x overhead, and then "re-lock" it.
*   **The LSim Victory:** This is the key slide. In a large circuit simulation (4k gates), the overhead drops to 1.27x. Why? Because the time is spent in logic, not just allocation.
*   **Memory Pressure:** 0.59x bytes consed! Because we use structural sharing, we don't need to deep-copy the state for every tick of the simulation. This is a massive "win" for functional architectures.

---

## LLM Experience Report

*   **Agentic Pair-Programming:**
    *   **Successes:** HAMT implementation; generating 100+ sequence functions; property-based test suites.
    *   **Weakness:** High-level architectural consistency requires human "guardrails."
*   **The "Boilerplate Slayer":**
    *   Automating the `reducible` protocol across 19 collection types.
    *   Reducing development time for routine MOP specialization.

**Speaker Notes:** 
*   **The Workflow:** This project used an AI Agent (Antigravity). We treated it as a junior engineer/intern.
*   **Mechanical Wins:** It wrote the 100+ sequence functions (map, filter, reduce) across all 19 collections. This would have been weeks of boring work; it took hours.
*   **Architectural Guardrails:** The AI couldn't design the Specificity Calculus. It "hallucinated" complex logic but when directed with a simple category hierarchy, it could implement the dispatch logic perfectly.
*   **Testing:** Mention that we used the AI to generate property-based tests (Check-style). This caught many subtle HAMT bugs that manual testing missed.

---

## Conclusion

*   **FOL:** A successful synthesis of persistence and CLOS.
*   **Principle:** Persistence as a modular engineering cost.
*   **Future:**
    *   Parallel collections (Fork-join over tries).
    *   Native LLVM compiler backend.
    *   VSCode persistence debugger.

**Full Source:** `github.com/frankadrian314159/fol`

**Questions?**

**Speaker Notes:** 
*   **Summary:** FOL shows that functional and object-oriented paradigms aren't at war. They can be synergistic. 
*   **The MOP is Key:** The only reason we could do this so deeply is because of the Common Lisp Metaobject Protocol. No other language gives you this kind of "surgical access" to object internals.
*   **Future:** We’re moving towards a native LLVM compiler. Transpiling to SBCL is great for stability, but we want that 1.27x to become 1.0x.
*   **Closing:** "History is a value. You can have the power of the MOP and the safety of time."
