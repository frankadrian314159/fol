# FOL (Functional Object Lisp)

We present FOL (Functional Object Lisp), a Lisp dialect combining Clojure’s persistent data structures with CLOS-style object orientation.

Using this combination, we find that persistent objects and CLOS are not antagonistic but, in fact synergistic. Among other software capabilities, the combination yields metaobject-protocol-enabled versioned objects, declarative event sourcing using method combinations, and lazy schema evaluation - patterns more natural than in either parent alone. Benchmarks show that persistence adds only 1-3x overhead for sequential modifications. 

A preliminary transpiler to Common Lisp with minor optimizations reaches parity with hand-written Common Lisp code. FOL is written in Common Lisp using hand-coded persistent data structures—hash array mapped tries (HAMTs) for maps and sets, persistent vector tries for vectors, and B-trees for sorted collections—providing Clojure-compatible persistent collection objects and a meta-object-protocol adapted for immutable storage.

## Features

- **Immutability by default**: All objects and collections (except streams, atoms, etc.) are persistent, preserving previous versions after modification.
- **Structural sharing**: Updates create new versions sharing structure with old.
- **Object identity**: Distinguishes version identity (`eq`) from value equality (`=`).
- **Generic functions**: Multiple dispatch over destructuring patterns.
- **Meta-object protocol**: Introspection and extension via adapted MOP protocols.

## Examples

Below are a couple of small examples from the FOL benchmarks illustrating the syntax and capabilities of the language.

### Event Sourcing

FOL uses `:around` methods to declaratively intercept mutations and build an immutable event log, while predicate dispatch routes commands by content:

```clojure
(defclass <account> []
  [[balance :initform 0]
   [events  :initform []]])

(defn now [] (get-internal-run-time))

(defgeneric apply-command [agg cmd])

(defmethod apply-command :around [agg cmd]
  (bind [result (call-next-method)
         event  {:command cmd :timestamp (now)}]
    (assoc result :events (conj (get result :events) event))))

(defn deposit? [cmd] (= (get cmd :type) :deposit))
(defn withdraw? [cmd] (= (get cmd :type) :withdraw))

(defmethod apply-command
  ([agg (cmd (deposit?))]
   (assoc agg :balance (+ (get agg :balance) (get cmd :amount))))
  ([agg (cmd (withdraw?))]
   (assoc agg :balance (- (get agg :balance) (get cmd :amount)))))
```

### Observability

Another example from the `observable.fol` benchmark:

```clojure
(defclass <sensor> []
  [[name     :initarg :name]
   [reading  :initarg :reading  :initform 0]
   [status   :initarg :status   :initform :normal]])

(defn make-change [obj slot old-val new-val]
  {:object obj :slot slot :old old-val :new new-val})

(defn updated [obj snext new-val]
  (bind [old-val (get obj snext)
         new-obj (assoc obj snext new-val)]
    {:object new-obj
     :change (make-change obj snext old-val new-val)}))

(defn spike? [ch]
  (bind [change (get ch :change)]
    (and (= (get change :slot) :reading)
         (> (- (get change :new) (get change :old)) 50))))
         
(defgeneric on-change [change])

(defmethod on-change
  ([(c (spike?))]
   {:alert :spike
    :message (str "Spike detected: "
                  (get (get c :change) :old) " -> " (get (get c :change) :new))})
  ([c]
   {:alert :info
    :message (str "Slot " (get (get c :change) :slot)
                  " changed.")}))
```

## Running the Transpiler and Tests

### Tests

You can run the comprehensive test suite using the provided script at the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-tests.ps1
```

Or run the LSIM simulation using:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-lsim.ps1
```

### Transpiler

FOL code is typically compiled via the `fol.compiler` package. You can launch a standard Common Lisp environment (e.g. SBCL), load the environment, and use the transpiler by calling `(fol.compiler:compile-form ...)`.

For example, to view generated Common Lisp code from FOL code representations:

```lisp
(fol.compiler:compile-form '(def x 42)) 
;; => (DEFVAR X 42)
```

The transpiler is not production-ready and is only intended for research purposes. If you find any issues, please report them to the issue tracker. If you'd like to help, feel free to submit a pull request. Make sure that any pull requests are based on the latest master branch and provide tests for any new functionality.

Currently, work on FOL is supported by my personal research funds. If you find this project interesting, please consider supporting my research via [GoFundMe](https://www.gofundme.com/f/support-fol-advancing-functional-object-lisp).