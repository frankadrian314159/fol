(ns asr-corpus.classify-asr
  "A gate-faithful Pass 2 for FOL's own ASR (aggregate scalar replacement,
   record-accumulator) mechanism -- the CGO-2027 applicability claim (see
   docs/cgo2027/cgo2027.tex, sec:cand/sec:loop/sec:inline/sec:align).

   asr-corpus.analyze's :record/:record-strong categories are a
   SYNTACTIC-SHAPE proxy: init looks like a record constructor call, update
   looks like a constructor/assoc/helper call. This file instead ports the
   actual gates src/compiler.lisp's loop-carried-ASR pass applies, as
   closely as reader-level (non-macroexpanded) analysis of Clojure allows,
   and reports what fraction of sites the REAL rules would accept.

   Faithfulness to src/compiler.lisp (line numbers as of this port):
     - Candidate identification == %SR-TRY-ACCUMULATOR (4193-4226) +
       INFER-TYPE-FROM-CONSTRUCTOR (1448-1473) + %SR-CTOR-FIELDS/
       %SR-FIELDS-MATCH (3476-3495): a loop binding whose init is a call to
       a known record's constructor, supplying EXACTLY that record's field
       set. FOL's *GLOBAL-TYPE-INFO* registry is reader-level here: a
       project-wide map from record name to its ordered field-keyword
       vector, built from every (defrecord Name [f1 f2 ...] ...) /
       (deftype Name [f1 f2 ...] ...) form in the project (see
       `record-registry`) -- FOL's own registry is populated from defclass
       forms the same way, project-wide, not per-file.
     - Reconstruct (== EXPAND-ACC, compiler.lisp:4293-4481), tried in this
       order at the recur position: passthrough (bare alias) / explicit
       same-type constructor (full field set) / partial reconstruction via
       assoc (literal-keyword keys only, fields not mentioned keep their
       current field-variable value) / a single-form let-or-do wrapper
       peeled once, before (not inside) branch dispatch / if-branched
       reconstruction (both arms, no wrapper inside either arm) / cond-
       branched (every clause) / case-branched (every clause; the dispatch
       key itself is an ordinary sub-expression, not a reconstruction).
       Anything else disqualifies -- exactly EXPAND-ACC's `(t (fail))`.
     - Rewrite (== RW, compiler.lisp:4228-4258/4482-4584): a field read
       ((:k alias) or (get alias :k), a real field) is always fine; a bare
       accumulator reference is fine ONLY as this loop's own recur-position
       reconstruction (handled by Reconstruct) or, outside any nested loop,
       as the form's own tail expression (re-boxed) -- every other bare
       occurrence (argument to an arbitrary call, captured by a closure,
       stored in a literal, referenced from inside a DIFFERENT recur's
       argument, or read inside a nested loop that doesn't itself shadow
       the accumulator's name) disqualifies. A nested loop/let whose OWN
       binding name shadows the accumulator conservatively disqualifies
       the whole site (matches compiler.lisp:4528-4530/4559-4561's
       shadow-guard) rather than trying to reason about the shadowed
       scope.
     - Multi-accumulator: FOL's %SR-REPLACE-ONE fixpoint (4140-4191)
       unboxes qualifying bindings one at a time and re-scans, so each
       binding's OWN qualification is independent of any other binding's
       -- mirrored here by classifying every loop binding as its own
       candidate (site-verdict per binding), exactly loop-sites' own
       existing convention.

   Deliberate scope cuts (documented, not silently dropped -- each pushes
   the result toward an UNDERCOUNT relative to the real compiler.lisp gate,
   same direction/discipline as asr-corpus.classify's own caveats):
     - loop/loop* sites ONLY -- unlike the sibling classify.clj (whose
       transient technique has its own dedicated REDUCE-ACC-QUALIFIED-P/
       %LINEAR-REDUCE-LAMBDA predicate in escape-analysis.lisp), FOL's
       loop-carried ASR pass hooks the RECUR-NODE-P case specifically
       (compiler.lisp:4502-4516) -- it has no reduce-shaped analogue to
       port faithfully, so reduce/reduce-kv/reductions forms are not
       scanned by this file at all (analyze.clj's own reduce-site tally
       remains a syntactic-only proxy for those, same as it always was).
     - No macroexpansion (same reason as analyze.clj/classify.clj: no
       classpath at corpus scale) -- a defrecord/loop hidden behind a
       macro is invisible to the registry or the site walk.
     - No interprocedural inlining (FOL's sec:inline / *SR-INLINABLE-FNS*,
       compiler.lisp:3434-3517/4303-4374). A loop reconstructing its
       accumulator by calling a project-local helper is classified
       :usage-disqualified here exactly as an un-inlined FOL loop would be
       -- this is classify.clj's own documented precedent (\"No helper
       inlining\" in its docstring) for the identical reason: reader-level
       analysis has no reliable, corpus-scale way to resolve a call target
       to its own defn body and re-run this same walk against it. Purely
       an undercount, never an overcount.
     - Field reads recognize (:k alias), (get alias :k), and the
       zero-argument dot-interop accessor (.k alias) (`deftype`'s own
       idiomatic spelling, since a `deftype` -- unlike `defrecord` -- has
       no keyword-based accessor at all). A dot-accessor CALLED WITH
       ARGUMENTS, e.g. (.k alias other-arg), is not treated as a field
       read (that's a real method invocation, not a field access, and
       (.k alias) is syntactically indistinguishable at reader level from
       an arbitrary zero-arg interop call on an unrelated object of the
       same method name -- an unavoidable, direction-neutral imprecision
       shared with every other name-based match in this file).
     - `map->Name` is only credited when its sole argument is a literal
       map with EXACTLY the record's field keywords as keys -- a
       non-literal argument (a variable, a call) cannot be verified
       field-complete without running code, so it disqualifies, matching
       the \"no execution\" discipline every pass in this corpus study
       shares.

   Usage: clojure -M:classify-asr <corpus-dir> [manifest.edn] [out.edn]"
  (:require [clojure.tools.reader :as r]
            [clojure.tools.reader.reader-types :as rt]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]
            [clojure.set :as set]
            [clojure.pprint :as pp]))

