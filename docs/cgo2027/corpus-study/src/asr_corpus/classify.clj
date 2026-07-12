(ns asr-corpus.classify
  "A second, GATE-FAITHFUL pass over the same Clojure corpus used by
   asr-corpus.analyze, for the PLDI-2027 'Transients Without Tears'
   applicability claim (see docs/pldi2027/pldi2027.tex, RQ 'Applicability
   beyond FOL').

   analyze.clj's :map/:coll categories are a SYNTACTIC-SHAPE proxy: init
   looks like a map/vector/set, update looks like an assoc/conj call. This
   file instead ports the actual gates src/escape-analysis.lisp applies --
   tail-position-sensitive usage classification (chain-kind), per-
   representation op-gates, and the freshness rule -- as closely as
   reader-level (non-macroexpanded) analysis of Clojure allows, and reports
   what fraction of sites the REAL rules would accept.

   Faithfulness to src/escape-analysis.lisp and src/summaries.lisp:
     - Spine ops = exactly FOL's *transient-op-map* keys: assoc, conj,
       dissoc, disj, pop (summaries.lisp:330-336).
     - Read-ok ops = exactly +transient-readable-ops+: get, nth, count,
       empty? ('size' has no idiomatic Clojure spelling, dropped).
     - Op-gates = exactly INIT-SUPPORTS-P (escape-analysis.lisp:873-896):
       dict {assoc,dissoc}+reads; vector {conj}+reads; set {conj,disj},
       NO reads at all.
     - Freshness = exactly TRANSIENT-ELIGIBLE-INIT-P: a literal, or a call
       whose *FOL* Tier-1 summary sets :returns-fresh-p. This is why
       `vec` and `into` -- both missing :returns-fresh-p in summaries.lisp
       -- are NOT treated as fresh here, even though analyze.clj's cruder
       classify-init counts `(into {} ...)` as :map. `hash-map`/`vector`/
       `hash-set` correspond to FOL's DICT/VECTOR/SET constructors, which
       DO set :returns-fresh-p, so they count.
     - The usage walk (classify-uses) mirrors CLASSIFY-LOOP-PARAM's `walk`:
       tail-position propagation through if/do/let/cond/when; recur
       handling (update / passthrough / reset / complex-context); bare
       exit, in-literal exit, and read-ok whitelist; closures and other
       flow disqualify.

   Deliberate scope cuts (documented, not silently dropped -- each pushes
   the result toward an UNDERCOUNT, same direction as analyze.clj's own
   caveats):
     - No macroexpansion (same reason as analyze.clj: no classpath at
       corpus scale). when-let/if-let/loop-destructuring bodies that only
       become visible post-expansion are missed.
     - No helper inlining (FOL's chain-inline / 'DVI gap' rule). A loop
       threading its accumulator through a user helper is classified
       :escape-call here exactly as an un-inlined FOL loop would be if
       helper inlining were disabled -- i.e. this UNDERCOUNTS relative to
       full FOL, not overcounts.
     - No Tier-2 (inferred-summary) freshness for user-defined 0-ary
       constructors; only literals and the handful of stdlib constructors
       with a direct FOL Tier-1 analogue count as fresh.
     - Multi-arity fn literals and destructuring loop/reduce params are
       treated as unrecognized shapes (conservatively non-qualifying),
       matching FOL's own :pattern-param / shadowed-bind conservatism.

   Usage: clojure -M:classify <corpus-dir> [manifest.edn] [out.edn]"
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

;;; --------------------------------------------------------------- op tables

(def spine-ops
  "== FOL *transient-op-map* keys (summaries.lisp:330-336)."
  #{"assoc" "conj" "dissoc" "disj" "pop"})

(def read-ops
  "== FOL +transient-readable-ops+ (escape-analysis.lisp:420), Clojure spellings."
  #{"get" "nth" "count" "empty?"})

(def gate-ops
  "== INIT-SUPPORTS-P (escape-analysis.lisp:873-896)."
  {:dict   #{"assoc" "dissoc"}
   :vector #{"conj"}
   :set    #{"conj" "disj"}})

(def gate-allows-reads? {:dict true :vector true :set false})

(defn op-name [form]
  (when (and (seq? form) (seq form) (symbol? (first form)))
    (clojure.core/name (first form))))

;;; ------------------------------------------------- init freshness/representation
;;; == TRANSIENT-ELIGIBLE-INIT-P + %INFER-RETURNS-KIND, restricted to the
;;; stdlib constructors that have a direct FOL Tier-1 analogue with
;;; :returns-fresh-p set. Deliberately NOT including `vec`/`into`/`list`/
;;; `sorted-map`/`sorted-set`/`zipmap`: none of FOL's VEC/INTO/LIST-adjacent
;;; summaries set :returns-fresh-p, and FOL has no op-gate for a list
;;; representation, so a faithful port must exclude them too.

(def fresh-ctor->repr
  {"hash-map" :dict "array-map" :dict
   "vector" :vector
   "hash-set" :set})

(defn init-repr
  "Representation of INIT if TRANSIENT-ELIGIBLE-INIT-P would accept it as a
   fresh root of known kind, else nil."
  [init]
  (cond
    (map? init) :dict
    (vector? init) :vector
    (set? init) :set
    :else (fresh-ctor->repr (op-name init))))

;;; --------------------------------------------------- why freshness failed
;;; For weakness-4-style scoping questions ("how much of this is genuinely
;;; unreachable vs. just an analysis gap"), NO-FRESH-INIT sites need a
;;; reason, not just a count. A bare variable reference as init is
;;; STRUCTURALLY aliased -- the loop's initial value is literally handed in
;;; from outside, so it can never be proven fresh by any static analysis,
;;; however extended (that's what "aliased" means). A call to a stdlib op
;;; this port doesn't credit as fresh, or to a project-local helper, is an
;;; ANALYSIS GAP: the value may well be fresh at runtime (e.g. `(into {}
;;; xs)`, a fresh-constructed 0-ary user function), just not provably so by
;;; this classifier (extending Tier-1's fresh-constructor table, or Tier-2
;;; inference for the helper case, could plausibly close it -- see RQ3).
;;; These are NOT the same claim, and conflating them overstates how much
;;; of real code is structurally out of reach for the technique as designed.

(def known-nonfresh-stdlib-ops
  "Clojure stdlib ops recognized by name but not credited as fresh (see
   fresh-ctor->repr's docstring: FOL's own Tier-1 summaries for the
   analogous ops don't set :returns-fresh-p either, so a faithful port
   can't credit them). A call to one of these is an analysis-gap case, not
   a structurally-aliased one."
  #{"vec" "into" "merge" "merge-with" "zipmap" "sorted-map" "sorted-map-by"
    "sorted-set" "sorted-set-by" "list" "list*" "concat" "select-keys"
    "assoc" "assoc-in" "dissoc" "update" "update-in" "conj" "disj"
    "str" "repeat" "range" "set" "frequencies" "group-by" "distinct"
    "filter" "remove" "map" "mapv" "reduce" "sort" "sort-by" "take" "drop"
    "partition" "partition-all" "flatten" "seq" "reverse"})

(defn init-nonfresh-reason
  "Categorizes why INIT-REPR returned nil for INIT:
     :aliased-reference   -- a bare variable/parameter -- structurally
                             unfixable, the value comes from outside the
                             loop by construction.
     :nonfresh-stdlib-call -- a call to a recognized-but-not-fresh-credited
                              stdlib op -- an analysis gap (Tier-1 extension
                              could plausibly close some fraction of these).
     :helper-call         -- a call to an unrecognized (project-local)
                              function -- an analysis gap (Tier-2 territory).
     :other               -- anything else (literal of unhandled shape,
                              nested conditional, etc.)."
  [init]
  (cond
    (symbol? init) :aliased-reference
    (and (seq? init) (seq init) (symbol? (first init))
         (contains? known-nonfresh-stdlib-ops (op-name init))) :nonfresh-stdlib-call
    (and (seq? init) (seq init) (symbol? (first init))) :helper-call
    :else :other))

;;; ---------------------------------------------------------------- chain-kind
;;; == CHAIN-KIND (escape-analysis.lisp:291-365), minus helper inlining.

(declare classify-uses)
(declare contains-recur?)

(defn free-ref?
  "True when FORM (a raw Clojure form) contains a reference to ACC-SYM
   outside of a nested binding form that shadows it. Deliberately coarse
   (does not track shadowing precisely) -- used only for the reduce-lambda
   non-capture check, where over-approximating 'contains a reference'
   toward false (missing a capture) would be unsound; toward true
   (flagging a capture that isn't really one) is merely conservative, the
   safe direction for a proxy."
  [form acc-sym]
  (cond
    (= form acc-sym) true
    (map? form) (boolean (some #(free-ref? % acc-sym) (mapcat identity form)))
    (coll? form) (boolean (some #(free-ref? % acc-sym) form))
    :else false))

(defn fn-literal?
  [f]
  (and (seq? f) (seq f) (contains? #{'fn 'fn*} (first f))))

(defn fn-single-arity-params
  "For a single-arity (fn [params...] body...) or (fn name [params...]
   body...) literal, returns [params body-forms]; nil for multi-arity or
   unrecognized shapes (conservatively unhandled, like FOL's :pattern-param)."
  [f]
  (let [after (rest f)
        after (if (symbol? (first after)) (rest after) after)]
    (when (vector? (first after))
      [(first after) (rest after)])))

(defn reduce-form?
  [expr]
  (and (seq? expr) (seq expr) (symbol? (first expr))
       (contains? #{"reduce" "reduce-kv"} (op-name expr))
       (= 3 (count (rest expr)))))

(defn linear-reduce-lambda-acc
  "== %LINEAR-REDUCE-LAMBDA. F is the callback in (reduce F init coll) or
   (reduce-kv F init coll). Returns the callback's own accumulator param
   symbol when it (a) is a plain 2-param fn (reduce) matching this
   restricted port's scope, (b) does not itself contain recur, (c) does not
   freely reference the outer ACC-SYM (no capture), and (d) its own body
   qualifies per REDUCE-ACC-QUALIFIED-P (classify-uses with recur
   disabled). Else nil."
  [f acc-sym]
  (when (fn-literal? f)
    (when-let [[params body] (fn-single-arity-params f)]
      (when (and (= 2 (count params)) (every? symbol? params))
        (let [a (first params)]
          (when (and (not= a acc-sym)
                     (not (contains-recur? body))
                     (or (some #(= % acc-sym) params)
                         (not (free-ref? body acc-sym))))
            (let [{:keys [qualifies? ops reads?]} (classify-uses body a false)]
              (when qualifies? {:acc a :ops ops :reads? reads?}))))))))

(defn contains-recur?
  [form]
  (cond
    (and (seq? form) (seq form) (= 'recur (first form))) true
    (map? form) (boolean (some contains-recur? (mapcat identity form)))
    (coll? form) (boolean (some contains-recur? form))
    :else false))

(defn chain-kind
  "== CHAIN-KIND. Returns {:kind :passthrough|:update|nil :ops #{...}
   :reads? bool :others [...]}. OTHERS are sub-expressions the caller must
   still scan for stray ACC-SYM uses (keys/values/test exprs)."
  [expr acc-sym]
  (cond
    (= expr acc-sym)
    {:kind :passthrough :ops #{} :reads? false :others []}

    (reduce-form? expr)
    (let [[_ f init _coll] expr
          root (chain-kind init acc-sym)]
      (if (nil? (:kind root))
        {:kind nil :ops #{} :reads? false :others []}
        (if-let [lin (linear-reduce-lambda-acc f acc-sym)]
          {:kind :update
           :ops (into (:ops root) (:ops lin))
           :reads? (or (:reads? root) (:reads? lin))
           :others (:others root)}
          {:kind nil :ops #{} :reads? false :others []})))

    (and (seq? expr) (seq expr) (symbol? (first expr))
         (contains? spine-ops (op-name expr))
         (seq (rest expr)))
    (let [op (op-name expr)
          args (rest expr)
          sub (chain-kind (first args) acc-sym)]
      (if (nil? (:kind sub))
        {:kind nil :ops #{} :reads? false :others []}
        {:kind :update
         :ops (conj (:ops sub) op)
         :reads? (:reads? sub)
         :others (concat (rest args) (:others sub))}))

    (and (seq? expr) (seq expr) (= '-> (first expr)))
    (let [forms (rest expr)]
      (if (empty? forms)
        {:kind nil :ops #{} :reads? false :others []}
        (let [sub (chain-kind (first forms) acc-sym)
              tail (rest forms)]
          (if (and (:kind sub)
                   (every? #(and (seq? %) (seq %) (symbol? (first %))
                                 (contains? spine-ops (op-name %)))
                           tail))
            {:kind :update
             :ops (into (:ops sub) (map op-name tail))
             :reads? (:reads? sub)
             :others (concat (mapcat rest tail) (:others sub))}
            {:kind nil :ops #{} :reads? false :others []}))))

    (and (seq? expr) (seq expr) (= 'if (first expr)) (<= 3 (count expr) 4))
    (let [[_ test then else] expr]
      (if (nil? else)
        {:kind nil :ops #{} :reads? false :others []}
        (let [k1 (chain-kind then acc-sym)]
          (if (nil? (:kind k1))
            {:kind nil :ops #{} :reads? false :others []}
            (let [k2 (chain-kind else acc-sym)]
              (if (nil? (:kind k2))
                {:kind nil :ops #{} :reads? false :others []}
                {:kind :update
                 :ops (into (:ops k1) (:ops k2))
                 :reads? (or (:reads? k1) (:reads? k2))
                 :others (concat [test] (:others k1) (:others k2))}))))))

    :else {:kind nil :ops #{} :reads? false :others []}))

;;; ------------------------------------------------------- usage classification
;;; == CLASSIFY-LOOP-PARAM's `walk`. Operates directly on raw Clojure forms;
;;; RECUR? controls whether a `recur` in tail position targets this
;;; accumulator (true for a real loop body; false when classifying a
;;; reduce-lambda body, mirroring REDUCE-ACC-QUALIFIED-P's synthetic
;;; recur-enabled wrapper collapsing to "no recur present" in practice).

(def sanctioned #{:recur-update :recur-passthrough :exit-bare :exit-update
                  :exit-in-literal :read-ok})

(defn shadows?
  [binding-form acc-sym]
  (cond
    (= binding-form acc-sym) true
    (coll? binding-form) (boolean (some #(shadows? % acc-sym) binding-form))
    :else false))

(defn classify-uses
  "Walk BODY (a seq of top-level forms in the loop/lambda body -- only the
   last is in tail position) for every use of ACC-SYM. Returns
   {:uses #{...} :qualifies? bool :ops #{spine ops seen} :reads? bool}."
  [body acc-sym recur?]
  (let [uses (volatile! [])
        ops (volatile! #{})
        reads? (volatile! false)
        record! (fn [k] (vswap! uses conj k))
        note-ops! (fn [chain] (vswap! ops into (:ops chain))
                    (when (:reads? chain) (vreset! reads? true)))]
    (letfn
     [(walk-last-tail [forms tailp infn recurp]
        (doseq [[i f] (map-indexed vector forms)]
          (walk f (and tailp (= i (dec (count forms)))) infn recurp)))
      (walk-others [others infn recurp]
        (doseq [o others] (walk o false infn recurp)))
      (walk [f tailp infn recurp]
        (cond
          (nil? f) nil

          (= f acc-sym)
          (record! (cond infn :captured tailp :exit-bare :else :other-flow))

          (and (seq? f) (seq f) (= 'recur (first f)))
          (if recurp
            ;; Reader-level limitation: we don't statically know ACC-SYM's
            ;; positional index in the loop/reduce binding vector the way
            ;; the FOL AST does, so instead of matching by position we
            ;; match by CONTENT -- any recur arg whose chain root is
            ;; ACC-SYM is treated as ACC-SYM's own update; an arg that is
            ;; exactly ACC-SYM is a passthrough. This slightly UNDERcounts
            ;; recur-reset (an unrelated recur arg happening to be some
            ;; other chain never gets blamed on ACC-SYM) but never
            ;; overcounts qualification, since a genuine ACC-SYM-rooted
            ;; recur arg is still found regardless of position.
            (let [args (rest f)
                  hit (some (fn [a]
                              (let [c (chain-kind a acc-sym)]
                                (cond (= (:kind c) :update) [:update c]
                                      (= (:kind c) :passthrough) [:passthrough c]
                                      :else nil)))
                            args)]
              (cond
                hit (let [[k c] hit]
                      (record! (if (= k :update) :recur-update :recur-passthrough))
                      (when (= k :update) (note-ops! c) (walk-others (:others c) infn recurp)))
                (some #(free-ref? % acc-sym) args)
                (do (record! :recur-in-complex-context)
                    (doseq [a args] (walk a false infn recurp)))
                :else nil))
            (doseq [a (rest f)] (walk a false infn recurp)))

          (and (seq? f) (seq f) (= 'if (first f)))
          (let [[_ test then else] f]
            (walk test false infn recurp)
            (walk then tailp infn recurp)
            (when else (walk else tailp infn recurp)))

          (and (seq? f) (seq f) (contains? #{'do} (first f)))
          (walk-last-tail (rest f) tailp infn recurp)

          (and (seq? f) (seq f) (contains? #{'let 'let*} (first f)))
          (let [[_ bindings & bodyf] f]
            (if (odd? (count bindings))
              (record! :other-flow) ; malformed/unreadable, conservative
              (let [pairs (partition 2 bindings)
                    shadowed (some #(shadows? (first %) acc-sym) pairs)]
                (doseq [[_ init] pairs] (walk init false infn recurp))
                (if shadowed
                  (record! :shadowed-bind)
                  (walk-last-tail bodyf tailp infn recurp)))))

          (and (seq? f) (seq f) (= 'cond (first f)))
          (doseq [[test res] (partition 2 (rest f))]
            (when (and (not= test :else) (not= test 'true))
              (walk test false infn recurp))
            (walk res tailp infn recurp))

          (and (seq? f) (seq f) (contains? #{'when 'when-not} (first f)))
          (let [[_ test & bodyf] f]
            (walk test false infn recurp)
            (walk-last-tail bodyf tailp infn recurp))

          (and (seq? f) (seq f) (contains? #{'loop 'loop*} (first f)))
          (let [[_ bindings & bodyf] f]
            (when (vector? bindings)
              (let [pairs (partition 2 bindings)]
                (doseq [[_ init] pairs]
                  (when (free-ref? init acc-sym) (record! :nested-loop-init)))
                (when-not (some #(shadows? (first %) acc-sym) pairs)
                  (walk-last-tail bodyf false infn nil)))))

          (fn-literal? f)
          (when-let [[params bodyf] (fn-single-arity-params f)]
            (when-not (shadows? params acc-sym)
              (walk-last-tail bodyf false true nil)))

          (vector? f)
          (doseq [el f]
            (if (and tailp (= el acc-sym))
              (record! :exit-in-literal)
              (walk el false infn recurp)))

          (set? f)
          (doseq [el f]
            (if (and tailp (= el acc-sym))
              (record! :exit-in-literal)
              (walk el false infn recurp)))

          (map? f)
          (doseq [[k v] f]
            (doseq [el [k v]]
              (if (and tailp (= el acc-sym))
                (record! :exit-in-literal)
                (walk el false infn recurp))))

          (and (seq? f) (seq f) (symbol? (first f)))
          (let [c (chain-kind f acc-sym)]
            (if (and tailp (= (:kind c) :update))
              (do (record! :exit-update) (note-ops! c) (walk-others (:others c) infn recurp))
              (do
                (walk (first f) false infn recurp)
                (doseq [[i a] (map-indexed vector (rest f))]
                  (if (= a acc-sym)
                    (record!
                     (cond
                       infn :captured
                       (and (= i 0) (contains? read-ops (op-name f)))
                       (do (vreset! reads? true) :read-ok)
                       :else :escape-call))
                    (walk a false infn recurp))))))

          (coll? f)
          (doseq [c f] (walk c false infn recurp))

          :else nil))]
      (walk-last-tail (vec body) true false recur?))
    (let [u (set @uses)
          bad (remove sanctioned u)]
      {:uses u
       :qualifies? (and (or (contains? u :recur-update) (contains? u :exit-update))
                         (empty? bad))
       :ops @ops
       :reads? @reads?})))

;;; -------------------------------------------------------------- site verdict
;;; == PARAM-VERDICT + INIT-SUPPORTS-P, combined: qualifies only when the
;;; usage walk qualifies AND the init is a fresh, known-representation root
;;; AND every spine op seen is inside that representation's op-gate AND
;;; (representation isn't :set, or no reads were seen).

(defn site-verdict
  [init body acc-sym recur?]
  (let [repr (init-repr init)
        {:keys [qualifies? ops reads? uses] :as u} (classify-uses body acc-sym recur?)]
    (cond
      (nil? repr) {:verdict :no-fresh-init :reason (init-nonfresh-reason init) :uses (:uses u)}
      (not qualifies?) {:verdict :usage-disqualified :uses (:uses u)}
      (not (set/subset? ops (gate-ops repr)))
      {:verdict :op-gate-fail :uses (:uses u) :ops ops :repr repr}
      (and reads? (not (gate-allows-reads? repr)))
      {:verdict :op-gate-fail :uses (:uses u) :ops ops :repr repr}
      :else {:verdict :qualified :uses (:uses u) :repr repr})))

;;; --------------------------------------------------------- site enumeration
;;; Mirrors analyze.clj's ANALYZE-LOOP / ANALYZE-REDUCE site definitions, so
;;; totals are directly comparable, but classifies with SITE-VERDICT instead
;;; of the syntactic classify-init/classify-update.

(defn loop-sites
  [form]
  (let [binds (second form)]
    (when (and (vector? binds) (even? (count binds)))
      (let [pairs (partition 2 binds)
            body (drop 2 form)]
        (for [[sym init] pairs :when (symbol? sym)]
          (site-verdict init body sym true))))))

(defn reduce-sites
  [form]
  (let [args (rest form)]
    (when (and (= 3 (count args)) (fn-literal? (first args)))
      (let [f (first args)
            init (second args)]
        (when-let [[params bodyf] (fn-single-arity-params f)]
          (when (and (= 2 (count params)) (symbol? (first params)))
            [(site-verdict init bodyf (first params) false)]))))))

(defn op-name* [form] (op-name form))

(defn walk-sites
  [form visit]
  (when-not (= "quote" (op-name* form))
    (visit form)
    (doseq [c (cond (map? form) (mapcat identity form)
                    (coll? form) form
                    :else nil)]
      (walk-sites c visit))))

(defn form-verdict
  "Aggregate a LOOP/REDUCE FORM's per-binding verdicts into ONE record, the
   same granularity analyze.clj's SITE-TAGS uses (a form is 'a map/coll
   site' if ANY of its bindings is), so totals are directly comparable to
   the paper's existing '1,442 loop/reduce accumulator sites' denominator.
   :qualified? true iff at least one binding fully qualifies; :best-reason
   is qualified's reason if so, else the most informative disqualification
   reason among its bindings (preferring op-gate-fail/usage-disqualified,
   which presuppose a real accumulator shape, over no-fresh-init)."
  [binding-verdicts]
  (if (empty? binding-verdicts)
    nil
    (let [reasons (map :verdict binding-verdicts)
          rank {:qualified 0 :op-gate-fail 1 :usage-disqualified 2 :no-fresh-init 3}
          best (apply min-key rank reasons)]
      {:qualified? (= best :qualified) :reason best})))

(defn analyze-project
  [project domain dir]
  (let [files (clj-files dir)
        parsed (mapv read-forms files)
        binding-verdicts (volatile! [])
        form-verdicts (volatile! [])]
    (doseq [{fs :forms} parsed, top fs]
      (walk-sites top
        (fn [f]
          (let [op (op-name* f)]
            (cond
              (#{"loop" "loop*"} op)
              (let [vs (loop-sites f)]
                (doseq [v vs] (vswap! binding-verdicts conj v))
                (when-let [fv (form-verdict vs)] (vswap! form-verdicts conj fv)))
              (#{"reduce" "reduce-kv" "reductions"} op)
              (let [vs (reduce-sites f)]
                (doseq [v vs] (vswap! binding-verdicts conj v))
                (when-let [fv (form-verdict vs)] (vswap! form-verdicts conj fv))))))))
    {:project project :domain domain :files (count files)
     :read-errors (count (filter :read-error parsed))
     :binding-verdicts @binding-verdicts
     :form-verdicts @form-verdicts}))

;;; ------------------------------------------------------------- aggregation

(defn tally [verdicts]
  (reduce (fn [m v] (update m (:verdict v) (fnil inc 0)))
          {:qualified 0 :no-fresh-init 0 :usage-disqualified 0 :op-gate-fail 0}
          verdicts))

(defn tally-forms [form-verdicts]
  (reduce (fn [m v] (update m (:reason v) (fnil inc 0)))
          {:qualified 0 :no-fresh-init 0 :usage-disqualified 0 :op-gate-fail 0}
          form-verdicts))

(defn tally-nonfresh-reasons
  "Sub-breakdown of BINDING-level :no-fresh-init verdicts by WHY (see
   INIT-NONFRESH-REASON): distinguishes structurally-aliased (unfixable)
   from analysis-gap (potentially closeable) causes."
  [binding-verdicts]
  (reduce (fn [m v] (update m (:reason v) (fnil inc 0)))
          {:aliased-reference 0 :nonfresh-stdlib-call 0 :helper-call 0 :other 0}
          (filter #(= :no-fresh-init (:verdict %)) binding-verdicts)))

(defn pct [num den] (if (pos? den) (format "%.2f%%" (* 100.0 (/ (double num) den))) "n/a"))

(defn print-summary [stats]
  (let [all-b (mapcat :binding-verdicts stats)
        all-f (mapcat :form-verdicts stats)
        nb (count all-b)
        nf (count all-f)
        tb (tally all-b)
        tf (tally-forms all-f)]
    (println "\n============= Gate-faithful classifier corpus study =============")
    (println (format "Projects: %d   Files: %d   Read errors: %d"
                     (count stats)
                     (reduce + (map :files stats))
                     (reduce + (map :read-errors stats))))
    (println (format "\n--- Per-FORM (comparable to analyze.clj's 1,442-site denominator: one entry per loop/reduce form, true if ANY binding qualifies) ---"))
    (println (format "Loop/reduce forms classified: %d" nf))
    (println (format "  QUALIFIED (>=1 binding passes real chain+op-gate+freshness): %d (%s)"
                     (:qualified tf) (pct (:qualified tf) nf)))
    (println (format "  no fresh/known-representation init only:        %d (%s)"
                     (:no-fresh-init tf) (pct (:no-fresh-init tf) nf)))
    (println (format "  usage walk disqualified (escape/capture/reset/complex): %d (%s)"
                     (:usage-disqualified tf) (pct (:usage-disqualified tf) nf)))
    (println (format "  op-gate failure (op or read unsupported by repr): %d (%s)"
                     (:op-gate-fail tf) (pct (:op-gate-fail tf) nf)))
    (println (format "\n--- Per-BINDING (finer-grained; one entry per accumulator candidate) ---"))
    (println (format "Bindings classified: %d" nb))
    (println (format "  QUALIFIED: %d (%s)" (:qualified tb) (pct (:qualified tb) nb)))
    (println (format "  no-fresh-init: %d (%s)" (:no-fresh-init tb) (pct (:no-fresh-init tb) nb)))
    (println (format "  usage-disqualified: %d (%s)" (:usage-disqualified tb) (pct (:usage-disqualified tb) nb)))
    (println (format "  op-gate-fail: %d (%s)" (:op-gate-fail tb) (pct (:op-gate-fail tb) nb)))
    (let [tr (tally-nonfresh-reasons all-b)
          nfi (:no-fresh-init tb)]
      (println (format "\n--- Why no-fresh-init? (of the %d no-fresh-init bindings above) ---" nfi))
      (println (format "  aliased-reference (bare var/param -- STRUCTURALLY unfixable): %d (%s)"
                       (:aliased-reference tr) (pct (:aliased-reference tr) nfi)))
      (println (format "  nonfresh-stdlib-call (vec/into/merge/etc -- analysis gap): %d (%s)"
                       (:nonfresh-stdlib-call tr) (pct (:nonfresh-stdlib-call tr) nfi)))
      (println (format "  helper-call (project-local fn -- Tier-2-closeable gap): %d (%s)"
                       (:helper-call tr) (pct (:helper-call tr) nfi)))
      (println (format "  other: %d (%s)" (:other tr) (pct (:other tr) nfi))))
    (println "===================================================================\n")))

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
    (spit (or out-path "results-classify.edn")
          (with-out-str
            (pp/pprint
             {:generated (str (java.time.Instant/now))
              :projects (mapv (fn [s] (update s :binding-verdicts
                                              (fn [vs] (mapv #(dissoc % :uses) vs))))
                              stats)})))
    (print-summary stats)
    (println "Wrote" (or out-path "results-classify.edn"))
    (shutdown-agents)))
