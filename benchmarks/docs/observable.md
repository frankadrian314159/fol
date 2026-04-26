# Observable Benchmark Analysis

## Overview
This report analyzes the **Observable** benchmark which implements a sensor monitoring system with change notifications. It compares a **FOL** implementation (`benchmarks/fol-code/observable.fol`) using persistent objects and predicate dispatch against a **Common Lisp** implementation (`benchmarks/lisp-code/observable.lisp`) using standard CLOS and manual dispatch.

---

## 1. Performance Benchmark
The benchmark executed **1,000,000 iterations** of a sensor update loop. Each iteration involves updating a sensor reading, calculating a change event, and routing that event through a notification system.

| Metric | Common Lisp (Optimized) | FOL (Transpiled) | Ratio (FOL/CL) |
| :--- | :--- | :--- | :--- |
| **Real Time** | 0.820 seconds | 3.838 seconds | **~4.68x** |
| **Bytes Consed** | 372.96 MB | 2,403.79 MB | **~6.45x** |

### Performance Analysis
- **Structural Sharing vs. Mutation**: The FOL implementation uses persistent data structures (HAMT-based dicts for change events, Sycamore hash-maps for persistent objects). The CL version uses mutable CLOS objects and structs, which are significantly faster for simple field updates.
- **Allocation Pressure**: FOL conses ~6x more than CL. This is expected as every "update" in FOL produces multiple new immutable maps (the change event, the result wrapper, and the new sensor state), whereas CL performs a shallow copy and in-place field mutation.
- **Dispatch Overhead**: FOL's `on-change` uses **Predicate Dispatch**, which involves running arbitrary logic (like `spike?` and `critical?`) during method selection. The CL version uses a hard-coded `cond` block.

---

## 2. LOC Analysis (Conciseness)
This analysis compares the source-level complexity of the implementations.

| Metric | FOL (`observable.fol`) | CL (`observable.lisp`) | Difference |
| :--- | :---: | :---: | :---: |
| **Total Lines** | 57 | 87 | -30 lines |
| **Blank Lines** | 8 | 14 | -6 lines |
| **Comments** | 4 | 21 | -17 lines |
| **SLOC (Logic)** | **45** | **52** | **-7 lines (-13%)** |

### Conciseness Analysis
- **Protocol Automation**: In FOL, the `update` protocol is more naturally expressed with functional `assoc` and `bind`, leading to a slightly more compact `updated` function.
- **Pattern Matching/Dispatch**: Predicate dispatch in FOL allows for cleaner separation of concerns in notification routing, although in this specific small-scale benchmark, the SLOC difference is modest (13%).
- **Boilerplate**: FOL's `defclass` and `defn` syntax reduces the noise of initargs and manual field copying required in the CL CLOS implementation.

---

## 3. Why These Patterns Are Inconvenient in CL and Clojure

The Observable benchmark combines two FOL features: **persistent objects** for
the sensor state and **predicate dispatch** for the notification routing
(`spike?`, `critical?`).  Each feature has a different story in CL and Clojure.

### Persistent Objects

**Common Lisp.**  CLOS objects are mutable by default.  Producing a new sensor
snapshot on each update requires an explicit copy, which every `update` function
must perform manually.  There is no language-level mechanism to make "update
returns a new value" the default; it is a discipline imposed by convention, not
by the type system.

**Clojure.**  Clojure records (`defrecord`) and maps are persistent; `assoc`
returns a new value automatically.  Persistent objects are the default, not the
exception.  This aspect of the pattern is equally convenient in Clojure.

### Predicate Dispatch

**Common Lisp.**  CLOS specializers are restricted to class names and
`(eql value)`.  Dispatching on arbitrary predicate functions (e.g., `spike?`,
`critical?`) is not supported.  The equivalent requires a `cond` block inside
one function:

```lisp
(defun on-change (event sensor)
  (cond ((spike?    event) (handle-spike    event sensor))
        ((critical? event) (handle-critical event sensor))
        (t                 (handle-normal   event sensor))))
```

Adding a new case (e.g., `overload?`) requires modifying this function.
Different modules cannot independently extend the dispatch.

**Clojure.**  `defmulti` is more flexible: the dispatch function is arbitrary
Clojure code, and `defmethod` can extend the multi-method from any namespace.
For two predicates the approach is workable:

```clojure
(defmulti on-change
  (fn [event sensor]
    (cond (spike?    event) :spike
          (critical? event) :critical
          :else             :normal)))

(defmethod on-change :spike    [event sensor] ...)
(defmethod on-change :critical [event sensor] ...)
(defmethod on-change :normal   [event sensor] ...)
```

The limitation surfaces when cases overlap or must be prioritised.  FOL's
predicate dispatch supports multiple overlapping predicates with an explicit
specificity ordering: a method that matches both `spike?` and `critical?` can
be declared more specific and will shadow the less-specific one.  Clojure's
`defmulti` dispatches on a single computed value and requires the `prefer-method`
mechanism for ordering, which must be declared explicitly for every overlapping
pair.  For complex event hierarchies with many overlapping predicates this
quickly becomes unmanageable.  FOL's predicate dispatch also does not require a
closed dispatch function: any module can add a `defmethod` with new predicates
without touching the original definition.

---

## 4. Conclusion
The Observable benchmark highlights the cost of **Full Immutability**. While FOL is roughly 4.7x slower than native CL/CLOS in this specific update-heavy workload, it provides **structural integrity** and **time-travel debugging** capabilities by default. For monitoring systems where audit trails and event sourcing are required, the performance trade-off is often acceptable in exchange for the safety of persistent state.