;;; ------------------------------------------------------------------ reading

(defn read-forms
  "Read all top-level forms from a Clojure source file as data."
  [path]
  (let [rdr  (rt/indexing-push-back-reader (slurp path))
        opts {:eof ::eof :read-cond :allow :features #{:clj}}]
    (binding [r/*default-data-reader-fn* (fn [_tag v] v)
              r/*read-eval* false
              r/*suppress-read* true]
      (loop [acc []]
        (let [form (try (r/read opts rdr) (catch Throwable _ ::error))]
          (cond
            (identical? form ::eof)   {:forms acc :read-error false}
            (identical? form ::error) {:forms acc :read-error true}
            :else                     (recur (conj acc form))))))))

(defn clj-files [dir]
  (->> (file-seq (io/file dir))
       (filter #(.isFile ^java.io.File %))
       (map #(.getPath ^java.io.File %))
       (filter #(re-find #"\.clj[cs]?$" %))
       (remove #(re-find #"(?:^|[/\\])(?:target|\.git|node_modules|\.cpcache|out|resources)[/\\]"
                         %))))

(defn op-name [form]
  (when (and (seq? form) (seq form) (symbol? (first form)))
    (clojure.core/name (first form))))

(defn walk-sites
  "Pre-order walk of FORM calling (visit node) on every non-quoted subform."
  [form visit]
  (when-not (= "quote" (op-name form))
    (visit form)
    (doseq [c (cond (map? form) (mapcat identity form)
                    (coll? form) form
                    :else nil)]
      (walk-sites c visit))))

;;; --------------------------------------------------------- record registry
;;; == *GLOBAL-TYPE-INFO*, built reader-level and project-wide (compiler.lisp
;;; 1442, populated from defclass; here from defrecord/deftype). Field
;;; keywords are canonicalized the same way %SR-CANON-KEY does (compiler.lisp
;;; 3440-3442): upcased keyword-of-name, so a constructor's :x and the
;;; registry's :x compare equal regardless of reader case.

(defn canon-key [s]
  (keyword (str/upper-case (name s))))

(defn record-registry
  "Scan FORMS for defrecord/deftype and return {\"Name\" #{canon-key ...}}."
  [forms]
  (let [reg (volatile! {})]
    (doseq [top forms]
      (walk-sites top
        (fn [f]
          (when (and (#{"defrecord" "deftype"} (op-name f))
                     (symbol? (second f))
                     (vector? (nth f 2 nil))
                     (every? symbol? (nth f 2)))
            (let [nm (name (second f))
                  fields (into #{} (map canon-key) (nth f 2))]
              (vswap! reg assoc nm fields))))))
    @reg))

(defn ctor-target-name
  "If FORM's operator is a ->Name/map->Name/(Name. ...)/(new Name ...) call
   for a NAME present in REGISTRY, returns that Name string; else nil. ==
   INFER-TYPE-FROM-CONSTRUCTOR (compiler.lisp:1448-1473)."
  [form registry]
  (when (and (seq? form) (seq form) (symbol? (first form)))
    (let [op (name (first form))]
      (cond
        (and (str/starts-with? op "->") (contains? registry (subs op 2))) (subs op 2)
        (and (str/starts-with? op "map->") (contains? registry (subs op 5))) (subs op 5)
        (and (str/ends-with? op ".") (contains? registry (subs op 0 (dec (count op)))))
        (subs op 0 (dec (count op)))
        (and (= op "new") (symbol? (second form)) (contains? registry (name (second form))))
        (name (second form))
        :else nil))))

;;; ----------------------------------------------- constructor field-matching
;;; == %SR-CTOR-FIELDS + %SR-FIELDS-MATCH (compiler.lisp:3476-3495): the
;;; constructor call must supply EXACTLY the registry's field set, no more,
;;; no fewer. Positional (->Name .../Name. .../new Name ...) constructors are
;;; arity-fixed by Clojure itself (defrecord always generates exactly
;;; field-count positional params), so a syntactically well-formed call
;;; trivially satisfies this -- the check below only ever meaningfully
;;; rejects a map->Name call whose literal map doesn't exactly match, or (via
;;; the :incomplete-call branch) flags a positional call with the wrong
;;; argument count (a real, if rare, static-analysis-catchable defect)."

(defn ctor-fields-match?
  "True iff FORM (a recognized constructor call for TYPE-NAME, field set
   FIELDS) supplies exactly FIELDS -- see docstring above for per-shape
   rules; map->Name additionally requires a LITERAL map argument (a
   non-literal argument can't be verified field-complete without running
   code, see namespace docstring's scope-cut)."
  [form fields]
  (let [op (op-name form)
        args (rest form)]
    (cond
      (str/starts-with? op "map->")
      (and (= 1 (count args)) (map? (first args))
           (every? keyword? (keys (first args)))
           (= fields (into #{} (map canon-key) (keys (first args)))))

      :else ; ->Name / Name. / new Name -- positional, arity must equal field count
      (let [pos-args (if (= op "new") (rest args) args)]
        (= (count fields) (count pos-args))))))

;;; ------------------------------------------------------------- field reads
;;; == the `get`-of-alias dispatch inside RW (compiler.lisp:4239-4248,
;;; 4536-4541), extended to Clojure's own idiomatic (:k alias) accessor
;;; (which has no FOL analogue to cite, since FOL's own `get` IS the
;;; idiomatic spelling there).

(defn field-read?
  "True if FORM is (:k alias), (get alias :k), or the Java-interop dot-
   accessor (.k alias) (Clojure's own idiomatic spelling for a `deftype`
   field, which has no keyword-based accessor at all -- fastmath's own
   nested-loop Vec2 read, the paper's own real corpus example, uses this
   shape exactly: (.x rr)) -- where :k/k canonicalizes into FIELDS. ALIAS
   must be `=` to ACC-SYM exactly (no shadowing tracked at this leaf --
   shadowing is caught earlier, at binding-introduction sites, by
   `shadows?`)."
  [form acc-sym fields]
  (or
   (and (seq? form) (= 2 (count form)) (keyword? (first form))
        (= (second form) acc-sym) (contains? fields (canon-key (first form))))
   (and (seq? form) (= 3 (count form)) (= 'get (first form))
        (= (second form) acc-sym) (keyword? (nth form 2))
        (contains? fields (canon-key (nth form 2))))
   (and (seq? form) (= 2 (count form)) (symbol? (first form))
        (str/starts-with? (name (first form)) ".")
        (> (count (name (first form))) 1)
        (= (second form) acc-sym)
        (contains? fields (canon-key (subs (name (first form)) 1))))))

(defn shadows?
  [binding-form acc-sym]
  (cond
    (= binding-form acc-sym) true
    (coll? binding-form) (boolean (some #(shadows? % acc-sym) binding-form))
    :else false))

;;; ---------------------------------------------------------- Reconstruct
;;; == EXPAND-ACC (compiler.lisp:4293-4481). Returns {:ok? bool
;;; :others [...]} where OTHERS are every sub-expression RW must still scan
;;; for stray ACC-SYM escapes (constructor/assoc field-value expressions,
;;; branch test expressions, case dispatch key) -- mirroring `chain-kind`'s
;;; own :others convention in the sibling classify.clj.

(defn reconstruct
  [expr acc-sym registry fields type-name]
  (cond
    (= expr acc-sym) {:ok? true :others []}

    ;; single-form let/do wrapper peel, ONCE, before branch dispatch --
    ;; compiler.lisp:4409-4423, and (b) point 6/7's "no wrappers inside
    ;; branches" restriction is enforced simply by never re-entering this
    ;; peel from inside the if/cond/case cases below.
    (and (seq? expr) (seq expr) (contains? #{'let 'let*} (first expr))
         (= 1 (count (drop 2 expr))))
    (let [[_ bindings body] expr]
      (if (or (odd? (count bindings))
              (some #(shadows? (first %) acc-sym) (partition 2 bindings)))
        {:ok? false :others []}
        (let [inner (reconstruct body acc-sym registry fields type-name)]
          (if (:ok? inner)
            {:ok? true :others (into (mapv second (partition 2 bindings)) (:others inner))}
            {:ok? false :others []}))))

    (and (seq? expr) (seq expr) (= 'do (first expr)) (= 1 (count (rest expr))))
    (reconstruct (second expr) acc-sym registry fields type-name)

    ;; explicit same-type constructor, full field set
    (and (= (ctor-target-name expr registry) type-name)
         (ctor-fields-match? expr fields))
    {:ok? true :others (rest expr)}

    ;; partial reconstruction via assoc: literal-keyword keys only, on the
    ;; alias itself -- compiler.lisp:4385-4408
    (and (seq? expr) (seq expr) (= 'assoc (first expr)) (= (second expr) acc-sym)
         (let [kvs (drop 2 expr)]
           (and (even? (count kvs))
                (every? keyword? (take-nth 2 kvs))
                (every? #(contains? fields (canon-key %)) (take-nth 2 kvs)))))
    {:ok? true :others (take-nth 2 (drop 1 (drop 2 expr)))}

    ;; if-branched -- compiler.lisp:4424-4445; missing else = bare passthrough
    (and (seq? expr) (seq expr) (= 'if (first expr)) (<= 3 (count expr) 4))
    (let [[_ test then else] expr
          else (if (nil? else) acc-sym else)
          r1 (reconstruct then acc-sym registry fields type-name)
          r2 (reconstruct else acc-sym registry fields type-name)]
      (if (and (:ok? r1) (:ok? r2))
        {:ok? true :others (concat [test] (:others r1) (:others r2))}
        {:ok? false :others []}))

    ;; cond-branched -- compiler.lisp:4446-4461
    (and (seq? expr) (seq expr) (= 'cond (first expr)))
    (let [clauses (partition 2 (rest expr))]
      (if (empty? clauses)
        {:ok? false :others []}
        (let [rs (map (fn [[test res]]
                        [test (reconstruct res acc-sym registry fields type-name)])
                      clauses)]
          (if (every? (comp :ok? second) rs)
            {:ok? true :others (mapcat (fn [[test r]] (cons test (:others r))) rs)}
            {:ok? false :others []}))))

    ;; case-branched -- compiler.lisp:4462-4480; dispatch key is an ordinary
    ;; sub-expression (RW, not Reconstruct)
    (and (seq? expr) (seq expr) (= 'case (first expr)))
    (let [key-expr (second expr)
          rest-forms (drop 2 expr)
          has-default (odd? (count rest-forms))
          default (when has-default (last rest-forms))
          clause-pairs (partition 2 (if has-default (butlast rest-forms) rest-forms))
          results (map second clause-pairs)
          results (if has-default (concat results [default]) results)
          rs (map #(reconstruct % acc-sym registry fields type-name) results)]
      (if (every? :ok? rs)
        {:ok? true :others (cons key-expr (mapcat :others rs))}
        {:ok? false :others []}))

    :else {:ok? false :others []}))

;;; ------------------------------------------------------------------- Rewrite
;;; == RW (compiler.lisp:4228-4258, 4482-4584). Walks BODY (a seq of
;;; top-level loop-body forms; only the last is in tail position) for every
;;; use of ACC-SYM. RECUR-IDX is this binding's own position in the loop's
;;; binding vector, so a recur's reconstruction is matched by POSITION (RW
;;; knows this statically, unlike the sibling classify.clj's own
;;; content-based recur-arg matching, since ASR's recur arg for THIS
;;; accumulator is always at a fixed, known slot).

(def sanctioned #{:recur-update :recur-passthrough :exit-bare :read-ok})

(defn classify-uses
  "Returns {:uses #{...} :qualifies? bool}."
  [body acc-sym recur-idx registry fields type-name]
  (let [uses (volatile! [])
        record! (fn [k] (vswap! uses conj k))]
    (letfn
     [(walk-last-tail [forms tailp infn nested-p]
        (doseq [[i f] (map-indexed vector forms)]
          (walk f (and tailp (= i (dec (count forms)))) infn nested-p)))
      (walk-others [others infn nested-p]
        (doseq [o others] (walk o false infn nested-p)))
      (walk [f tailp infn nested-p]
        (cond
          (nil? f) nil

          (field-read? f acc-sym fields) (record! :read-ok)

          (= f acc-sym)
          (record! (cond infn :captured
                          (and tailp (not nested-p)) :exit-bare
                          :else :other-flow))

          (and (seq? f) (seq f) (= 'recur (first f)))
          (let [args (vec (rest f))]
            (if (and (not nested-p) (< recur-idx (count args)))
              (let [a (nth args recur-idx)]
                (if (= a acc-sym)
                  (record! :recur-passthrough)
                  (let [r (reconstruct a acc-sym registry fields type-name)]
                    (if (:ok? r)
                      (do (record! :recur-update) (walk-others (:others r) infn nested-p))
                      (record! :recur-reconstruct-fail))))
                (doseq [[i a] (map-indexed vector args) :when (not= i recur-idx)]
                  (walk a false infn nested-p)))
              (doseq [a args] (walk a false infn nested-p))))

          (and (seq? f) (seq f) (= 'if (first f)))
          (let [[_ test then else] f]
            (walk test false infn nested-p)
            (walk then tailp infn nested-p)
            (when else (walk else tailp infn nested-p)))

          (and (seq? f) (seq f) (= 'do (first f)))
          (walk-last-tail (rest f) tailp infn nested-p)

          (and (seq? f) (seq f) (contains? #{'let 'let*} (first f)))
          (let [[_ bindings & bodyf] f]
            (if (odd? (count bindings))
              (record! :other-flow)
              (let [pairs (partition 2 bindings)
                    shadowed (some #(shadows? (first %) acc-sym) pairs)]
                (doseq [[_ init] pairs] (walk init false infn nested-p))
                (if shadowed
                  (record! :shadowed-bind)
                  (walk-last-tail bodyf tailp infn nested-p)))))

          (and (seq? f) (seq f) (= 'cond (first f)))
          (doseq [[test res] (partition 2 (rest f))]
            (when (and (not= test :else) (not= test 'true))
              (walk test false infn nested-p))
            (walk res tailp infn nested-p))

          (and (seq? f) (seq f) (= 'case (first f)))
          (let [key-expr (second f)
                rest-forms (drop 2 f)
                has-default (odd? (count rest-forms))
                default (when has-default (last rest-forms))
                clause-pairs (partition 2 (if has-default (butlast rest-forms) rest-forms))]
            (walk key-expr false infn nested-p)
            (doseq [[_ res] clause-pairs] (walk res tailp infn nested-p))
            (when has-default (walk default tailp infn nested-p)))

          (and (seq? f) (seq f) (contains? #{'when 'when-not} (first f)))
          (let [[_ test & bodyf] f]
            (walk test false infn nested-p)
            (walk-last-tail bodyf tailp infn nested-p))

          ;; nested loop/loop* -- compiler.lisp:4522-4535: reads allowed
          ;; (nested-p true suppresses tail-reboxing so a bare ref there
          ;; always fails), and a shadowing binding conservatively
          ;; disqualifies the WHOLE site rather than reasoning about the
          ;; shadowed scope.
          (and (seq? f) (seq f) (contains? #{'loop 'loop*} (first f)))
          (let [[_ bindings & bodyf] f]
            (if-not (and (vector? bindings) (even? (count bindings)))
              (record! :other-flow)
              (let [pairs (partition 2 bindings)]
                (doseq [[_ init] pairs] (walk init false infn nested-p))
                (if (some #(shadows? (first %) acc-sym) pairs)
                  (record! :shadowed-bind)
                  (walk-last-tail bodyf false infn true)))))

          ;; A fn literal whose OWN param list shadows acc-sym opens a
          ;; separate scope -- references inside its body mean something
          ;; else entirely, safe to skip without walking further (same
          ;; shadow-then-skip discipline as let/loop above). Otherwise,
          ;; walk the body for a genuine free-variable reference to
          ;; acc-sym (compiler.lisp's own "captured by a closure" rule) --
          ;; a fn literal that never mentions acc-sym at all is entirely
          ;; unrelated and must record nothing.
          (and (seq? f) (seq f) (contains? #{'fn 'fn*} (first f)))
          (let [after (rest f)
                after (if (symbol? (first after)) (rest after) after)
                params (first after)
                bodyf (rest after)]
            (cond
              (not (vector? params)) (record! :other-flow)
              (shadows? params acc-sym) nil
              (some #(shadows? % acc-sym) bodyf) (record! :captured)
              :else nil))

          (vector? f) (doseq [el f] (walk el false infn nested-p))
          (set? f) (doseq [el f] (walk el false infn nested-p))
          (map? f) (doseq [[k v] f] (walk k false infn nested-p) (walk v false infn nested-p))

          (and (seq? f) (seq f) (symbol? (first f)))
          (doseq [a (rest f)] (walk a false infn nested-p))

          (coll? f) (doseq [c f] (walk c false infn nested-p))

          :else nil))]
      (walk-last-tail (vec body) true false false))
    (let [u (set @uses)
          bad (remove sanctioned u)]
      {:uses u :qualifies? (and (contains? u :recur-update) (empty? bad))})))

;;; --------------------------------------------------------------- site verdict

(defn site-verdict
  "INIT is this binding's own pre-loop initializer form; BODY is the loop's
   body forms; ACC-SYM its own bound symbol; RECUR-IDX its own positional
   index in the binding vector; REGISTRY the project's record-name->fields
   map."
  [init body acc-sym recur-idx registry]
  (let [type-name (ctor-target-name init registry)]
    (cond
      (nil? type-name) {:verdict :no-record-init}
      (not (ctor-fields-match? init (registry type-name)))
      {:verdict :field-mismatch}
      :else
      (let [fields (registry type-name)
            {:keys [qualifies? uses]}
            (classify-uses body acc-sym recur-idx registry fields type-name)]
        (if qualifies?
          {:verdict :qualified}
          {:verdict :usage-disqualified :uses uses})))))

;;; --------------------------------------------------------------- site enumeration

(defn loop-sites
  [form registry]
  (let [binds (second form)]
    (when (and (vector? binds) (even? (count binds)))
      (let [pairs (partition 2 binds)
            body (drop 2 form)]
        (vec
         (for [[i [sym init]] (map-indexed vector pairs) :when (symbol? sym)]
           (site-verdict init body sym i registry)))))))

(defn form-verdict
  "Aggregate a LOOP form's per-binding verdicts into ONE record, the same
   granularity analyze.clj's SITE-TAGS uses (a form is 'a record site' if
   ANY of its bindings qualifies), so totals are directly comparable to the
   paper's existing '1,442 loop/reduce accumulator sites' denominator."
  [binding-verdicts]
  (if (empty? binding-verdicts)
    nil
    (let [reasons (map :verdict binding-verdicts)
          rank {:qualified 0 :usage-disqualified 1 :field-mismatch 2 :no-record-init 3}
          best (apply min-key rank reasons)]
      {:qualified? (= best :qualified) :reason best})))

(defn analyze-project
  [project domain dir]
  (let [files (clj-files dir)
        parsed (mapv read-forms files)
        registry (record-registry (mapcat :forms parsed))
        binding-verdicts (volatile! [])
        form-verdicts (volatile! [])]
    (doseq [{fs :forms} parsed, top fs]
      (walk-sites top
        (fn [f]
          (when (#{"loop" "loop*"} (op-name f))
            (let [vs (loop-sites f registry)]
              (doseq [v vs] (vswap! binding-verdicts conj v))
              (when-let [fv (form-verdict vs)] (vswap! form-verdicts conj fv)))))))
    {:project project :domain domain :files (count files)
     :read-errors (count (filter :read-error parsed))
     :record-types (count registry)
     :binding-verdicts @binding-verdicts
     :form-verdicts @form-verdicts}))

;;; ------------------------------------------------------------- aggregation

(defn tally [verdicts]
  (reduce (fn [m v] (update m (:verdict v) (fnil inc 0)))
          {:qualified 0 :no-record-init 0 :field-mismatch 0 :usage-disqualified 0}
          verdicts))

(defn tally-forms [form-verdicts]
  (reduce (fn [m v] (update m (:reason v) (fnil inc 0)))
          {:qualified 0 :no-record-init 0 :field-mismatch 0 :usage-disqualified 0}
          form-verdicts))

(defn pct [num den] (if (pos? den) (format "%.2f%%" (* 100.0 (/ (double num) den))) "n/a"))

(defn print-summary [stats]
  (let [all-b (mapcat :binding-verdicts stats)
        all-f (mapcat :form-verdicts stats)
        nb (count all-b)
        nf (count all-f)
        tb (tally all-b)
        tf (tally-forms all-f)]
    (println "\n========= Gate-faithful ASR classifier corpus study =========")
    (println (format "Projects: %d   Files: %d   Read errors: %d   Record types found: %d"
                     (count stats)
                     (reduce + (map :files stats))
                     (reduce + (map :read-errors stats))
                     (reduce + (map :record-types stats))))
    (println "\n--- Per-loop-FORM (comparable to analyze.clj's loop-site denominator: one entry per loop form, true if ANY binding qualifies) ---")
    (println (format "Loop forms classified: %d" nf))
    (println (format "  QUALIFIED (>=1 binding passes the real candidate+Reconstruct+Rewrite gates): %d (%s)"
                     (:qualified tf) (pct (:qualified tf) nf)))
    (println (format "  no record-shaped init only:                      %d (%s)"
                     (:no-record-init tf) (pct (:no-record-init tf) nf)))
    (println (format "  constructor doesn't supply exactly the field set: %d (%s)"
                     (:field-mismatch tf) (pct (:field-mismatch tf) nf)))
    (println (format "  usage walk disqualified (escape/capture/shadow/unrecognized reconstruction): %d (%s)"
                     (:usage-disqualified tf) (pct (:usage-disqualified tf) nf)))
    (println "\n--- Per-BINDING (finer-grained; one entry per accumulator candidate) ---")
    (println (format "Bindings classified: %d" nb))
    (println (format "  QUALIFIED: %d (%s)" (:qualified tb) (pct (:qualified tb) nb)))
    (println (format "  no-record-init: %d (%s)" (:no-record-init tb) (pct (:no-record-init tb) nb)))
    (println (format "  field-mismatch: %d (%s)" (:field-mismatch tb) (pct (:field-mismatch tb) nb)))
    (println (format "  usage-disqualified: %d (%s)" (:usage-disqualified tb) (pct (:usage-disqualified tb) nb)))
    (println "===============================================================\n")))

(defn -main [& [corpus-dir manifest-path out-path]]
  (let [corpus (or corpus-dir "corpus")
        manifest (edn/read-string (slurp (or manifest-path "manifest.edn")))
        dom-of (into {} (map (juxt :name :domain) (:repos manifest)))
        projects (->> (.listFiles (io/file corpus))
                      (filter #(.isDirectory ^java.io.File %))
                      (sort-by #(.getName ^java.io.File %)))
        stats (vec
               (for [d projects
                     :let [nm (.getName ^java.io.File d)]]
                 (do (binding [*out* *err*] (println "classifying" nm))
                     (analyze-project nm (get dom-of nm :unknown) (.getPath d)))))]
    (spit (or out-path "results-classify-asr.edn")
          (with-out-str
            (pp/pprint
             {:generated (str (java.time.Instant/now))
              :projects (mapv (fn [s] (update s :binding-verdicts
                                              (fn [vs] (mapv #(dissoc % :uses) vs))))
                              stats)})))
    (print-summary stats)
    (println "Wrote" (or out-path "results-classify-asr.edn"))
    (shutdown-agents)))
