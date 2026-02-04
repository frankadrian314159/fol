(in-package fol.eval)

;;; ============================================================================
;;; Standard Macros
;;; ============================================================================

(defun make-when-macro ()
  "Create the 'when' macro.
   (when test form0 form1 ... formN) expands to (if test (do form0 form1 ... formN) nil)"
  (make-macro
   '(test)                    ; params: just test
   '((syntax-quote            ; body: expand to (if test (do ~@body) nil)
      (if (unquote test)
          (do (unquote-splicing body))
          nil)))
   nil                        ; env
   :rest-param 'body          ; rest param captures all body forms
   :name 'when))

(defun make-unless-macro ()
  "Create the 'unless' macro.
   (unless test form0 form1 ... formN) expands to (if test nil (do form0 form1 ... formN))"
  (make-macro
   '(test)                    ; params: just test
   '((syntax-quote            ; body: expand to (if test nil (do ~@body))
      (if (unquote test)
          nil
          (do (unquote-splicing body)))))
   nil                        ; env
   :rest-param 'body          ; rest param captures all body forms
   :name 'unless))

(defun make-with-seed-macro ()
  "Create the 'with-seed' macro.
   (with-seed seed form0 form1 ... formN) expands to
   (call-with-seed seed (fn [] form0 form1 ... formN))
   This binds *random-state* to a seeded state for the duration of the body,
   returning the value of the last form."
  (let ((empty-vec (make-instance 'fol.collection:<vector> :items (fset:empty-seq))))
    (make-macro
     '(seed)                    ; params: seed value
     `((syntax-quote            ; body: expand to (call-with-seed seed (fn [] body...))
        (call-with-seed (unquote seed)
                        (fn ,empty-vec (unquote-splicing body)))))
     nil                        ; env
     :rest-param 'body          ; rest param captures all body forms
     :name 'with-seed)))

;;; --- Threading Macros ---

(defun make-as->-macro ()
  "Create the 'as->' macro.
   (as-> expr name form1 form2 ...) binds name to expr, then threads through forms.
   In each form, name refers to the result of the previous form.
   Example: (as-> 1 x (+ x 1) (* x 2)) => 4"
  (make-macro
   '(expr name)
   '((build-as->-expansion name expr forms))
   (make-env nil
             'build-as->-expansion
             #'(lambda (name expr forms)
                 ;; Build nested bind forms: (bind (name expr) (bind (name form1) ... name))
                 (cl:labels ((build (remaining-forms)
                               (if (null remaining-forms)
                                   ;; No more forms, return the name
                                   name
                                   ;; Wrap in bind
                                   (cl:list 'bind
                                            (cl:list name (cl:first remaining-forms))
                                            (build (cl:rest remaining-forms))))))
                   (cl:list 'bind
                            (cl:list name expr)
                            (build forms)))))
   :rest-param 'forms
   :name 'as->))

(defun make-cond->-macro ()
  "Create the 'cond->' macro.
   (cond-> expr test1 form1 test2 form2 ...)
   Threads expr through forms where corresponding test is true (thread-first).
   Example: (cond-> 1 true (+ 1) false (+ 2) true (* 3)) => 6"
  (make-macro
   '(expr)
   '((syntax-quote
      (cond->-helper (unquote expr) (unquote-splicing clauses))))
   nil
   :rest-param 'clauses
   :name 'cond->))

(defun make-cond->>-macro ()
  "Create the 'cond->>' macro.
   (cond->> expr test1 form1 test2 form2 ...)
   Threads expr through forms where corresponding test is true (thread-last).
   Example: (cond->> [1 2 3] true (map inc) false (map dec)) => [2 3 4]"
  (make-macro
   '(expr)
   '((syntax-quote
      (cond->>-helper (unquote expr) (unquote-splicing clauses))))
   nil
   :rest-param 'clauses
   :name 'cond->>))

(defun make-some->-macro ()
  "Create the 'some->' macro.
   (some-> expr form1 form2 ...)
   Threads expr through forms as first arg, short-circuiting on nil.
   Example: (some-> {:a 1} :a inc) => 2
            (some-> {:a 1} :b inc) => nil"
  (make-macro
   '(expr)
   '((syntax-quote
      (some->-helper (unquote expr) (unquote-splicing forms))))
   nil
   :rest-param 'forms
   :name 'some->))

(defun make-some->>-macro ()
  "Create the 'some->>' macro.
   (some->> expr form1 form2 ...)
   Threads expr through forms as last arg, short-circuiting on nil.
   Example: (some->> [1 2 3] (map inc) first) => 2"
  (make-macro
   '(expr)
   '((syntax-quote
      (some->>-helper (unquote expr) (unquote-splicing forms))))
   nil
   :rest-param 'forms
   :name 'some->>))

;;; --- Control Flow Macros ---

(defun make-when-not-macro ()
  "Create the 'when-not' macro.
   (when-not test form0 form1 ... formN) expands to (if test nil (do form0 form1 ... formN))"
  (make-macro
   '(test)
   '((syntax-quote
      (if (unquote test)
          nil
          (do (unquote-splicing body)))))
   nil
   :rest-param 'body
   :name 'when-not))

(defun make-when-let-macro ()
  "Create the 'when-let' macro.
   (when-let [x expr] body...) evaluates expr, binds to x if truthy, then executes body.
   Example: (when-let [x (get m :key)] (inc x))"
  (make-macro
   '(bindings)
   '((bind (var (first bindings)
            expr (nth bindings 1))
       (syntax-quote
        (bind (temp# (unquote expr))
          (when temp#
            (bind ((unquote var) temp#)
              (unquote-splicing body)))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'body
   :name 'when-let))

(defun make-when-first-macro ()
  "Create the 'when-first' macro.
   (when-first [x coll] body...) binds x to (first coll) if coll is not empty.
   Example: (when-first [x [1 2 3]] (inc x)) => 2"
  (make-macro
   '(bindings)
   '((bind (var (first bindings)
            coll-expr (nth bindings 1))
       (syntax-quote
        (bind (s# (seq (unquote coll-expr)))
          (when s#
            (bind ((unquote var) (first s#))
              (unquote-splicing body)))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'body
   :name 'when-first))

(defun make-if-not-macro ()
  "Create the 'if-not' macro.
   (if-not test then) or (if-not test then else)
   Equivalent to (if (not test) then else)"
  (make-macro
   '(test then)
   '((syntax-quote
      (if (not (unquote test))
          (unquote then)
          (unquote (first else)))))
   (make-env nil 'first #'fol.seqop:first)
   :rest-param 'else
   :name 'if-not))

(defun make-if-let-macro ()
  "Create the 'if-let' macro.
   (if-let [x expr] then else?) binds x to expr, executes then if truthy, else otherwise.
   Example: (if-let [x (get m :key)] (inc x) 0)"
  (make-macro
   '(bindings then)
   '((bind (var (first bindings)
            expr (nth bindings 1))
       (syntax-quote
        (bind (temp# (unquote expr))
          (if temp#
              (bind ((unquote var) temp#)
                (unquote then))
              (unquote (first else)))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'else
   :name 'if-let))

(defun make-condp-macro ()
  "Create the 'condp' macro.
   (condp pred expr clause1 clause2 ... default?)
   Each clause is (test-expr result-expr) or (test-expr :>> result-fn).
   Evaluates (pred test-expr expr) for each clause.
   Example: (condp = x 1 :one 2 :two :other)"
  (make-macro
   '(pred expr)
   '((syntax-quote
      (condp-helper (unquote pred) (unquote expr) (unquote-splicing clauses))))
   nil
   :rest-param 'clauses
   :name 'condp))

(defun make-when-some-macro ()
  "Create the 'when-some' macro.
   (when-some [x expr] body...) binds x to expr if (some? expr), then executes body.
   Example: (when-some [x (get m :key)] (inc x))"
  (make-macro
   '(bindings)
   '((bind (var (first bindings)
            expr (nth bindings 1))
       (syntax-quote
        (bind (temp# (unquote expr))
          (when (some? temp#)
            (bind ((unquote var) temp#)
              (unquote-splicing body)))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'body
   :name 'when-some))

(defun make-if-some-macro ()
  "Create the 'if-some' macro.
   (if-some [x expr] then else?) binds x to expr if (some? expr), executes then, else otherwise.
   Example: (if-some [x (get m :key)] (inc x) 0)"
  (make-macro
   '(bindings then)
   '((bind (var (first bindings)
            expr (nth bindings 1))
       (syntax-quote
        (bind (temp# (unquote expr))
          (if (some? temp#)
              (bind ((unquote var) temp#)
                (unquote then))
              (unquote (first else)))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'else
   :name 'if-some))

;;; --- Loop Macros ---

(defun make-dotimes-macro ()
  "Create the 'dotimes' macro.
   (dotimes [i n] body...) executes body n times with i bound to 0, 1, ..., n-1.
   Example: (dotimes [i 3] (print i)) prints 0, 1, 2"
  (make-macro
   '(bindings)
   '((bind (var (first bindings)
            count-expr (nth bindings 1))
       (syntax-quote
        (loop (idx# 0
               limit# (unquote count-expr))
          (when (< idx# limit#)
            (bind ((unquote var) idx#)
              (unquote-splicing body))
            (recur (inc idx#) limit#))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'body
   :name 'dotimes))

(defun make-doseq-macro ()
  "Create the 'doseq' macro.
   (doseq [x coll] body...) executes body for each element x in coll.
   Example: (doseq [x [1 2 3]] (print x)) prints 1, 2, 3"
  (make-macro
   '(bindings)
   '((bind (var (first bindings)
            coll-expr (nth bindings 1))
       (syntax-quote
        (loop (s# (seq (unquote coll-expr)))
          (when (not (empty? s#))
            (bind ((unquote var) (first s#))
              (unquote-splicing body))
            (recur (rest s#)))))))
   (make-env nil 'first #'fol.seqop:first 'nth #'fol.seqop:nth)
   :rest-param 'body
   :name 'doseq))

(defun make-for-macro ()
  "Create the 'for' macro.
   (for [x coll] body) returns a lazy sequence of body for each x in coll.
   Supports :when modifiers and nested bindings.
   Example: (for [x [1 2 3]] (* x x)) => (1 4 9)
            (for [x (range 10) :when (even? x)] x) => (0 2 4 6 8)
            (for [x [1 2] y [:a :b]] [x y]) => ([1 :a] [1 :b] [2 :a] [2 :b])"
  (make-macro
   '(seq-exprs)
   '((bind (parsed (%parse-for-bindings seq-exprs)
            expansion (%expand-for-bindings parsed body))
       expansion))
   (make-env nil
             '%parse-for-bindings
             #'(lambda (seq-exprs)
                 "Parse for binding vector into list of (var coll-expr [:when pred])"
                 ;; Convert FOL vector to Common Lisp list
                 (let ((items-list (fset:convert 'cl:list (cl:slot-value seq-exprs 'fol.collection::items))))
                   (cl:labels ((parse-loop (remaining bindings)
                                (if (null remaining)
                                    (cl:nreverse bindings)
                                    (let ((var (cl:first remaining))
                                          (coll-expr (cl:second remaining))
                                          (rest-exprs (cl:cddr remaining)))
                                      ;; Check for :when modifier
                                      (if (cl:and rest-exprs
                                                  (cl:keywordp (cl:first rest-exprs))
                                                  (string-equal (cl:symbol-name (cl:first rest-exprs)) "when"))
                                          ;; Has :when modifier
                                          (let ((when-pred (cl:second rest-exprs)))
                                            (parse-loop (cl:cddr rest-exprs)
                                                        (cl:cons (cl:list var coll-expr :when when-pred)
                                                                 bindings)))
                                          ;; No modifier
                                          (parse-loop rest-exprs
                                                      (cl:cons (cl:list var coll-expr)
                                                               bindings)))))))
                     (parse-loop items-list nil))))
             '%expand-for-bindings
             #'(lambda (parsed-bindings body)
                 "Expand parsed bindings into nested map/mapcat calls"
                 (if (null parsed-bindings)
                     (error "for: empty bindings vector")
                     (cl:labels ((build-expansion (bindings)
                                   (if (null bindings)
                                       ;; Base case: just the body
                                       (cl:cons 'do body)
                                       ;; Recursive case: wrap in map or filter+map
                                       (let* ((binding (cl:first bindings))
                                              (var (cl:first binding))
                                              (coll-expr (cl:second binding))
                                              (has-when (cl:>= (cl:length binding) 4))
                                              (when-pred (if has-when (cl:fourth binding) nil))
                                              (inner-expansion (build-expansion (cl:rest bindings))))
                                         (if (null (cl:rest bindings))
                                             ;; Last binding: use map
                                             (if has-when
                                                 (cl:list 'mapcat
                                                          (cl:list 'fn (cl:list var)
                                                                   (cl:list 'if when-pred
                                                                            (cl:list 'list inner-expansion)
                                                                            (cl:list 'list)))
                                                          coll-expr)
                                                 (cl:list 'map
                                                          (cl:list 'fn (cl:list var) inner-expansion)
                                                          coll-expr))
                                             ;; Not last binding: use mapcat for cartesian product
                                             (if has-when
                                                 (cl:list 'mapcat
                                                          (cl:list 'fn (cl:list var)
                                                                   (cl:list 'if when-pred
                                                                            inner-expansion
                                                                            (cl:list 'list)))
                                                          coll-expr)
                                                 (cl:list 'mapcat
                                                          (cl:list 'fn (cl:list var) inner-expansion)
                                                          coll-expr)))))))
                       (build-expansion parsed-bindings)))))
   :rest-param 'body
   :name 'for))

;;; --- Lazy and Misc Macros ---

(defun make-lazy-cat-macro ()
  "Create the 'lazy-cat' macro.
   (lazy-cat coll1 coll2 ...) returns a lazy sequence of the concatenation of colls.
   Example: (lazy-cat [1 2] [3 4]) => (1 2 3 4)"
  (make-macro
   nil
   '((syntax-quote
      (lazy-cat-helper (unquote-splicing colls))))
   nil
   :rest-param 'colls
   :name 'lazy-cat))

(defun make-delay-macro ()
  "Create the 'delay' macro.
   (delay body...) creates a delay object that computes body when forced.
   Use (force d) or @d to get the value. The value is cached after first computation.
   Example: (def d (delay (+ 1 2))) (force d) => 3"
  (let ((empty-vec (make-instance 'fol.collection:<vector> :items (fset:empty-seq))))
    (make-macro
     nil
     `((syntax-quote
        (make-delay (fn ,empty-vec (unquote-splicing body)))))
     nil
     :rest-param 'body
     :name 'delay)))

(defun make-assert-macro ()
  "Create the 'assert' macro.
   (assert test) or (assert test message) throws if test is false.
   Example: (assert (> x 0) \"x must be positive\")"
  (make-macro
   '(test)
   '((syntax-quote
      (when (not (unquote test))
        (throw (if (first (quote (unquote-splicing msg)))
                   (first (quote (unquote-splicing msg)))
                   (str "Assertion failed: " (quote (unquote test))))))))
   nil
   :rest-param 'msg
   :name 'assert))

(defun make-comment-macro ()
  "Create the 'comment' macro.
   (comment body...) ignores all forms and returns nil.
   Useful for commenting out code blocks.
   Example: (comment (this is ignored) (so is this)) => nil"
  (make-macro
   nil
   '(nil)  ; Just returns nil
   nil
   :rest-param 'body
   :name 'comment))

(defun fol-time-thunk (thunk)
  "Execute THUNK (a FOL function of no arguments) and print timing information.
   Returns the result of calling the thunk."
  (let* ((start-time (get-internal-real-time))
         (result (fol.eval:apply-function thunk nil))
         (end-time (get-internal-real-time))
         (elapsed-seconds (/ (- end-time start-time)
                             (float internal-time-units-per-second))))
    (format t "~&Elapsed time: ~,6F seconds~%" elapsed-seconds)
    (finish-output)
    result))

(defun make-%time%-macro ()
  "Create the '%time%' macro.
   (%time% body...) evaluates the body forms and prints the elapsed time.
   Returns the result of evaluating the body.
   Example: (%time% (reduce + (range 10000))) prints elapsed time and returns 49995000"
  (let ((empty-vec (make-instance 'fol.collection:<vector> :items (fset:empty-seq))))
    (make-macro
     nil
     `((syntax-quote
        (%time-thunk% (fn ,empty-vec (unquote-splicing body)))))
     nil
     :rest-param 'body
     :name '%time%)))

;;; ============================================================================
;;; Standard Environment
;;; ============================================================================

(defun make-standard-module ()
  "Create a module with standard FOL bindings for arithmetic,
   comparison, and logical operations. All symbols are exported."
  (let ((module (fol.module:make-module "fol.core"
            ;; Arithmetic
            '+ #'+
            '- #'-
            '* #'*
            '/ #'/
            'abs #'abs
            'sin #'sin
            'cos #'cos
            'tan #'tan
            'sqrt #'sqrt
            'expt #'expt
            'exp #'exp
            'ln #'ln
            'mod #'cl:mod
            'rem #'cl:rem
            'abs #'abs
            'sin #'sin
            'cos #'cos
            'tan #'tan
            'sqrt #'sqrt
            'expt #'expt
            'exp #'exp
            'ln #'ln
            'mod #'cl:mod
            'rem #'cl:rem
            'floor #'cl:floor
            'ceiling #'cl:ceiling
            'truncate #'cl:truncate
            'round #'cl:round
            'inc #'cl:1+
            'dec #'cl:1-
            ;; Comparison
            '= #'=
            '/= #'/=
            '< #'<
            '> #'>
            '<= #'<=
            '>= #'>=
            'min #'min
            'max #'max
            'eq #'cl:eq
            'eql #'cl:eql
            'equal #'cl:equal
            ;; Logical
            'not #'not
            'and #'and
            'or #'or
            ;; Type predicates
            '<bool>? #'(lambda (x) (typep x 'boolean))
            '<char>? #'cl:characterp
            '<number>? #'cl:numberp
            '<integer>? #'cl:integerp
            '<fixnum>? #'(lambda (x) (typep x 'fixnum))
            '<bignum>? #'(lambda (x) (typep x 'bignum))
            '<float>? #'cl:floatp
            '<single-float>? #'(lambda (x) (typep x 'single-float))
            '<double-float>? #'(lambda (x) (typep x 'double-float))
            '<ratio>? #'(lambda (x) (typep x 'ratio))
            '<rational>? #'cl:rationalp
            '<complex>? #'cl:complexp
            '<string>? #'cl:stringp
            '<symbol>? #'cl:symbolp
            '<keyword>? #'cl:keywordp
            ;; Collection type predicates
            '<collection>? #'fol.collection:<collection>?
            '<ordered-collection>? #'fol.collection:<ordered-collection>?
            '<unordered-collection>? #'fol.collection:<unordered-collection>?
            '<vector>? #'fol.collection:<vector>?
            '<deque>? #'fol.collection:<deque>?
            '<list>? #'fol.collection:<list>?
            '<dict>? #'fol.collection:<dict>?
            '<set>? #'fol.collection:<set>?
            '<bag>? #'fol.collection:<bag>?
            '<array-dict>? #'fol.collection:<array-dict>?
            '<sorted-dict>? #'fol.collection:<sorted-dict>?
            '<ordered-dict>? #'fol.collection:<ordered-dict>?
            '<priority-dict>? #'fol.collection:<priority-dict>?
            '<int-dict>? #'fol.collection:<int-dict>?
            '<array>? #'fol.collection:<array>?
            '<lazy-seq>? #'fol.collection:<lazy-seq>?
            ;; Number predicates
            'positive? #'fol.number:positive?
            'negative? #'fol.number:negative?
            'zero? #'fol.number:zero?
            'even? #'fol.number:even?
            'odd? #'fol.number:odd?
            'nat-int? #'fol.number:nat-int?
            'pos-int? #'fol.number:pos-int?
            'NaN? #'fol.number:NaN?
            'infinite? #'fol.number:infinite?
            ;; Type conversion functions
            '<complex> #'fol.number:<complex>
            '<single-float> #'fol.number:<single-float>
            '<double-float> #'fol.number:<double-float>
            'int #'fol.number:int
            'rationalize #'fol.arithop:rationalize
            ;; Random number generation
            'rand #'fol.number:rand
            'call-with-seed #'fol.number:call-with-seed
            ;; List operations
            ;; list creates FOL <list> objects (Clojure-style)
            ;; Use cl-list for macro form construction (building CL lists)
            'list #'fol.collection:make-list
            'cl-list #'cl:list
            'list* #'(lambda (&rest args)
                       "Creates a new list containing the items prepended to the rest, the last of which
                        will be treated as a sequence."
                       (if (null args)
                           (fol.collection:make-list)
                           (let* ((all-but-last (butlast args))
                                  (last-arg (car (last args)))
                                  (tail-seq (fol.seqop:seq last-arg)))
                             ;; Build list from the tail backwards
                             (let ((result (if (null tail-seq)
                                               (fol.collection:make-list)
                                               ;; Convert tail-seq to a <list>
                                               (cl:labels ((seq-to-list (s)
                                                             (if (cl:or (null s) (fol.seqop:empty? s))
                                                                 (fol.collection:make-list)
                                                                 (fol.seqop:conj
                                                                  (seq-to-list (fol.seqop:rest s))
                                                                  (fol.seqop:first s)))))
                                                 (seq-to-list tail-seq)))))
                               ;; Prepend the other args in reverse order
                               (dolist (item (cl:reverse all-but-last))
                                 (setf result (fol.seqop:conj result item)))
                               result))))
            ;; cons prepends to FOL collections (Clojure-style)
            ;; Use cl-cons for macro form construction (building CL cons cells)
            'cons #'(lambda (x coll)
                      "Returns a new seq where x is the first element and coll is the rest."
                      (if (null coll)
                          (fol.collection:make-list x)
                          (fol.seqop:conj (fol.seqop:seq coll) x)))
            'cl-cons #'cl:cons
            'peek #'fol.seqop:peek
            'pop #'fol.seqop:pop
            'push #'fol.seqop:push
            ;; CL sequence operations (for compatibility)
            'append #'cl:append
            ;; String operations
            'str #'(lambda (&rest args)
                     (apply #'concatenate 'string
                            (mapcar (lambda (x)
                                      (cond
                                        ((null x) "nil")
                                        ;; Handle wrapped FOL <string> objects
                                        ((typep x 'fol.classes:<string>)
                                         (fol.wrappers:fol-value x))
                                        ;; Handle raw CL strings
                                        ((stringp x) x)
                                        ;; Everything else
                                        (t (princ-to-string x))))
                                    args)))
            'sub #'fol.seqop:sub
            'blank? #'fol.string:blank?
            'trim #'fol.string:trim
            'triml #'fol.string:triml
            'trimr #'fol.string:trimr
            'trim-newline #'fol.string:trim-newline
            'capitalize #'fol.string:capitalize
            'upper-case #'cl:string-upcase
            'lower-case #'cl:string-downcase
            'starts-with? #'fol.string:starts-with?
            'ends-with? #'fol.string:ends-with?
            'includes? #'fol.string:includes?
            'replace #'fol.string:replace
            'replace-first #'fol.string:replace-first
            'join #'fol.string:join
            'escape #'fol.string:escape
            'split #'fol.string:split
            'split-lines #'fol.string:split-lines
            'reverse #'fol.seqop:reverse
            'index-of #'fol.seqop:index-of
            'last-index-of #'fol.seqop:last-index-of
            ;; Regex operations
            're-find #'fol.string:re-find
            're-seq #'fol.string:re-seq
            're-pattern #'fol.string:wrap-re-pattern
            're-scanner #'fol.string:make-re-scanner
            ;; Parsing functions
            'parse-bool #'fol.bool:parse-bool
            'parse-int #'fol.number:parse-int
            'parse-double #'fol.number:parse-double
            'parse-uuid #'fol.string:parse-uuid
            ;; Keyword and symbol functions
            'keyword #'fol.symbol:keyword
            'find-keyword #'fol.symbol:find-keyword
            'symbol #'fol.symbol:symbol
            'gensym #'fol.symbol:gensym
            ;; Character operations
            'char-name-string #'fol.char:char-name-string
            ;; Misc
            'identity #'cl:identity
            'complement #'cl:complement
            'disjoin #'(lambda (&rest predicates)
                         "Returns a function that is the disjunction (OR) of the predicates.
                          The returned function applies predicates in order until one returns
                          a truthy value (short-circuit). Returns that value, or nil if none."
                         (lambda (&rest args)
                           (loop for pred in predicates
                                 for result = (apply-function pred args)
                                 when result return result
                                 finally (return nil))))
            'conjoin #'(lambda (&rest predicates)
                         "Returns a function that is the conjunction (AND) of the predicates.
                          The returned function applies predicates in order. If any returns nil,
                          immediately returns nil (short-circuit). Otherwise returns the last result."
                         (lambda (&rest args)
                           (if (null predicates)
                               t  ; empty conjunction is true
                               (loop for pred in predicates
                                     for result = (apply-function pred args)
                                     unless result return nil
                                     finally (return result)))))
            'partial #'(lambda (f &rest bound-args)
                         "Returns a function that calls f with bound-args prepended to any additional args.
                          (partial f a b) returns a function that, when called with (x y), calls (f a b x y)."
                         (lambda (&rest more-args)
                           (apply-function f (append bound-args more-args))))
            'rpartial #'(lambda (f &rest bound-args)
                          "Returns a function that calls f with bound-args appended to any additional args.
                           (rpartial f a b) returns a function that, when called with (x y), calls (f x y a b)."
                          (lambda (&rest more-args)
                            (apply-function f (append more-args bound-args))))
            'juxt #'(lambda (&rest fns)
                      "Returns a function that applies each fn to its args and returns the results as a vector.
                       (juxt f g h) returns a function that, when called with args, returns [(f args) (g args) (h args)]."
                      (lambda (&rest args)
                        (apply #'fol.collection:make-vector
                               (loop for fn in fns
                                     collect (apply-function fn args)))))
            'print #'cl:print
            'eval #'fol-eval
            'type #'fol.wrappers:fol-type-of
            ;; Generic constructor
            'make #'make
            ;; MOP introspection functions
            'class-name #'cl:class-name
            'class-direct-superclasses* #'(lambda (class)
                                            (apply #'fol.collection:make-list
                                                   (c2mop:class-direct-superclasses class)))
            'class-slots #'(lambda (class)
                              (apply #'fol.collection:make-list
                                     (c2mop:class-slots class)))
            'slot-names #'(lambda (class)
                            (apply #'fol.collection:make-list
                                   (mapcar #'c2mop:slot-definition-name
                                           (c2mop:class-slots class))))
            'slot-value #'cl:slot-value
            'instance-class #'cl:class-of
            '<persistent-object>? #'(lambda (x) (typep x 'fol.persistent:<persistent-object>))
            'symbol? #'cl:symbolp
            ;; Class objects for MOP
            '<string> (find-class 'fol.classes:<string>)
            '<integer> (find-class 'fol.classes:<integer>)
            '<number> (find-class 'fol.classes:<number>)
            '<vector> (find-class 'fol.collection:<vector>)
            '<list> (find-class 'fol.collection:<list>)
            '<dict> (find-class 'fol.collection:<dict>)
            '<set> (find-class 'fol.collection:<set>)
            '<persistent-object> (find-class 'fol.persistent:<persistent-object>)
            ;; Bitwise operations
            'bitnot #'fol.bitop:bitnot
            'bitand #'fol.bitop:bitand
            'bitor #'fol.bitop:bitor
            'bitxor #'fol.bitop:bitxor
            'bit-nand #'fol.bitop:bit-nand
            'bit-nor #'fol.bitop:bit-nor
            'bit-andc1 #'fol.bitop:bit-andc1
            'bit-andc2 #'fol.bitop:bit-andc2
            'bit-orc1 #'fol.bitop:bit-orc1
            'bit-orc2 #'fol.bitop:bit-orc2
            'bit-test #'fol.bitop:bit-test
            'bit-set #'fol.bitop:bit-set
            'bit-clear #'fol.bitop:bit-clear
            'bit-count #'fol.bitop:bit-count
            'bit-shift #'fol.bitop:bit-shift
            'bit-rotate #'fol.bitop:bit-rotate
            ;; FOL collection operations
            'conj #'fol.seqop:conj
            'first #'fol.seqop:first
            'rest #'fol.seqop:rest
            'second #'fol.collection:second
            'third #'fol.collection:third
            'nth #'fol.seqop:nth
            'size #'fol.seqop:size
            'empty? #'fol.seqop:empty?
            'get #'fol.seqop:get
            'contains? #'fol.seqop:contains?
            'seq #'fol.seqop:seq
            'sequence #'(lambda (coll-or-xform &optional coll)
                          "Coerces coll to a (possibly empty) sequence. Like seq, but returns
                           () instead of nil for empty collections. Does not force lazy seqs.
                           When called with two args (xform coll), applies transducer xform."
                          (if coll
                              ;; 2-arg version: (sequence xform coll)
                              (let* ((xform coll-or-xform)
                                     (result nil)
                                     ;; Wrap rf to handle all three arities
                                     (rf #'(lambda (&rest args)
                                             (cl:case (cl:length args)
                                               (0 nil)  ; init
                                               (1 (cl:first args))  ; completion
                                               (2 (cl:push (cl:second args) (cl:first args))
                                                  (cl:first args)))))
                                     (xf (funcall xform rf))
                                     (s (fol.seqop:seq coll))
                                     (acc nil))
                                (loop while (cl:and s (cl:not (fol.seqop:empty? s))
                                                    (cl:not (fol.collection:<reduced>? acc)))
                                      do (setf acc (funcall xf acc (fol.seqop:first s)))
                                         (setf s (fol.seqop:rest s)))
                                (setf result (fol.collection:unreduced acc))
                                ;; Call completion arity
                                (setf result (funcall xf result))
                                ;; Convert to lazy seq
                                (apply #'fol.collection:make-list (cl:nreverse result)))
                              ;; 1-arg version: (sequence coll)
                              (let ((s (fol.seqop:seq coll-or-xform)))
                                (if (null s)
                                    (fol.collection:make-list)  ; Return empty list, not nil
                                    s))))
            'add #'fol.seqop:add
            'remove #'fol.seqop:remove
            'disj #'fol.seqop:disj
            'sized? #'fol.collection:sized?
            'bounded-size #'fol.collection:bounded-size
            'into #'fol.collection:into
            'vector #'fol.collection:vector
            'vec #'fol.collection:vec
            'mapv #'fol.collection:mapv
            'filterv #'fol.collection:filterv
            ;; Deque constructor and operations
            'deque #'fol.collection:make-deque
            'peek-front #'fol.seqop:peek-front
            'pop-front #'fol.seqop:pop-front
            'push-front #'fol.seqop:push-front
            'peek-end #'fol.seqop:peek-end
            'pop-end #'fol.seqop:pop-end
            'push-end #'fol.seqop:push-end
            'assoc #'fol.seqop:assoc
            'assoc-in #'fol.seqop:assoc-in
            'rseq #'fol.seqop:rseq
            'update #'fol.seqop:update
            'update-in #'fol.seqop:update-in
            'reduce-kv #'fol.seqop:reduce-kv
            ;; Set constructors (Clojure-style)
            'set #'fol.collection:make-set
            'hash-set #'fol.collection:make-set
            'sorted-set #'fol.collection:make-sorted-set
            '<sorted-set> #'fol.collection:make-sorted-set
            'ordered-set #'fol.collection:make-ordered-set
            '<ordered-set> #'fol.collection:make-ordered-set
            'int-set #'fol.collection:make-int-set
            '<int-set> #'fol.collection:make-int-set
            'dense-int-set #'fol.collection:make-dense-int-set
            '<dense-int-set> #'fol.collection:make-dense-int-set
            ;; Set type predicates
            '<set>? #'fol.collection:<set>?
            '<sorted-set>? #'fol.collection:<sorted-set>?
            '<ordered-set>? #'fol.collection:<ordered-set>?
            '<int-set>? #'fol.collection:<int-set>?
            '<dense-int-set>? #'fol.collection:<dense-int-set>?
            ;; sorted-set-by constructor and predicate
            'sorted-set-by #'fol.collection:sorted-set-by
            '<sorted-set-by> #'fol.collection:sorted-set-by
            '<sorted-set-by>? #'fol.collection:<sorted-set-by>?
            ;; Dict constructors (Clojure-style)
            'array-dict #'fol.collection:array-dict
            '<array-dict> #'fol.collection:array-dict
            'array-dict-with-limit #'fol.collection:array-dict-with-limit
            'sorted-dict #'fol.collection:sorted-dict
            '<sorted-dict> #'fol.collection:sorted-dict
            'sorted-dict-by #'fol.collection:sorted-dict-by
            'ordered-dict #'fol.collection:ordered-dict
            '<ordered-dict> #'fol.collection:ordered-dict
            'priority-dict #'fol.collection:priority-dict
            '<priority-dict> #'fol.collection:priority-dict
            'int-dict #'fol.collection:int-dict
            '<int-dict> #'fol.collection:int-dict
            ;; Set operations (FOL names union/difference/intersection, CL impl set-union/etc.)
            'union #'fol.seqop:set-union
            'difference #'fol.seqop:set-difference
            'intersection #'fol.seqop:set-intersection
            'select #'fol.seqop:select
            'subset? #'fol.seqop:subset?
            'superset? #'fol.seqop:superset?
            ;; Ordered set subsequence operations
            'subs #'fol.seqop:subs
            'rsubs #'fol.seqop:rsubs
            ;; Base collection constructors
            'dict #'fol.collection:make-dict
            'bag #'fol.collection:make-bag
            'array #'fol.collection:make-array
            ;; Dict query functions
            'get-in #'fol.seqop:get-in
            'find #'fol.seqop:find
            'keys #'fol.seqop:keys
            'vals #'fol.seqop:vals
            'key #'fol.seqop:key
            'val #'fol.seqop:val
            ;; Dict modification functions
            'dissoc #'fol.seqop:dissoc
            'merge #'fol.seqop:merge
            'merge-with #'fol.seqop:merge-with
            ;; Dict transformation functions
            'select-keys #'fol.seqop:select-keys
            'rename-keys #'fol.seqop:rename-keys
            'map-invert #'fol.seqop:map-invert
            'update-keys #'fol.seqop:update-keys
            'update-vals #'fol.seqop:update-vals
            ;; Dict construction functions
            'freqs #'fol.seqop:freqs
            'group-by #'fol.seqop:group-by
            'index #'fol.seqop:index
            ;; Higher-order collection operations
            'reduce #'(lambda (f &rest args)
                        "Reduce a collection using function f.
                         (reduce f) - returns a transducer that applies (f elem) to each element
                         (reduce f coll) - uses first element as initial value, f is (f acc elem)
                         (reduce f init coll) - uses init as initial value, f is (f acc elem)
                         If f returns a (reduced val), reduction terminates early with val."
                        (cond
                          ;; (reduce f) - return a transducer
                          ;; The transducer applies f (as unary) to each element before passing to rf.
                          ;; This is equivalent to (map f) as a transducer.
                          ((= (cl:length args) 0)
                           ;; Return a CL closure that acts as a transducer.
                           ;; apply-function handles CL functions via the generic dispatch.
                           #'(lambda (rf)
                               #'(lambda (result input)
                                   (apply-function rf
                                                   (cl:list result
                                                            (apply-function f (cl:list input)))))))
                          ;; (reduce f coll) - no initial value, f is binary (acc, elem) -> acc
                          ((= (cl:length args) 1)
                           (let* ((coll (cl:first args))
                                  (s (fol.seqop:seq coll)))
                             (if (or (null s) (fol.seqop:empty? s))
                                 (apply-function f nil)  ; call f with no args for empty coll
                                 (let ((acc (fol.seqop:first s))
                                       (s (fol.seqop:rest s)))
                                   (loop until (cl:or (null s) (fol.seqop:empty? s)
                                                      (fol.collection:<reduced>? acc))
                                         do (setf acc (apply-function f (cl:list acc (fol.seqop:first s))))
                                            (setf s (fol.seqop:rest s)))
                                   (fol.collection:unreduced acc)))))
                          ;; (reduce f init coll) - with initial value, f is binary (acc, elem) -> acc
                          ((= (cl:length args) 2)
                           (let* ((init (cl:first args))
                                  (coll (cl:second args))
                                  (s (fol.seqop:seq coll))
                                  (acc init))
                             (loop until (cl:or (null s) (fol.seqop:empty? s)
                                                (fol.collection:<reduced>? acc))
                                   do (setf acc (apply-function f (cl:list acc (fol.seqop:first s))))
                                      (setf s (fol.seqop:rest s)))
                             (fol.collection:unreduced acc)))
                          (t (error "reduce requires 1, 2, or 3 arguments"))))
            'map #'(lambda (f &rest args)
                     "Apply f to each element of coll.
                      (map f) - returns a transducer
                      (map f coll) - returns a lazy-seq of (f elem) for each elem in coll"
                     (cond
                       ;; (map f) - return a transducer
                       ((= (cl:length args) 0)
                        #'(lambda (rf)
                            #'(lambda (&rest xf-args)
                                (cl:case (cl:length xf-args)
                                  (0 (funcall rf))  ; init
                                  (1 (funcall rf (cl:first xf-args)))  ; completion
                                  (2 (funcall rf (cl:first xf-args)  ; step
                                              (apply-function f (cl:list (cl:second xf-args)))))))))
                       ;; (map f coll) - return lazy-seq
                       ((= (cl:length args) 1)
                        (let ((coll (cl:first args)))
                          (cl:labels ((map-seq (s)
                                        (fol.collection:make-lazy-seq
                                         (lambda ()
                                           (if (or (null s) (fol.seqop:empty? s))
                                               nil
                                               (cl:cons (apply-function f (cl:list (fol.seqop:first s)))
                                                        (map-seq (fol.seqop:rest s))))))))
                            (map-seq (fol.seqop:seq coll)))))
                       (t (error "map requires 1 or 2 arguments"))))
            'filter #'(lambda (pred &rest args)
                        "Return elements from coll for which pred returns truthy.
                         (filter pred) - returns a transducer
                         (filter pred coll) - returns a lazy-seq of elements where (pred elem) is truthy"
                        (cond
                          ;; (filter pred) - return a transducer
                          ((= (cl:length args) 0)
                           #'(lambda (rf)
                               #'(lambda (&rest xf-args)
                                   (cl:case (cl:length xf-args)
                                     (0 (funcall rf))  ; init
                                     (1 (funcall rf (cl:first xf-args)))  ; completion
                                     (2 (if (apply-function pred (cl:list (cl:second xf-args)))
                                            (funcall rf (cl:first xf-args) (cl:second xf-args))
                                            (cl:first xf-args)))))))
                          ;; (filter pred coll) - return lazy-seq
                          ((= (cl:length args) 1)
                           (let ((coll (cl:first args)))
                             (cl:labels ((filter-seq (s)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (cl:labels ((find-next (current)
                                                            (cond
                                                              ((or (null current) (fol.seqop:empty? current))
                                                               nil)
                                                              ((apply-function pred (cl:list (fol.seqop:first current)))
                                                               (cl:cons (fol.seqop:first current)
                                                                        (filter-seq (fol.seqop:rest current))))
                                                              (t (find-next (fol.seqop:rest current))))))
                                                (find-next s))))))
                               (filter-seq (fol.seqop:seq coll)))))
                          (t (error "filter requires 1 or 2 arguments"))))
            'remove #'(lambda (pred &rest args)
                        "Return elements from coll for which pred returns falsy.
                         (remove pred) - returns a transducer
                         (remove pred coll) - returns a lazy-seq of elements where (pred elem) is falsy"
                        (cond
                          ;; (remove pred) - return a transducer
                          ((= (cl:length args) 0)
                           #'(lambda (rf)
                               #'(lambda (result input)
                                   (if (apply-function pred (cl:list input))
                                       result
                                       (funcall rf result input)))))
                          ;; (remove pred coll) - return lazy-seq
                          ((= (cl:length args) 1)
                           (let ((coll (cl:first args)))
                             (cl:labels ((remove-seq (s)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (cl:labels ((find-next (current)
                                                            (cond
                                                              ((or (null current) (fol.seqop:empty? current))
                                                               nil)
                                                              ((not (apply-function pred (cl:list (fol.seqop:first current))))
                                                               (cl:cons (fol.seqop:first current)
                                                                        (remove-seq (fol.seqop:rest current))))
                                                              (t (find-next (fol.seqop:rest current))))))
                                                (find-next s))))))
                               (remove-seq (fol.seqop:seq coll)))))
                          (t (error "remove requires 1 or 2 arguments"))))
            'keep #'(lambda (f &rest args)
                      "Apply f to each element, keeping non-nil results.
                       (keep f) - returns a transducer
                       (keep f coll) - returns a lazy-seq of non-nil (f elem) results"
                      (cond
                        ;; (keep f) - return a transducer
                        ((= (cl:length args) 0)
                         #'(lambda (rf)
                             #'(lambda (result input)
                                 (let ((v (apply-function f (cl:list input))))
                                   (if v
                                       (funcall rf result v)
                                       result)))))
                        ;; (keep f coll) - return lazy-seq
                        ((= (cl:length args) 1)
                         (let ((coll (cl:first args)))
                           (cl:labels ((keep-seq (s)
                                         (fol.collection:make-lazy-seq
                                          (lambda ()
                                            (cl:labels ((find-next (current)
                                                          (cond
                                                            ((or (null current) (fol.seqop:empty? current))
                                                             nil)
                                                            (t (let ((v (apply-function f (cl:list (fol.seqop:first current)))))
                                                                 (if v
                                                                     (cl:cons v (keep-seq (fol.seqop:rest current)))
                                                                     (find-next (fol.seqop:rest current))))))))
                                              (find-next s))))))
                             (keep-seq (fol.seqop:seq coll)))))
                        (t (error "keep requires 1 or 2 arguments"))))
            'keep-indexed #'(lambda (f &rest args)
                              "Returns a lazy sequence of the non-nil results of (f index item).
                               (keep-indexed f) - returns a transducer
                               (keep-indexed f coll) - returns a lazy-seq of non-nil results"
                              (cond
                                ;; (keep-indexed f) - return a transducer
                                ((= (cl:length args) 0)
                                 (let ((idx -1))
                                   #'(lambda (rf)
                                       #'(lambda (result input)
                                           (cl:incf idx)
                                           (let ((v (apply-function f (cl:list idx input))))
                                             (if v
                                                 (funcall rf result v)
                                                 result))))))
                                ;; (keep-indexed f coll) - return lazy-seq
                                ((= (cl:length args) 1)
                                 (let ((coll (cl:first args)))
                                   (cl:labels ((keep-idx-seq (s idx)
                                                 (fol.collection:make-lazy-seq
                                                  (lambda ()
                                                    (cl:labels ((find-next (current i)
                                                                  (cond
                                                                    ((or (null current) (fol.seqop:empty? current))
                                                                     nil)
                                                                    (t (let ((v (apply-function f (cl:list i (fol.seqop:first current)))))
                                                                         (if v
                                                                             (cl:cons v (keep-idx-seq (fol.seqop:rest current) (cl:1+ i)))
                                                                             (find-next (fol.seqop:rest current) (cl:1+ i))))))))
                                                      (find-next s idx))))))
                                     (keep-idx-seq (fol.seqop:seq coll) 0))))
                                (t (error "keep-indexed requires 1 or 2 arguments"))))
            'map-indexed #'(lambda (f &rest args)
                             "Returns a lazy sequence of (f index item) for each item in coll.
                              (map-indexed f) - returns a transducer
                              (map-indexed f coll) - returns a lazy-seq of (f index item) results"
                             (cond
                               ;; (map-indexed f) - return a transducer
                               ((= (cl:length args) 0)
                                (let ((idx -1))
                                  #'(lambda (rf)
                                      #'(lambda (result input)
                                          (cl:incf idx)
                                          (funcall rf result (apply-function f (cl:list idx input)))))))
                               ;; (map-indexed f coll) - return lazy-seq
                               ((= (cl:length args) 1)
                                (let ((coll (cl:first args)))
                                  (cl:labels ((map-idx-seq (s idx)
                                                (fol.collection:make-lazy-seq
                                                 (lambda ()
                                                   (if (or (null s) (fol.seqop:empty? s))
                                                       nil
                                                       (cl:cons (apply-function f (cl:list idx (fol.seqop:first s)))
                                                                (map-idx-seq (fol.seqop:rest s) (cl:1+ idx))))))))
                                    (map-idx-seq (fol.seqop:seq coll) 0))))
                               (t (error "map-indexed requires 1 or 2 arguments"))))
            'mapcat #'(lambda (f &rest args)
                        "Apply f to each element, concatenating the results.
                         (mapcat f) - returns a transducer
                         (mapcat f coll) - returns a lazy-seq of elements from concatenated (f elem) results"
                        (cond
                          ;; (mapcat f) - return a transducer
                          ((= (cl:length args) 0)
                           #'(lambda (rf)
                               #'(lambda (result input)
                                   (let* ((coll (apply-function f (cl:list input)))
                                          (s (fol.seqop:seq coll))
                                          (acc result))
                                     (loop until (cl:or (null s) (fol.seqop:empty? s))
                                           do (setf acc (funcall rf acc (fol.seqop:first s)))
                                              (setf s (fol.seqop:rest s)))
                                     acc))))
                          ;; (mapcat f coll) - return lazy-seq
                          ((= (cl:length args) 1)
                           (let ((coll (cl:first args)))
                             (cl:labels ((concat-seqs (outer-s inner-s)
                                           ;; outer-s: sequence of input elements
                                           ;; inner-s: current inner sequence being consumed
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (cl:labels ((next-elem ()
                                                            (cond
                                                              ;; If inner-s has elements, return the first one
                                                              ((cl:and inner-s
                                                                       (cl:not (fol.seqop:empty? inner-s)))
                                                               (cl:cons (fol.seqop:first inner-s)
                                                                        (concat-seqs outer-s (fol.seqop:rest inner-s))))
                                                              ;; Otherwise, get next from outer
                                                              ((cl:or (null outer-s) (fol.seqop:empty? outer-s))
                                                               nil)
                                                              (t
                                                               (let* ((elem (fol.seqop:first outer-s))
                                                                      (new-inner (fol.seqop:seq
                                                                                  (apply-function f (cl:list elem)))))
                                                                 (funcall (fol.collection::lazy-seq-thunk
                                                                           (concat-seqs (fol.seqop:rest outer-s) new-inner))))))))
                                                (next-elem))))))
                               (concat-seqs (fol.seqop:seq coll) nil))))
                          (t (error "mapcat requires 1 or 2 arguments"))))
            'interleave #'(lambda (&rest colls)
                            "Return a lazy-seq of the first item in each coll, then second, etc.
                             (interleave coll1 coll2 ...) - interleaves elements from all collections"
                            (if (null colls)
                                (fol.collection:make-lazy-seq (lambda () nil))
                                (cl:labels ((interleave-seqs (seqs)
                                              (fol.collection:make-lazy-seq
                                               (lambda ()
                                                 ;; Check if any seq is exhausted
                                                 (if (cl:some (lambda (s) (or (null s) (fol.seqop:empty? s))) seqs)
                                                     nil
                                                     ;; Take first from each, then recurse with rests
                                                     (let ((firsts (cl:mapcar #'fol.seqop:first seqs))
                                                           (rests (cl:mapcar #'fol.seqop:rest seqs)))
                                                       (cl:labels ((build-result (items rest-seqs)
                                                                     (if (null items)
                                                                         (funcall (fol.collection::lazy-seq-thunk
                                                                                   (interleave-seqs rest-seqs)))
                                                                         (cl:cons (cl:first items)
                                                                                  (fol.collection:make-lazy-seq
                                                                                   (lambda ()
                                                                                     (build-result (cl:rest items) rest-seqs)))))))
                                                         (build-result firsts rests))))))))
                                  (interleave-seqs (cl:mapcar #'fol.seqop:seq colls)))))
            'interpose #'(lambda (sep &rest args)
                           "Return elements of coll separated by sep.
                            (interpose sep) - returns a transducer
                            (interpose sep coll) - returns a lazy-seq with sep between elements"
                           (cond
                             ;; (interpose sep) - return a transducer
                             ((= (cl:length args) 0)
                              (let ((started nil))
                                (declare (ignore started))
                                  #'(lambda (rf)
                                      (let ((started nil))
                                        #'(lambda (result input)
                                            (if started
                                                (funcall rf (funcall rf result sep) input)
                                                (progn
                                                  (setf started t)
                                                  (funcall rf result input))))))))
                             ;; (interpose sep coll) - return lazy-seq
                             ((= (cl:length args) 1)
                              (let ((coll (cl:first args)))
                                (cl:labels ((interpose-seq (s first-elem)
                                              (fol.collection:make-lazy-seq
                                               (lambda ()
                                                 (cond
                                                   ((or (null s) (fol.seqop:empty? s))
                                                    nil)
                                                   (first-elem
                                                    ;; First element: just return it
                                                    (cl:cons (fol.seqop:first s)
                                                             (interpose-seq (fol.seqop:rest s) nil)))
                                                   (t
                                                    ;; Not first: emit sep, then element
                                                    (cl:cons sep
                                                             (fol.collection:make-lazy-seq
                                                              (lambda ()
                                                                (cl:cons (fol.seqop:first s)
                                                                         (interpose-seq (fol.seqop:rest s) nil)))))))))))
                                  (interpose-seq (fol.seqop:seq coll) t))))
                             (t (error "interpose requires 1 or 2 arguments"))))
            ;; Lazy sequence generators
            'range #'(lambda (&rest args)
                       "Return a lazy sequence of numbers.
                        (range) - infinite sequence 0, 1, 2, ...
                        (range end) - 0, 1, ..., end-1
                        (range start end) - start, start+1, ..., end-1
                        (range start end step) - start, start+step, ... while in bounds"
                       (cl:labels ((make-range-seq (current end step)
                                     ;; Helper to create the lazy sequence
                                     (fol.collection:make-lazy-seq
                                      (lambda ()
                                        (cond
                                          ;; Infinite range (no end)
                                          ((null end)
                                           (cl:cons current (make-range-seq (cl:+ current step) nil step)))
                                          ;; Positive step: continue while current < end
                                          ((and (cl:> step 0) (cl:< current end))
                                           (cl:cons current (make-range-seq (cl:+ current step) end step)))
                                          ;; Negative step: continue while current > end
                                          ((and (cl:< step 0) (cl:> current end))
                                           (cl:cons current (make-range-seq (cl:+ current step) end step)))
                                          ;; Zero step is invalid, but if we get here just stop
                                          ;; Done - return nil for empty
                                          (t nil))))))
                         (case (cl:length args)
                           ;; (range) - infinite from 0
                           (0 (make-range-seq 0 nil 1))
                           ;; (range end) - 0 to end-1
                           (1 (let ((end (cl:first args)))
                                (if (cl:<= end 0)
                                    (fol.collection:make-lazy-seq (lambda () nil))
                                    (make-range-seq 0 end 1))))
                           ;; (range start end) - start to end-1
                           (2 (let ((start (cl:first args))
                                    (end (cl:second args)))
                                (if (cl:>= start end)
                                    (fol.collection:make-lazy-seq (lambda () nil))
                                    (make-range-seq start end 1))))
                           ;; (range start end step) - start, start+step, ...
                           (3 (let ((start (cl:first args))
                                    (end (cl:second args))
                                    (step (cl:third args)))
                                (cond
                                  ((cl:zerop step)
                                   (error "range step cannot be zero"))
                                  ;; Positive step but start >= end: empty
                                  ((and (cl:> step 0) (cl:>= start end))
                                   (fol.collection:make-lazy-seq (lambda () nil)))
                                  ;; Negative step but start <= end: empty
                                  ((and (cl:< step 0) (cl:<= start end))
                                   (fol.collection:make-lazy-seq (lambda () nil)))
                                  (t (make-range-seq start end step)))))
                           (otherwise (error "range takes 0 to 3 arguments")))))
            ;; Reduced: early termination for reduce
            'reduced #'fol.collection:reduced
            'reduced? #'fol.collection:<reduced>?
            'unreduced #'fol.collection:unreduced
            ;; Additional lazy sequence generators
            'iterate #'(lambda (f x)
                         "Returns a lazy sequence of x, (f x), (f (f x)), etc.
                          f must be free of side-effects."
                         (cl:labels ((iter-seq (val)
                                       (fol.collection:make-lazy-seq
                                        (lambda ()
                                          (cl:cons val (iter-seq (apply-function f (cl:list val))))))))
                           (iter-seq x)))
            'iteration #'(lambda (step &rest opts)
                           "Creates a lazy sequence by applying step to an initial value.
                            step is a function that takes a value and returns a map with keys
                            :some/:value for the value (if any) and :next for the next iteration seed.
                            Options:
                              :initk key - use this key to get next seed from result (default :next)
                              :somef fn - predicate to test if there's a value (default some?)
                              :vf fn - function to extract value from result (default :value)
                              :kf fn - function to extract next seed (default value of :initk)
                            Example: (iteration (fn [x] {:value x :next (inc x)}) :initk :next)"
                           (let* ((initk (or (cl:getf opts :initk) :next))
                                  (somef (or (cl:getf opts :somef)
                                             (lambda (x) (cl:not (null x)))))
                                  (vf (or (cl:getf opts :vf)
                                          (lambda (m) (fol.seqop:get m :value))))
                                  (kf (or (cl:getf opts :kf)
                                          (lambda (m) (fol.seqop:get m initk)))))
                             (cl:labels ((iter-seq (seed first-p)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (let ((result (apply-function step (cl:list seed))))
                                                (if (apply-function somef (cl:list result))
                                                    (let ((val (apply-function vf (cl:list result)))
                                                          (next-seed (apply-function kf (cl:list result))))
                                                      (if first-p
                                                          (cl:cons val (iter-seq next-seed nil))
                                                          (cl:cons val (iter-seq next-seed nil))))
                                                    nil))))))
                               (let ((initial (cl:getf opts initk)))
                                 (iter-seq initial t)))))
            'repeat #'(lambda (x &rest args)
                        "Returns a lazy sequence of xs.
                         (repeat x) - infinite sequence of x
                         (repeat n x) - sequence of x repeated n times"
                        (cond
                          ;; (repeat x) - infinite
                          ((= (cl:length args) 0)
                           (cl:labels ((repeat-seq ()
                                         (fol.collection:make-lazy-seq
                                          (lambda ()
                                            (cl:cons x (repeat-seq))))))
                             (repeat-seq)))
                          ;; (repeat n x) - n times
                          ((= (cl:length args) 1)
                           (let ((n x)
                                 (val (cl:first args)))
                             (cl:labels ((repeat-n (remaining)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (if (cl:<= remaining 0)
                                                  nil
                                                  (cl:cons val (repeat-n (cl:1- remaining))))))))
                               (repeat-n n))))
                          (t (error "repeat takes 1 or 2 arguments"))))
            'repeatedly #'(lambda (f &rest args)
                            "Returns a lazy sequence of calls to f (which should have side effects).
                             (repeatedly f) - infinite sequence of (f)
                             (repeatedly n f) - sequence of n calls to (f)"
                            (cond
                              ;; (repeatedly f) - infinite
                              ((= (cl:length args) 0)
                               (cl:labels ((repeat-seq ()
                                             (fol.collection:make-lazy-seq
                                              (lambda ()
                                                (cl:cons (apply-function f nil) (repeat-seq))))))
                                 (repeat-seq)))
                              ;; (repeatedly n f) - n times
                              ((= (cl:length args) 1)
                               (let ((n f)
                                     (fn (cl:first args)))
                                 (cl:labels ((repeat-n (remaining)
                                               (fol.collection:make-lazy-seq
                                                (lambda ()
                                                  (if (cl:<= remaining 0)
                                                      nil
                                                      (cl:cons (apply-function fn nil) (repeat-n (cl:1- remaining))))))))
                                   (repeat-n n))))
                              (t (error "repeatedly takes 1 or 2 arguments"))))
            'cycle #'(lambda (coll)
                       "Returns a lazy (infinite!) sequence of repetitions of the items in coll."
                       (let ((s (fol.seqop:seq coll)))
                         (if (or (null s) (fol.seqop:empty? s))
                             (fol.collection:make-lazy-seq (lambda () nil))
                             (cl:labels ((cycle-seq (current)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (if (or (null current) (fol.seqop:empty? current))
                                                  ;; Restart from beginning
                                                  (funcall (fol.collection::lazy-seq-thunk (cycle-seq s)))
                                                  (cl:cons (fol.seqop:first current)
                                                           (cycle-seq (fol.seqop:rest current))))))))
                               (cycle-seq s)))))
            'tree-seq #'(lambda (branch? children root)
                          "Returns a lazy sequence of the nodes in a tree, via a depth-first walk.
                           branch? is a function that returns true if a node can have children.
                           children is a function that returns the children of a node.
                           root is the root node of the tree.
                           Example: (tree-seq coll? seq {:a [1 2] :b [3 4]}) walks the tree"
                          ;; Simple recursive tree walk using mapcat-like logic
                          (cl:labels ((lazy-concat (s1 s2)
                                        (fol.collection:make-lazy-seq
                                         (lambda ()
                                           (if (or (null s1) (fol.seqop:empty? s1))
                                               (if s2
                                                   (funcall (fol.collection::lazy-seq-thunk s2))
                                                   nil)
                                               (cl:cons (fol.seqop:first s1)
                                                        (lazy-concat (fol.seqop:rest s1) s2))))))
                                      (walk (node)
                                        (fol.collection:make-lazy-seq
                                         (lambda ()
                                           (if (apply-function branch? (cl:list node))
                                               ;; Branch node: cons node, then walk children
                                               (let* ((kids (apply-function children (cl:list node)))
                                                      (kid-seq (fol.seqop:seq kids)))
                                                 (cl:cons node (walk-children kid-seq)))
                                               ;; Leaf node: just cons the node with nil
                                               (cl:cons node nil)))))
                                      (walk-children (child-seq)
                                        (fol.collection:make-lazy-seq
                                         (lambda ()
                                           (if (or (null child-seq) (fol.seqop:empty? child-seq))
                                               nil
                                               (let ((child (fol.seqop:first child-seq)))
                                                 (funcall (fol.collection::lazy-seq-thunk
                                                           (lazy-concat (walk child)
                                                                        (walk-children (fol.seqop:rest child-seq)))))))))))
                            (walk root)))
            'take #'(lambda (n &rest args)
                      "Returns a lazy sequence of the first n items in coll, or all items if there are fewer than n.
                       (take n) - returns a transducer
                       (take n coll) - returns a lazy-seq of the first n items"
                      (cond
                        ;; (take n) - return a transducer
                        ((cl:= (cl:length args) 0)
                         (let ((remaining n))
                           #'(lambda (rf)
                               (let ((taken 0))
                                 #'(lambda (result input)
                                     (if (cl:< taken remaining)
                                         (progn
                                           (cl:incf taken)
                                           (let ((new-result (funcall rf result input)))
                                             (if (cl:= taken remaining)
                                                 (fol.collection:reduced new-result)
                                                 new-result)))
                                         (fol.collection:reduced result)))))))
                        ;; (take n coll) - return lazy-seq
                        ((cl:= (cl:length args) 1)
                         (let ((coll (cl:first args)))
                           (cl:labels ((take-seq (remaining s)
                                         (fol.collection:make-lazy-seq
                                          (lambda ()
                                            (if (cl:or (cl:<= remaining 0)
                                                       (null s)
                                                       (fol.seqop:empty? s))
                                                nil
                                                (cl:cons (fol.seqop:first s)
                                                         (take-seq (cl:1- remaining)
                                                                   (fol.seqop:rest s))))))))
                             (take-seq n (fol.seqop:seq coll)))))
                        (t (error "take requires 1 or 2 arguments"))))
            'drop #'(lambda (n &rest args)
                      "Returns a lazy sequence of all but the first n items in coll.
                       (drop n) - returns a transducer
                       (drop n coll) - returns a lazy-seq of all but the first n items"
                      (cond
                        ;; (drop n) - return a transducer
                        ((cl:= (cl:length args) 0)
                         (let ((to-drop n))
                           #'(lambda (rf)
                               (let ((dropped 0))
                                 #'(lambda (result input)
                                     (if (cl:< dropped to-drop)
                                         (progn
                                           (cl:incf dropped)
                                           result)
                                         (funcall rf result input)))))))
                        ;; (drop n coll) - return lazy-seq
                        ((cl:= (cl:length args) 1)
                         (let ((coll (cl:first args)))
                           (cl:labels ((drop-items (remaining s)
                                         ;; Eagerly drop n items, then return lazy seq of rest
                                         (if (cl:or (cl:<= remaining 0)
                                                    (null s)
                                                    (fol.seqop:empty? s))
                                             s
                                             (drop-items (cl:1- remaining) (fol.seqop:rest s)))))
                             (let ((remaining-seq (drop-items n (fol.seqop:seq coll))))
                               ;; Wrap remaining sequence in a lazy-seq for consistency
                               (cl:labels ((lazy-rest (s)
                                             (fol.collection:make-lazy-seq
                                              (lambda ()
                                                (if (cl:or (null s) (fol.seqop:empty? s))
                                                    nil
                                                    (cl:cons (fol.seqop:first s)
                                                             (lazy-rest (fol.seqop:rest s))))))))
                                 (lazy-rest remaining-seq))))))
                        (t (error "drop requires 1 or 2 arguments"))))
            ;; Additional functional utilities
            'constantly #'(lambda (x)
                            "Returns a function that takes any number of arguments and returns x."
                            (lambda (&rest args)
                              (declare (ignore args))
                              x))
            'comp #'(lambda (&rest fns)
                      "Takes a set of functions and returns a fn that is the composition
                       of those fns. The returned fn takes a variable number of args,
                       applies the rightmost of fns to the args, the next fn (right-to-left)
                       to the result, etc.
                       ((comp f g h) x y) is equivalent to (f (g (h x y)))"
                      (if (null fns)
                          #'cl:identity
                          (let ((fns-rev (cl:reverse fns)))
                            (lambda (&rest args)
                              (let ((result (apply-function (cl:first fns-rev) args)))
                                (dolist (f (cl:rest fns-rev))
                                  (setf result (apply-function f (cl:list result))))
                                result)))))
            'memoize #'(lambda (f)
                         "Returns a memoized version of a referentially transparent function.
                          The memoized version of the function keeps a cache of the mapping
                          from arguments to results and, when calls with the same arguments
                          are repeated often, has higher performance at the expense of
                          higher memory use."
                         (let ((cache (make-hash-table :test 'equal)))
                           (lambda (&rest args)
                             (let ((key args))
                               (multiple-value-bind (cached-val found)
                                   (gethash key cache)
                                 (if found
                                     cached-val
                                     (let ((result (apply-function f args)))
                                       (setf (gethash key cache) result)
                                       result)))))))
            'fnil #'(lambda (f &rest defaults)
                      "Takes a function f, and returns a function that calls f, replacing
                       a nil first argument with the first default, a nil second argument
                       with the second default, etc."
                      (let ((num-defaults (cl:length defaults)))
                        (lambda (&rest args)
                          (let ((patched-args
                                  (loop for arg in args
                                        for i from 0
                                        collect (if (cl:and (null arg)
                                                            (cl:< i num-defaults))
                                                    (cl:nth i defaults)
                                                    arg))))
                            (apply-function f patched-args)))))
            ;; Function predicate
            'fn? #'(lambda (x)
                     "Returns true if x is a function (FOL function, macro, or CL function)."
                     (cl:or (<function>? x)
                            (functionp x)))
            ;; Utility predicates and functions
            'nil? #'(lambda (x)
                      "Returns true if x is nil."
                      (null x))
            'some? #'(lambda (x)
                       "Returns true if x is not nil."
                       (cl:not (null x)))
            'not= #'(lambda (&rest args)
                      "Same as (not (= ...))."
                      (cl:not (apply #'cl:= args)))
            'compare #'(lambda (x y)
                         "Comparator. Returns a negative number, zero, or a positive number
                          when x is logically 'less than', 'equal to', or 'greater than' y.
                          Works for numbers, strings, and keywords."
                         (cond
                           ((cl:and (numberp x) (numberp y))
                            (cond ((cl:< x y) -1)
                                  ((cl:> x y) 1)
                                  (t 0)))
                           ((cl:and (stringp x) (stringp y))
                            (cond ((string< x y) -1)
                                  ((string> x y) 1)
                                  (t 0)))
                           ((cl:and (keywordp x) (keywordp y))
                            (let ((sx (symbol-name x))
                                  (sy (symbol-name y)))
                              (cond ((string< sx sy) -1)
                                    ((string> sx sy) 1)
                                    (t 0))))
                           ((cl:and (symbolp x) (symbolp y))
                            (let ((sx (symbol-name x))
                                  (sy (symbol-name y)))
                              (cond ((string< sx sy) -1)
                                    ((string> sx sy) 1)
                                    (t 0))))
                           (t (error "compare not supported for these types"))))
            'instance? #'(lambda (x type)
                           "Evaluates x and tests if it is an instance of the type."
                           (let ((type-sym (if (symbolp type) type
                                               (if (<symbol>? type)
                                                   (fol.wrappers:fol-value type)
                                                   type))))
                             (typep x (cl:find-class type-sym nil))))
            'some #'(lambda (pred &rest colls)
                      "Returns the first logical true value of (pred x) for any x in coll,
                       else nil. One common idiom is to use a set as pred, for example
                       this will return :fred if :fred is in the sequence, otherwise nil:
                       (some #{:fred} coll)"
                      (if (null colls)
                          nil
                          (let ((coll (cl:first colls)))
                            (let ((s (fol.seqop:seq coll)))
                              (loop until (cl:or (null s) (fol.seqop:empty? s))
                                    for elem = (fol.seqop:first s)
                                    for result = (apply-function pred (cl:list elem))
                                    when result return result
                                    do (setf s (fol.seqop:rest s))
                                    finally (return nil))))))
            'every #'(lambda (pred &rest colls)
                       "Returns true if (pred x) is logical true for every x in coll, else false."
                       (if (null colls)
                           t
                           (let ((coll (cl:first colls)))
                             (let ((s (fol.seqop:seq coll)))
                               (loop until (cl:or (null s) (fol.seqop:empty? s))
                                     for elem = (fol.seqop:first s)
                                     for result = (apply-function pred (cl:list elem))
                                     unless result return nil
                                     do (setf s (fol.seqop:rest s))
                                     finally (return t))))))
            'not-any #'(lambda (pred &rest colls)
                         "Returns false if (pred x) is logical true for any x in coll, else true."
                         (if (null colls)
                             t
                             (let ((coll (cl:first colls)))
                               (let ((s (fol.seqop:seq coll)))
                                 (loop until (cl:or (null s) (fol.seqop:empty? s))
                                       for elem = (fol.seqop:first s)
                                       for result = (apply-function pred (cl:list elem))
                                       when result return nil
                                       do (setf s (fol.seqop:rest s))
                                       finally (return t))))))
            'not-every #'(lambda (pred &rest colls)
                           "Returns false if (pred x) is logical true for every x in coll, else true."
                           (if (null colls)
                               nil
                               (let ((coll (cl:first colls)))
                                 (let ((s (fol.seqop:seq coll)))
                                   (loop until (cl:or (null s) (fol.seqop:empty? s))
                                         for elem = (fol.seqop:first s)
                                         for result = (apply-function pred (cl:list elem))
                                         unless result return t
                                         do (setf s (fol.seqop:rest s))
                                         finally (return nil))))))
            ;; Relational algebra functions (operate on collections of maps)
            'rel-join #'(lambda (xrel yrel &rest keyvals)
                          "Returns the natural join of xrel and yrel (collections of maps).
                           When called with keyvals, joins on the specified keys.
                           Example: (rel-join [{:a 1 :b 2}] [{:a 1 :c 3}]) => [{:a 1 :b 2 :c 3}]"
                          (let* ((km (when keyvals
                                       ;; Build a map from keyvals
                                       (loop with result = (fset:empty-map)
                                             for (k v) on keyvals by #'cddr
                                             do (setf result (fset:with result k v))
                                             finally (return result))))
                                 (xs (fol.seqop:seq xrel))
                                 (result nil))
                            (loop until (cl:or (null xs) (fol.seqop:empty? xs))
                                  for x = (fol.seqop:first xs)
                                  do (let ((ys (fol.seqop:seq yrel)))
                                       (loop until (cl:or (null ys) (fol.seqop:empty? ys))
                                             for y = (fol.seqop:first ys)
                                             for matches = (if km
                                                               ;; Check specified keys match
                                                               (loop for k being the hash-keys of km
                                                                     always (equal (fol.seqop:get x k)
                                                                                   (fol.seqop:get y (gethash k km))))
                                                               ;; Natural join: match on common keys
                                                               (let ((x-keys (fol.seqop:keys x))
                                                                     (y-keys (fol.seqop:keys y)))
                                                                 (loop for xk in (if x-keys
                                                                                     (loop for s = (fol.seqop:seq x-keys) then (fol.seqop:rest s)
                                                                                           until (cl:or (null s) (fol.seqop:empty? s))
                                                                                           collect (fol.seqop:first s))
                                                                                     nil)
                                                                       always (cl:or (cl:not (fol.seqop:contains? y xk))
                                                                                     (equal (fol.seqop:get x xk)
                                                                                            (fol.seqop:get y xk))))))
                                             when matches
                                               do (cl:push (fol.seqop:merge x y) result)
                                             do (setf ys (fol.seqop:rest ys))))
                                     (setf xs (fol.seqop:rest xs)))
                            (apply #'fol.collection:make-set (cl:nreverse result))))
            'project #'(lambda (rel ks)
                         "Returns a relation with only the specified keys.
                          Example: (project [{:a 1 :b 2 :c 3}] [:a :b]) => #{{:a 1 :b 2}}"
                         (let ((key-set (if (<vector>? ks)
                                            (loop for i from 0 below (fol.seqop:size ks)
                                                  collect (fol.seqop:nth ks i))
                                            (loop for s = (fol.seqop:seq ks) then (fol.seqop:rest s)
                                                  until (cl:or (null s) (fol.seqop:empty? s))
                                                  collect (fol.seqop:first s))))
                               (result nil))
                           (let ((s (fol.seqop:seq rel)))
                             (loop until (cl:or (null s) (fol.seqop:empty? s))
                                   for row = (fol.seqop:first s)
                                   for projected = (fol.seqop:select-keys row key-set)
                                   do (cl:push projected result)
                                      (setf s (fol.seqop:rest s))))
                           (apply #'fol.collection:make-set (cl:nreverse result))))
            'rename #'(lambda (rel kmap)
                        "Returns a relation with keys renamed according to kmap.
                         Example: (rename [{:a 1 :b 2}] {:a :x}) => #{{:x 1 :b 2}}"
                        (let ((result nil))
                          (let ((s (fol.seqop:seq rel)))
                            (loop until (cl:or (null s) (fol.seqop:empty? s))
                                  for row = (fol.seqop:first s)
                                  for renamed = (fol.seqop:rename-keys row kmap)
                                  do (cl:push renamed result)
                                     (setf s (fol.seqop:rest s))))
                          (apply #'fol.collection:make-set (cl:nreverse result))))
            ;; Trampoline for mutual recursion
            'trampoline #'(lambda (f &rest args)
                            "trampoline can be used to convert algorithms requiring mutual
                             recursion without stack consumption. Calls f with supplied args,
                             if any. If f returns a fn, calls that fn with no arguments,
                             and continues to repeat, until the return value is not a fn,
                             then returns that non-fn value."
                            (let ((result (apply-function f args)))
                              (loop while (cl:or (functionp result)
                                                 (<function>? result))
                                    do (setf result (apply-function result nil)))
                              result))
            ;; Threading macro helpers (implemented as functions)
            'as->-helper #'(lambda (val &rest forms)
                             "Helper for as-> macro. Not intended for direct use."
                             val)  ; as-> is special-handled, this is fallback
            'cond->-helper #'(lambda (val &rest clauses)
                               "Helper for cond-> macro."
                               (loop with result = val
                                     for (test form) on clauses by #'cddr
                                     when test
                                       do (setf result (apply-threaded result form :first nil))
                                     finally (return result)))
            'cond->>-helper #'(lambda (val &rest clauses)
                                "Helper for cond->> macro."
                                (loop with result = val
                                      for (test form) on clauses by #'cddr
                                      when test
                                        do (setf result (apply-threaded result form :last nil))
                                      finally (return result)))
            'some->-helper #'(lambda (val &rest forms)
                               "Helper for some-> macro."
                               (loop with result = val
                                     for form in forms
                                     while result
                                     do (setf result (apply-threaded result form :first nil))
                                     finally (return result)))
            'some->>-helper #'(lambda (val &rest forms)
                                "Helper for some->> macro."
                                (loop with result = val
                                      for form in forms
                                      while result
                                      do (setf result (apply-threaded result form :last nil))
                                      finally (return result)))
            'condp-helper #'(lambda (pred expr &rest clauses)
                              "Helper for condp macro."
                              (let* ((num-clauses (length clauses))
                                     (has-default (oddp num-clauses))
                                     (pairs (if has-default (butlast clauses) clauses))
                                     (default (when has-default (car (last clauses)))))
                                (loop for (test-val result-form) on pairs by #'cddr
                                      when (apply-function pred (list test-val expr))
                                        return (if (cl:and (consp result-form)
                                                           (eq (car result-form) :>>))
                                                   ;; :>> syntax: apply result-fn to matched value
                                                   (apply-function (cadr result-form) (list test-val))
                                                   result-form)
                                      finally (return default))))
            'lazy-cat-helper #'(lambda (&rest colls)
                                 "Helper for lazy-cat macro. Lazily concatenates collections."
                                 (if (null colls)
                                     nil
                                     (cl:labels ((cat-seq (remaining-colls current-seq)
                                                   (fol.collection:make-lazy-seq
                                                    (lambda ()
                                                      (cond
                                                        ;; Current seq has elements
                                                        ((cl:and current-seq (cl:not (fol.seqop:empty? current-seq)))
                                                         (cl:cons (fol.seqop:first current-seq)
                                                                  (cat-seq remaining-colls (fol.seqop:rest current-seq))))
                                                        ;; Move to next coll
                                                        ((cl:not (null remaining-colls))
                                                         (let ((next-seq (fol.seqop:seq (car remaining-colls))))
                                                           (funcall (fol.collection::lazy-seq-thunk
                                                                     (cat-seq (cdr remaining-colls) next-seq)))))
                                                        ;; Done
                                                        (t nil))))))
                                       (cat-seq (cdr colls) (fol.seqop:seq (car colls))))))
            ;; Delay support
            'make-delay #'(lambda (thunk)
                            "Create a delay object from a thunk."
                            (let ((realized nil)
                                  (value nil))
                              (lambda (&optional force-flag)
                                (when (eq force-flag :force)
                                  (unless realized
                                    (setf value (apply-function thunk nil))
                                    (setf realized t)))
                                value)))
            'force #'(lambda (delay-obj)
                       "Force evaluation of a delay and return its value."
                       (if (functionp delay-obj)
                           (progn
                             (funcall delay-obj :force)
                             (funcall delay-obj))
                           delay-obj))
            'deref #'(lambda (delay-obj)
                       "Dereference a delay, forcing its evaluation and returning its value.
                        This is an alias for force."
                       (if (functionp delay-obj)
                           (progn
                             (funcall delay-obj :force)
                             (funcall delay-obj))
                           delay-obj))
            'delay? #'(lambda (x)
                        "Returns true if x is a delay."
                        (functionp x))  ; Simplified check
            'realized? #'(lambda (x)
                           "Returns true if a value has been realized (lazy-seq or delay).
                            For lazy-seqs, returns true if the thunk has been called.
                            For delays, returns true if forced."
                           (cond
                             ((fol.collection:<lazy-seq>? x)
                              (fol.collection:lazy-seq-realized-p x))
                             ;; For other types, they're always "realized"
                             (t t)))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 1: Lazy Transformations
            ;; ============================================================
            'distinct #'(lambda (&rest args)
                          "Returns a lazy sequence of the elements of coll with duplicates removed.
                           (distinct) - returns a transducer
                           (distinct coll) - returns a lazy-seq"
                          (cond
                            ;; (distinct) - return a transducer
                            ((cl:= (cl:length args) 0)
                             (let ((seen (make-hash-table :test 'equal)))
                               #'(lambda (rf)
                                   #'(lambda (result input)
                                       (if (gethash input seen)
                                           result
                                           (progn
                                             (setf (gethash input seen) t)
                                             (funcall rf result input)))))))
                            ;; (distinct coll) - return lazy-seq
                            ((cl:= (cl:length args) 1)
                             (let ((coll (cl:first args)))
                               (let ((seen (make-hash-table :test 'equal)))
                                 (cl:labels ((distinct-seq (s)
                                               (fol.collection:make-lazy-seq
                                                (lambda ()
                                                  (cl:labels ((find-next (current)
                                                                (cond
                                                                  ((cl:or (null current) (fol.seqop:empty? current))
                                                                   nil)
                                                                  ((gethash (fol.seqop:first current) seen)
                                                                   (find-next (fol.seqop:rest current)))
                                                                  (t
                                                                   (let ((item (fol.seqop:first current)))
                                                                     (setf (gethash item seen) t)
                                                                     (cl:cons item (distinct-seq (fol.seqop:rest current))))))))
                                                    (find-next s))))))
                                   (distinct-seq (fol.seqop:seq coll))))))
                            (t (error "distinct requires 0 or 1 arguments"))))
            'take-nth #'(lambda (n &rest args)
                          "Returns a lazy seq of every nth item in coll.
                           (take-nth n) - returns a transducer
                           (take-nth n coll) - returns a lazy-seq"
                          (cond
                            ;; (take-nth n) - return a transducer
                            ((cl:= (cl:length args) 0)
                             (let ((idx -1))
                               #'(lambda (rf)
                                   #'(lambda (result input)
                                       (cl:incf idx)
                                       (if (cl:zerop (cl:mod idx n))
                                           (funcall rf result input)
                                           result)))))
                            ;; (take-nth n coll) - return lazy-seq
                            ((cl:= (cl:length args) 1)
                             (let ((coll (cl:first args)))
                               (cl:labels ((take-nth-seq (s idx)
                                             (fol.collection:make-lazy-seq
                                              (lambda ()
                                                (if (cl:or (null s) (fol.seqop:empty? s))
                                                    nil
                                                    (if (cl:zerop (cl:mod idx n))
                                                        (cl:cons (fol.seqop:first s)
                                                                 (take-nth-seq (fol.seqop:rest s) (cl:1+ idx)))
                                                        (funcall (fol.collection::lazy-seq-thunk
                                                                  (take-nth-seq (fol.seqop:rest s) (cl:1+ idx))))))))))
                                 (take-nth-seq (fol.seqop:seq coll) 0))))
                            (t (error "take-nth requires 1 or 2 arguments"))))
            'dedupe #'(lambda (&rest args)
                        "Returns a lazy sequence removing consecutive duplicates in coll.
                         (dedupe) - returns a transducer
                         (dedupe coll) - returns a lazy-seq"
                        (cond
                          ;; (dedupe) - return a transducer
                          ((cl:= (cl:length args) 0)
                           (let ((prev :fol-dedupe-none))
                             #'(lambda (rf)
                                 #'(lambda (result input)
                                     (if (equal input prev)
                                         result
                                         (progn
                                           (setf prev input)
                                           (funcall rf result input)))))))
                          ;; (dedupe coll) - return lazy-seq
                          ((cl:= (cl:length args) 1)
                           (let ((coll (cl:first args)))
                             (cl:labels ((dedupe-seq (s prev)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (cl:labels ((find-next (current last-val)
                                                            (cond
                                                              ((cl:or (null current) (fol.seqop:empty? current))
                                                               nil)
                                                              ((equal (fol.seqop:first current) last-val)
                                                               (find-next (fol.seqop:rest current) last-val))
                                                              (t
                                                               (let ((item (fol.seqop:first current)))
                                                                 (cl:cons item (dedupe-seq (fol.seqop:rest current) item)))))))
                                                (find-next s prev))))))
                               (dedupe-seq (fol.seqop:seq coll) :fol-dedupe-none))))
                          (t (error "dedupe requires 0 or 1 arguments"))))
            'random-sample #'(lambda (prob &rest args)
                               "Returns items from coll with random probability prob (0.0 to 1.0).
                                (random-sample prob) - returns a transducer
                                (random-sample prob coll) - returns a lazy-seq"
                               (cond
                                 ;; (random-sample prob) - return a transducer
                                 ((cl:= (cl:length args) 0)
                                  #'(lambda (rf)
                                      #'(lambda (result input)
                                          (if (cl:< (cl:random 1.0) prob)
                                              (funcall rf result input)
                                              result))))
                                 ;; (random-sample prob coll) - return lazy-seq
                                 ((cl:= (cl:length args) 1)
                                  (let ((coll (cl:first args)))
                                    (cl:labels ((sample-seq (s)
                                                  (fol.collection:make-lazy-seq
                                                   (lambda ()
                                                     (cl:labels ((find-next (current)
                                                                   (cond
                                                                     ((cl:or (null current) (fol.seqop:empty? current))
                                                                      nil)
                                                                     ((cl:< (cl:random 1.0) prob)
                                                                      (cl:cons (fol.seqop:first current)
                                                                               (sample-seq (fol.seqop:rest current))))
                                                                     (t (find-next (fol.seqop:rest current))))))
                                                       (find-next s))))))
                                      (sample-seq (fol.seqop:seq coll)))))
                                 (t (error "random-sample requires 1 or 2 arguments"))))
            'concat #'(lambda (&rest colls)
                        "Returns a lazy seq representing the concatenation of the elements in the supplied colls."
                        (if (null colls)
                            nil
                            (cl:labels ((cat-seq (remaining-colls current-seq)
                                          (fol.collection:make-lazy-seq
                                           (lambda ()
                                             (cond
                                               ;; Current seq has elements
                                               ((cl:and current-seq (cl:not (fol.seqop:empty? current-seq)))
                                                (cl:cons (fol.seqop:first current-seq)
                                                         (cat-seq remaining-colls (fol.seqop:rest current-seq))))
                                               ;; Move to next coll
                                               ((cl:not (null remaining-colls))
                                                (let ((next-seq (fol.seqop:seq (car remaining-colls))))
                                                  (funcall (fol.collection::lazy-seq-thunk
                                                            (cat-seq (cdr remaining-colls) next-seq)))))
                                               ;; Done
                                               (t nil))))))
                              (cat-seq (cdr colls) (fol.seqop:seq (car colls))))))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 2: Drop/Take Variants
            ;; ============================================================
            'nthrest #'(lambda (coll n)
                         "Returns the nth rest of coll, coll when n is 0."
                         (let ((s (fol.seqop:seq coll)))
                           (cl:labels ((drop-n (current remaining)
                                         (if (cl:or (cl:<= remaining 0)
                                                    (null current)
                                                    (fol.seqop:empty? current))
                                             current
                                             (drop-n (fol.seqop:rest current) (cl:1- remaining)))))
                             (drop-n s n))))
            'next #'(lambda (coll)
                      "Returns a seq of the items after the first. Calls seq on its argument.
                       If there are no more items, returns nil."
                      (let ((s (fol.seqop:seq coll)))
                        (if (cl:or (null s) (fol.seqop:empty? s))
                            nil
                            (let ((r (fol.seqop:rest s)))
                              (if (cl:or (null r) (fol.seqop:empty? r))
                                  nil
                                  r)))))
            'fnext #'(lambda (coll)
                       "Same as (first (next x))."
                       (let ((s (fol.seqop:seq coll)))
                         (if (cl:or (null s) (fol.seqop:empty? s))
                             nil
                             (fol.seqop:first (fol.seqop:rest s)))))
            'nnext #'(lambda (coll)
                       "Same as (next (next x))."
                       (let ((s (fol.seqop:seq coll)))
                         (if (cl:or (null s) (fol.seqop:empty? s))
                             nil
                             (let ((r1 (fol.seqop:rest s)))
                               (if (cl:or (null r1) (fol.seqop:empty? r1))
                                   nil
                                   (let ((r2 (fol.seqop:rest r1)))
                                     (if (cl:or (null r2) (fol.seqop:empty? r2))
                                         nil
                                         r2)))))))
            'drop-while #'(lambda (pred &rest args)
                            "Returns a lazy sequence of the items in coll starting from the
                             first item for which (pred item) returns logical false.
                             (drop-while pred) - returns a transducer
                             (drop-while pred coll) - returns a lazy-seq"
                            (cond
                              ;; (drop-while pred) - return a transducer
                              ((cl:= (cl:length args) 0)
                               (let ((dropping t))
                                 #'(lambda (rf)
                                     #'(lambda (result input)
                                         (if dropping
                                             (if (apply-function pred (cl:list input))
                                                 result
                                                 (progn
                                                   (setf dropping nil)
                                                   (funcall rf result input)))
                                             (funcall rf result input))))))
                              ;; (drop-while pred coll) - return lazy-seq
                              ((cl:= (cl:length args) 1)
                               (let ((coll (cl:first args)))
                                 (cl:labels ((drop-matching (s)
                                               (cond
                                                 ((cl:or (null s) (fol.seqop:empty? s))
                                                  nil)
                                                 ((apply-function pred (cl:list (fol.seqop:first s)))
                                                  (drop-matching (fol.seqop:rest s)))
                                                 (t s))))
                                   ;; Wrap remaining sequence in a lazy-seq
                                   (let ((remaining (drop-matching (fol.seqop:seq coll))))
                                     (cl:labels ((lazy-rest (s)
                                                   (fol.collection:make-lazy-seq
                                                    (lambda ()
                                                      (if (cl:or (null s) (fol.seqop:empty? s))
                                                          nil
                                                          (cl:cons (fol.seqop:first s)
                                                                   (lazy-rest (fol.seqop:rest s))))))))
                                       (lazy-rest remaining))))))
                              (t (error "drop-while requires 1 or 2 arguments"))))
            'take-while #'(lambda (pred &rest args)
                            "Returns a lazy sequence of successive items from coll while
                             (pred item) returns logical true.
                             (take-while pred) - returns a transducer
                             (take-while pred coll) - returns a lazy-seq"
                            (cond
                              ;; (take-while pred) - return a transducer
                              ((cl:= (cl:length args) 0)
                               #'(lambda (rf)
                                   #'(lambda (result input)
                                       (if (apply-function pred (cl:list input))
                                           (funcall rf result input)
                                           (fol.collection:reduced result)))))
                              ;; (take-while pred coll) - return lazy-seq
                              ((cl:= (cl:length args) 1)
                               (let ((coll (cl:first args)))
                                 (cl:labels ((take-seq (s)
                                               (fol.collection:make-lazy-seq
                                                (lambda ()
                                                  (if (cl:or (null s) (fol.seqop:empty? s))
                                                      nil
                                                      (let ((item (fol.seqop:first s)))
                                                        (if (apply-function pred (cl:list item))
                                                            (cl:cons item (take-seq (fol.seqop:rest s)))
                                                            nil)))))))
                                   (take-seq (fol.seqop:seq coll)))))
                              (t (error "take-while requires 1 or 2 arguments"))))
            'take-last #'(lambda (n coll)
                           "Returns a seq of the last n items in coll. Depending on the type,
                            seq may not be lazy."
                           (let ((s (fol.seqop:seq coll)))
                             (if (cl:or (null s) (fol.seqop:empty? s))
                                 nil
                                 ;; Use a sliding window approach
                                 (let ((lead s)
                                       (lag s))
                                   ;; Advance lead by n positions
                                   (dotimes (i n)
                                     (when (cl:and lead (cl:not (fol.seqop:empty? lead)))
                                       (setf lead (fol.seqop:rest lead))))
                                   ;; Now advance both until lead is exhausted
                                   (loop while (cl:and lead (cl:not (fol.seqop:empty? lead)))
                                         do (setf lead (fol.seqop:rest lead))
                                            (setf lag (fol.seqop:rest lag)))
                                   lag))))
            'drop-last #'(lambda (&rest args)
                           "Return a lazy sequence of all but the last n (default 1) items in coll.
                            (drop-last coll) - drops last 1 item
                            (drop-last n coll) - drops last n items"
                           (let ((n (if (cl:= (cl:length args) 1) 1 (cl:first args)))
                                 (coll (if (cl:= (cl:length args) 1) (cl:first args) (cl:second args))))
                             (cl:labels ((drop-last-seq (s lead)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (if (cl:or (null lead) (fol.seqop:empty? lead))
                                                  nil
                                                  (cl:cons (fol.seqop:first s)
                                                           (drop-last-seq (fol.seqop:rest s)
                                                                          (fol.seqop:rest lead))))))))
                               (let ((s (fol.seqop:seq coll)))
                                 ;; Advance lead by n positions
                                 (let ((lead s))
                                   (dotimes (i n)
                                     (when (cl:and lead (cl:not (fol.seqop:empty? lead)))
                                       (setf lead (fol.seqop:rest lead))))
                                   (drop-last-seq s lead))))))
            'butlast #'(lambda (coll)
                         "Return a seq of all but the last item in coll, in linear time."
                         (let ((s (fol.seqop:seq coll)))
                           (if (cl:or (null s) (fol.seqop:empty? s))
                               nil
                               (let ((r (fol.seqop:rest s)))
                                 (if (cl:or (null r) (fol.seqop:empty? r))
                                     nil
                                     (cl:labels ((butlast-seq (current)
                                                   (fol.collection:make-lazy-seq
                                                    (lambda ()
                                                      (let ((next (fol.seqop:rest current)))
                                                        (if (cl:or (null next) (fol.seqop:empty? next))
                                                            nil
                                                            (cl:cons (fol.seqop:first current)
                                                                     (butlast-seq next))))))))
                                       (butlast-seq s)))))))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 3: Partitioning and Grouping
            ;; ============================================================
            'flatten #'(lambda (coll)
                         "Takes any nested combination of sequential things and returns their
                          contents as a single, flat lazy sequence."
                         (cl:labels ((sequentialp (x)
                                       ;; Check if x is a sequential collection (not a map/set)
                                       (cl:or (fol.collection:<list>? x)
                                              (fol.collection:<vector>? x)
                                              (fol.collection:<lazy-seq>? x)
                                              (cl:and (consp x) (cl:not (keywordp (cl:car x))))))
                                     (flat-seq (s rest-stack)
                                       ;; s is current sequence being flattened
                                       ;; rest-stack is a list of remaining sequences to process
                                       (fol.collection:make-lazy-seq
                                        (lambda ()
                                          (cl:labels ((continue-from (cur stack)
                                                        (if (cl:or (null cur)
                                                                   (cl:and (cl:not (consp cur))
                                                                           (fol.seqop:empty? cur)))
                                                            ;; Current exhausted, try stack
                                                            (if (null stack)
                                                                nil
                                                                (continue-from (cl:car stack) (cl:cdr stack)))
                                                            ;; Get next item
                                                            (let ((item (if (consp cur)
                                                                            (cl:car cur)
                                                                            (fol.seqop:first cur)))
                                                                  (rst (if (consp cur)
                                                                           (cl:cdr cur)
                                                                           (fol.seqop:rest cur))))
                                                              (if (sequentialp item)
                                                                  ;; Push rest onto stack, descend into item
                                                                  (continue-from (fol.seqop:seq item)
                                                                                 (cl:cons rst stack))
                                                                  ;; Emit item, continue with rest
                                                                  (cl:cons item (flat-seq rst stack)))))))
                                            (continue-from s rest-stack))))))
                           (flat-seq (fol.seqop:seq coll) nil)))
            'partition #'(lambda (n &rest args)
                           "Returns a lazy sequence of lists of n items each, at offsets step apart.
                            (partition n coll) - partitions with step = n
                            (partition n step coll) - partitions with specified step
                            (partition n step pad coll) - uses pad collection to fill final partition"
                           (let* ((step (if (cl:>= (cl:length args) 2) (cl:first args) n))
                                  (pad (if (cl:>= (cl:length args) 3) (cl:second args) nil))
                                  (coll (cond
                                          ((cl:= (cl:length args) 1) (cl:first args))
                                          ((cl:= (cl:length args) 2) (cl:second args))
                                          (t (cl:third args)))))
                             (cl:labels ((take-n (s count)
                                           ;; Take up to count items from s, return (items . remaining)
                                           (let ((items nil)
                                                 (current s))
                                             (dotimes (i count)
                                               (when (cl:and current (cl:not (fol.seqop:empty? current)))
                                                 (cl:push (fol.seqop:first current) items)
                                                 (setf current (fol.seqop:rest current))))
                                             (cl:cons (cl:nreverse items) current)))
                                         (drop-n (s count)
                                           (let ((current s))
                                             (dotimes (i count)
                                               (when (cl:and current (cl:not (fol.seqop:empty? current)))
                                                 (setf current (fol.seqop:rest current))))
                                             current))
                                         (partition-seq (s)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (if (cl:or (null s) (fol.seqop:empty? s))
                                                  nil
                                                  (let* ((take-result (take-n s n))
                                                         (items (car take-result)))
                                                    (if (cl:= (cl:length items) n)
                                                        ;; Full partition
                                                        (cl:cons (apply #'fol.collection:make-list items)
                                                                 (partition-seq (drop-n s step)))
                                                        ;; Partial partition
                                                        (if pad
                                                            ;; Pad the final partition
                                                            (let* ((pad-seq (fol.seqop:seq pad))
                                                                   (needed (cl:- n (cl:length items)))
                                                                   (pad-items nil))
                                                              (dotimes (i needed)
                                                                (when (cl:and pad-seq (cl:not (fol.seqop:empty? pad-seq)))
                                                                  (cl:push (fol.seqop:first pad-seq) pad-items)
                                                                  (setf pad-seq (fol.seqop:rest pad-seq))))
                                                              (if (cl:= (cl:+ (cl:length items) (cl:length pad-items)) n)
                                                                  (cl:cons (apply #'fol.collection:make-list
                                                                                  (cl:append items (cl:nreverse pad-items)))
                                                                           nil)
                                                                  nil))
                                                            ;; No padding, discard partial partition
                                                            nil))))))))
                               (partition-seq (fol.seqop:seq coll)))))
            'partition-all #'(lambda (n &rest args)
                               "Returns a lazy sequence of lists like partition, but may include
                                partitions with fewer than n items at the end.
                                (partition-all n) - returns a transducer
                                (partition-all n coll)
                                (partition-all n step coll)"
                               (cond
                                 ;; (partition-all n) - return a transducer
                                 ((cl:= (cl:length args) 0)
                                  (let ((current-partition nil))
                                    #'(lambda (rf)
                                        #'(lambda (&rest xf-args)
                                            (cl:case (cl:length xf-args)
                                              (0 (funcall rf))
                                              (1 ;; Completion: emit any remaining partition
                                               (let ((result (cl:first xf-args)))
                                                 (if current-partition
                                                     (let ((final (apply #'fol.collection:make-list
                                                                         (cl:nreverse current-partition))))
                                                       (setf current-partition nil)
                                                       (funcall rf (funcall rf result final)))
                                                     (funcall rf result))))
                                              (2 (let ((result (cl:first xf-args))
                                                       (input (cl:second xf-args)))
                                                   (cl:push input current-partition)
                                                   (if (cl:>= (cl:length current-partition) n)
                                                       (let ((partition (apply #'fol.collection:make-list
                                                                               (cl:nreverse current-partition))))
                                                         (setf current-partition nil)
                                                         (funcall rf result partition))
                                                       result))))))))
                                 ;; (partition-all n coll) or (partition-all n step coll)
                                 (t
                                  (let* ((step (if (cl:= (cl:length args) 2) (cl:first args) n))
                                         (coll (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args))))
                                    (cl:labels ((take-n (s count)
                                                  (let ((items nil)
                                                        (current s))
                                                    (dotimes (i count)
                                                      (when (cl:and current (cl:not (fol.seqop:empty? current)))
                                                        (cl:push (fol.seqop:first current) items)
                                                        (setf current (fol.seqop:rest current))))
                                                    (cl:nreverse items)))
                                                (drop-n (s count)
                                                  (let ((current s))
                                                    (dotimes (i count)
                                                      (when (cl:and current (cl:not (fol.seqop:empty? current)))
                                                        (setf current (fol.seqop:rest current))))
                                                    current))
                                                (partition-all-seq (s)
                                                  (fol.collection:make-lazy-seq
                                                   (lambda ()
                                                     (if (cl:or (null s) (fol.seqop:empty? s))
                                                         nil
                                                         (let ((items (take-n s n)))
                                                           (if items
                                                               (cl:cons (apply #'fol.collection:make-list items)
                                                                        (partition-all-seq (drop-n s step)))
                                                               nil)))))))
                                      (partition-all-seq (fol.seqop:seq coll)))))))
            'partition-by #'(lambda (f &rest args)
                              "Applies f to each value in coll, splitting it each time f returns a new value.
                               (partition-by f) - returns a transducer
                               (partition-by f coll) - returns a lazy-seq of lists"
                              (cond
                                ;; (partition-by f) - return a transducer
                                ((cl:= (cl:length args) 0)
                                 (let ((current-group nil)
                                       (current-key :fol-partition-by-none))
                                   #'(lambda (rf)
                                       #'(lambda (result input)
                                           (let ((key (apply-function f (cl:list input))))
                                             (if (equal key current-key)
                                                 (progn
                                                   (cl:push input current-group)
                                                   result)
                                                 (let ((prev-group (cl:nreverse current-group)))
                                                   (setf current-key key)
                                                   (setf current-group (cl:list input))
                                                   (if prev-group
                                                       (funcall rf result (apply #'fol.collection:make-list prev-group))
                                                       result))))))))
                                ;; (partition-by f coll) - return lazy-seq
                                ((cl:= (cl:length args) 1)
                                 (let ((coll (cl:first args)))
                                   (cl:labels ((partition-seq (s current-group current-key)
                                                 (fol.collection:make-lazy-seq
                                                  (lambda ()
                                                    (if (cl:or (null s) (fol.seqop:empty? s))
                                                        ;; Emit final group if any
                                                        (if current-group
                                                            (cl:cons (apply #'fol.collection:make-list (cl:nreverse current-group)) nil)
                                                            nil)
                                                        (let* ((item (fol.seqop:first s))
                                                               (key (apply-function f (cl:list item))))
                                                          (if (equal key current-key)
                                                              ;; Same group
                                                              (funcall (fol.collection::lazy-seq-thunk
                                                                        (partition-seq (fol.seqop:rest s)
                                                                                       (cl:cons item current-group)
                                                                                       current-key)))
                                                              ;; New group
                                                              (if current-group
                                                                  (cl:cons (apply #'fol.collection:make-list (cl:nreverse current-group))
                                                                           (partition-seq (fol.seqop:rest s)
                                                                                          (cl:list item)
                                                                                          key))
                                                                  (funcall (fol.collection::lazy-seq-thunk
                                                                            (partition-seq (fol.seqop:rest s)
                                                                                           (cl:list item)
                                                                                           key)))))))))))
                                     (let ((s (fol.seqop:seq coll)))
                                       (if (cl:or (null s) (fol.seqop:empty? s))
                                           nil
                                           (let* ((first-item (fol.seqop:first s))
                                                  (first-key (apply-function f (cl:list first-item))))
                                             (partition-seq (fol.seqop:rest s) (cl:list first-item) first-key)))))))
                                (t (error "partition-by requires 1 or 2 arguments"))))
            'split-at #'(lambda (n coll)
                          "Returns a vector of [(take n coll) (drop n coll)]."
                          (let ((s (fol.seqop:seq coll))
                                (taken nil)
                                (remaining nil))
                            ;; Take first n items
                            (let ((current s))
                              (dotimes (i n)
                                (when (cl:and current (cl:not (fol.seqop:empty? current)))
                                  (cl:push (fol.seqop:first current) taken)
                                  (setf current (fol.seqop:rest current))))
                              (setf remaining current))
                            (fol.collection:make-vector
                             (apply #'fol.collection:make-list (cl:nreverse taken))
                             (if (cl:or (null remaining) (fol.seqop:empty? remaining))
                                 (fol.collection:make-list)
                                 remaining))))
            'split-with #'(lambda (pred coll)
                            "Returns a vector of [(take-while pred coll) (drop-while pred coll)]."
                            (let ((s (fol.seqop:seq coll))
                                  (taken nil))
                              ;; Take while pred is true
                              (let ((current s))
                                (loop while (cl:and current (cl:not (fol.seqop:empty? current)))
                                      for item = (fol.seqop:first current)
                                      while (apply-function pred (cl:list item))
                                      do (cl:push item taken)
                                         (setf current (fol.seqop:rest current))
                                      finally (setf s current)))
                              (fol.collection:make-vector
                               (apply #'fol.collection:make-list (cl:nreverse taken))
                               (if (cl:or (null s) (fol.seqop:empty? s))
                                   (fol.collection:make-list)
                                   s))))
            'shuffle #'(lambda (coll)
                         "Return a random permutation of coll."
                         (let ((vec (coerce (loop for s = (fol.seqop:seq coll) then (fol.seqop:rest s)
                                                  until (cl:or (null s) (fol.seqop:empty? s))
                                                  collect (fol.seqop:first s))
                                            'cl:vector)))
                           ;; Fisher-Yates shuffle
                           (loop for i from (cl:1- (cl:length vec)) downto 1
                                 do (let ((j (cl:random (cl:1+ i))))
                                      (rotatef (aref vec i) (aref vec j))))
                           (apply #'fol.collection:make-vector (coerce vec 'cl:list))))
            'seq-replace #'(lambda (smap &rest args)
                             "Given a map of replacement pairs and a collection, returns a
                              sequence with any keys that are in smap replaced with the
                              corresponding values.
                              (seq-replace smap) - returns a transducer
                              (seq-replace smap coll) - returns a lazy-seq"
                             (cond
                               ;; (seq-replace smap) - return a transducer
                               ((cl:= (cl:length args) 0)
                                #'(lambda (rf)
                                    #'(lambda (result input)
                                        (let ((replacement (fol.seqop:get smap input :fol-not-found)))
                                          (funcall rf result
                                                   (if (eq replacement :fol-not-found)
                                                       input
                                                       replacement))))))
                               ;; (seq-replace smap coll) - return lazy-seq
                               ((cl:= (cl:length args) 1)
                                (let ((coll (cl:first args)))
                                  (cl:labels ((replace-seq (s)
                                                (fol.collection:make-lazy-seq
                                                 (lambda ()
                                                   (if (cl:or (null s) (fol.seqop:empty? s))
                                                       nil
                                                       (let* ((item (fol.seqop:first s))
                                                              (replacement (fol.seqop:get smap item :fol-not-found)))
                                                         (cl:cons (if (eq replacement :fol-not-found)
                                                                      item
                                                                      replacement)
                                                                  (replace-seq (fol.seqop:rest s)))))))))
                                    (replace-seq (fol.seqop:seq coll)))))
                               (t (error "seq-replace requires 1 or 2 arguments"))))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 4: Sorting
            ;; ============================================================
            'sort #'(lambda (&rest args)
                      "Returns a sorted sequence of the items in coll.
                       (sort coll) - sorts using natural ordering
                       (sort comp coll) - sorts using comparator function"
                      (let* ((comp (if (cl:= (cl:length args) 2) (cl:first args) nil))
                             (coll (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args)))
                             (items (loop for s = (fol.seqop:seq coll) then (fol.seqop:rest s)
                                          until (cl:or (null s) (fol.seqop:empty? s))
                                          collect (fol.seqop:first s))))
                        (if comp
                            (apply #'fol.collection:make-list
                                   (cl:sort items (lambda (a b)
                                                    (let ((result (apply-function comp (cl:list a b))))
                                                      (if (numberp result)
                                                          (cl:< result 0)
                                                          result)))))
                            (apply #'fol.collection:make-list
                                   (cl:sort items (lambda (a b)
                                                    (cl:< (fol.collection::generic-compare a b) 0)))))))
            'sort-by #'(lambda (keyfn &rest args)
                         "Returns a sorted sequence of the items in coll, where the sort order is
                          determined by comparing (keyfn item).
                          (sort-by keyfn coll) - sorts by keyfn
                          (sort-by keyfn comp coll) - sorts by keyfn using comparator"
                         (let* ((comp (if (cl:= (cl:length args) 2) (cl:first args) nil))
                                (coll (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args)))
                                (items (loop for s = (fol.seqop:seq coll) then (fol.seqop:rest s)
                                             until (cl:or (null s) (fol.seqop:empty? s))
                                             collect (fol.seqop:first s))))
                           (if comp
                               (apply #'fol.collection:make-list
                                      (cl:sort items
                                               (lambda (a b)
                                                 (let* ((ka (apply-function keyfn (cl:list a)))
                                                        (kb (apply-function keyfn (cl:list b)))
                                                        (result (apply-function comp (cl:list ka kb))))
                                                   (if (numberp result)
                                                       (cl:< result 0)
                                                       result)))))
                               (apply #'fol.collection:make-list
                                      (cl:sort items
                                               (lambda (a b)
                                                 (let ((ka (apply-function keyfn (cl:list a)))
                                                       (kb (apply-function keyfn (cl:list b))))
                                                   (cl:< (fol.collection::generic-compare ka kb) 0))))))))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 5: Accessors
            ;; ============================================================
            'last #'(lambda (coll)
                      "Return the last item in coll, in linear time."
                      (let ((s (fol.seqop:seq coll)))
                        (if (cl:or (null s) (fol.seqop:empty? s))
                            nil
                            (loop for current = s then (fol.seqop:rest current)
                                  until (cl:or (null (fol.seqop:rest current))
                                               (fol.seqop:empty? (fol.seqop:rest current)))
                                  finally (return (fol.seqop:first current))))))
            'ffirst #'(lambda (coll)
                        "Same as (first (first x))."
                        (fol.seqop:first (fol.seqop:first coll)))
            'nfirst #'(lambda (coll)
                        "Same as (next (first x))."
                        (let ((f (fol.seqop:first coll)))
                          (if f
                              (let ((s (fol.seqop:seq f)))
                                (if (cl:or (null s) (fol.seqop:empty? s))
                                    nil
                                    (let ((r (fol.seqop:rest s)))
                                      (if (cl:or (null r) (fol.seqop:empty? r))
                                          nil
                                          r))))
                              nil)))
            'nthnext #'(lambda (coll n)
                         "Returns the nth next of coll, (seq coll) when n is 0."
                         (let ((s (fol.seqop:seq coll)))
                           (dotimes (i n)
                             (when s
                               (setf s (fol.seqop:rest s))
                               (when (fol.seqop:empty? s)
                                 (setf s nil))))
                           s))
            'rand-nth #'(lambda (coll)
                          "Return a random element of the (sequential) collection."
                          (let ((items (loop for s = (fol.seqop:seq coll) then (fol.seqop:rest s)
                                             until (cl:or (null s) (fol.seqop:empty? s))
                                             collect (fol.seqop:first s))))
                            (if items
                                (cl:nth (cl:random (cl:length items)) items)
                                nil)))
            'max-key #'(lambda (k &rest more)
                         "Returns the x for which (k x) is greatest."
                         (if (null more)
                             nil
                             (let ((best (cl:first more))
                                   (best-val (apply-function k (cl:list (cl:first more)))))
                               (dolist (x (cl:rest more))
                                 (let ((val (apply-function k (cl:list x))))
                                   (when (cl:> (fol.collection::generic-compare val best-val) 0)
                                     (setf best x)
                                     (setf best-val val))))
                               best)))
            'min-key #'(lambda (k &rest more)
                         "Returns the x for which (k x) is least."
                         (if (null more)
                             nil
                             (let ((best (cl:first more))
                                   (best-val (apply-function k (cl:list (cl:first more)))))
                               (dolist (x (cl:rest more))
                                 (let ((val (apply-function k (cl:list x))))
                                   (when (cl:< (fol.collection::generic-compare val best-val) 0)
                                     (setf best x)
                                     (setf best-val val))))
                               best)))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 6: Building Collections
            ;; ============================================================
            'zipmap #'(lambda (keys vals)
                        "Returns a map with the keys mapped to the corresponding vals."
                        (let ((ks (fol.seqop:seq keys))
                              (vs (fol.seqop:seq vals))
                              (result (fol.collection:make-dict)))
                          (loop while (cl:and ks vs
                                              (cl:not (fol.seqop:empty? ks))
                                              (cl:not (fol.seqop:empty? vs)))
                                do (setf result (fol.seqop:add result
                                                               (fol.seqop:first ks)
                                                               (fol.seqop:first vs)))
                                   (setf ks (fol.seqop:rest ks))
                                   (setf vs (fol.seqop:rest vs)))
                          result))
            'reductions #'(lambda (f &rest args)
                            "Returns a lazy seq of the intermediate values of the reduction
                             (as per reduce) of coll by f, starting with init.
                             (reductions f coll) - uses first element as init
                             (reductions f init coll) - uses init as starting value"
                            (cond
                              ;; (reductions f coll)
                              ((cl:= (cl:length args) 1)
                               (let* ((coll (cl:first args))
                                      (s (fol.seqop:seq coll)))
                                 (if (cl:or (null s) (fol.seqop:empty? s))
                                     (fol.collection:make-lazy-seq
                                      (lambda () (cl:cons (apply-function f nil) nil)))
                                     (cl:labels ((red-seq (acc rest-s)
                                                   (fol.collection:make-lazy-seq
                                                    (lambda ()
                                                      (cl:cons acc
                                                               (if (cl:or (null rest-s) (fol.seqop:empty? rest-s))
                                                                   nil
                                                                   (red-seq (apply-function f (cl:list acc (fol.seqop:first rest-s)))
                                                                            (fol.seqop:rest rest-s))))))))
                                       (red-seq (fol.seqop:first s) (fol.seqop:rest s))))))
                              ;; (reductions f init coll)
                              ((cl:= (cl:length args) 2)
                               (let* ((init (cl:first args))
                                      (coll (cl:second args))
                                      (s (fol.seqop:seq coll)))
                                 (cl:labels ((red-seq (acc rest-s)
                                               (fol.collection:make-lazy-seq
                                                (lambda ()
                                                  (cl:cons acc
                                                           (if (cl:or (null rest-s) (fol.seqop:empty? rest-s))
                                                               nil
                                                               (red-seq (apply-function f (cl:list acc (fol.seqop:first rest-s)))
                                                                        (fol.seqop:rest rest-s))))))))
                                   (red-seq init s))))
                              (t (error "reductions requires 2 or 3 arguments"))))
            'into-array #'(lambda (&rest args)
                            "Returns an array with components set to the values in aseq.
                             (into-array aseq) - creates array from seq
                             (into-array type aseq) - creates array of specified type"
                            (let* ((type (if (cl:= (cl:length args) 2) (cl:first args) t))
                                   (aseq (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args)))
                                   (items (loop for s = (fol.seqop:seq aseq) then (fol.seqop:rest s)
                                                until (cl:or (null s) (fol.seqop:empty? s))
                                                collect (fol.seqop:first s))))
                              (cl:make-array (cl:length items)
                                             :element-type type
                                             :initial-contents items)))
            'apply #'(lambda (f &rest args)
                       "Applies fn f to the argument list formed by prepending intervening
                        arguments to args (the last argument which must be a seq)."
                       (if (null args)
                           (apply-function f nil)
                           (let* ((all-but-last (cl:butlast args))
                                  (last-arg (cl:car (cl:last args)))
                                  (last-items (loop for s = (fol.seqop:seq last-arg) then (fol.seqop:rest s)
                                                    until (cl:or (null s) (fol.seqop:empty? s))
                                                    collect (fol.seqop:first s))))
                             (apply-function f (cl:append all-but-last last-items)))))
            ;; ============================================================
            ;; Clojure Sequence Functions - Part 7: Forcing Lazy Seqs
            ;; ============================================================
            'dorun #'(lambda (&rest args)
                       "Realize the lazy seq without retaining the head. Returns nil.
                        (dorun coll) - realize entire seq
                        (dorun n coll) - realize first n items"
                       (let* ((n (if (cl:= (cl:length args) 2) (cl:first args) nil))
                              (coll (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args)))
                              (s (fol.seqop:seq coll)))
                         (if n
                             (loop for i from 0 below n
                                   while (cl:and s (cl:not (fol.seqop:empty? s)))
                                   do (setf s (fol.seqop:rest s)))
                             (loop while (cl:and s (cl:not (fol.seqop:empty? s)))
                                   do (setf s (fol.seqop:rest s))))
                         nil))
            'doall #'(lambda (&rest args)
                       "Realize the lazy seq. Walks through the successive nexts of the seq,
                        retaining the head and returning it.
                        (doall coll) - realize entire seq
                        (doall n coll) - realize first n items"
                       (let* ((n (if (cl:= (cl:length args) 2) (cl:first args) nil))
                              (coll (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args)))
                              (s (fol.seqop:seq coll)))
                         (let ((head s))
                           (if n
                               (loop for i from 0 below n
                                     while (cl:and s (cl:not (fol.seqop:empty? s)))
                                     do (setf s (fol.seqop:rest s)))
                               (loop while (cl:and s (cl:not (fol.seqop:empty? s)))
                                     do (setf s (fol.seqop:rest s))))
                           head)))
            'run! #'(lambda (proc coll)
                      "Runs the supplied procedure (via reduce), for purposes of side effects,
                       on successive items in the collection. Returns nil."
                      (let ((s (fol.seqop:seq coll)))
                        (loop while (cl:and s (cl:not (fol.seqop:empty? s)))
                              do (apply-function proc (cl:list (fol.seqop:first s)))
                                 (setf s (fol.seqop:rest s)))
                        nil))
            ;; ============================================================
            ;; Parallel Processing with Thread Pool and pmap
            ;; ============================================================
            'pmap #'(lambda (f &rest colls)
                      "Like map, except f is applied in parallel. Semi-lazy in that the
                       parallel computation stays ahead of the consumption, but doesn't
                       realize the entire result unless required."
                      (if (null colls)
                          (fol.collection:make-lazy-seq (lambda () nil))
                          (if (cl:= (cl:length colls) 1)
                              ;; Single collection case
                              (let ((coll (cl:first colls)))
                                (cl:labels ((pmap-seq (s)
                                              (fol.collection:make-lazy-seq
                                               (lambda ()
                                                 (if (cl:or (null s) (fol.seqop:empty? s))
                                                     nil
                                                     ;; Use lparallel for parallel mapping
                                                     (let* ((chunk-size 32)
                                                            (items nil)
                                                            (current s))
                                                       ;; Collect a chunk of items
                                                       (dotimes (i chunk-size)
                                                         (when (cl:and current (cl:not (fol.seqop:empty? current)))
                                                           (cl:push (fol.seqop:first current) items)
                                                           (setf current (fol.seqop:rest current))))
                                                       (setf items (cl:nreverse items))
                                                       ;; Process chunk in parallel using lparallel
                                                       (let ((results (if (cl:> (cl:length items) 1)
                                                                          (handler-case
                                                                              (lparallel:pmapcar
                                                                               (lambda (x) (apply-function f (cl:list x)))
                                                                               items)
                                                                            (error (e)
                                                                              (declare (ignore e))
                                                                              ;; Fallback to sequential if lparallel not initialized
                                                                              (cl:mapcar (lambda (x) (apply-function f (cl:list x))) items)))
                                                                          (cl:mapcar (lambda (x) (apply-function f (cl:list x))) items))))
                                                         ;; Build lazy result
                                                         (cl:labels ((emit-results (rs rest-s)
                                                                       (if (null rs)
                                                                           (funcall (fol.collection::lazy-seq-thunk (pmap-seq rest-s)))
                                                                           (cl:cons (cl:first rs)
                                                                                    (fol.collection:make-lazy-seq
                                                                                     (lambda () (emit-results (cl:rest rs) rest-s)))))))
                                                           (emit-results results current)))))))))
                                  (pmap-seq (fol.seqop:seq coll))))
                              ;; Multiple collections - zip them together
                              (let ((seqs (cl:mapcar #'fol.seqop:seq colls)))
                                (cl:labels ((pmap-multi-seq (ss)
                                              (fol.collection:make-lazy-seq
                                               (lambda ()
                                                 (if (cl:some (lambda (s) (cl:or (null s) (fol.seqop:empty? s))) ss)
                                                     nil
                                                     (let ((args (cl:mapcar #'fol.seqop:first ss))
                                                           (rests (cl:mapcar #'fol.seqop:rest ss)))
                                                       (cl:cons (apply-function f args)
                                                                (pmap-multi-seq rests))))))))
                                  (pmap-multi-seq seqs))))))
            ;; seque - creates a queued seq that processes in background (simplified version)
            'seque #'(lambda (&rest args)
                       "Creates a queued seq on another thread.
                        (seque coll) - uses default buffer of 100
                        (seque n coll) - uses buffer of n items"
                       (let* ((n (if (cl:= (cl:length args) 2) (cl:first args) 100))
                              (coll (if (cl:= (cl:length args) 2) (cl:second args) (cl:first args))))
                         (declare (ignore n))
                         ;; Simplified: just return a lazy seq (full impl would use a queue)
                         (let ((s (fol.seqop:seq coll)))
                           (cl:labels ((seque-seq (current)
                                         (fol.collection:make-lazy-seq
                                          (lambda ()
                                            (if (cl:or (null current) (fol.seqop:empty? current))
                                                nil
                                                (cl:cons (fol.seqop:first current)
                                                         (seque-seq (fol.seqop:rest current))))))))
                             (seque-seq s)))))
            ;; ============================================================
            ;; Clojure Utility Predicates
            ;; ============================================================
            'zero? #'fol.number:zero?
            'qualified-keyword? #'(lambda (x)
                                    "Returns true if x is a keyword with a namespace."
                                    (cl:and (keywordp x)
                                            ;; Keywords in CL are in the KEYWORD package, so we check
                                            ;; if the name contains a / (Clojure-style namespace separator)
                                            (cl:let ((name (cl:symbol-name x)))
                                              (cl:and (cl:> (cl:length name) 0)
                                                      (cl:find #\/ name)))))
            'qualified-symbol? #'(lambda (x)
                                   "Returns true if x is a symbol with a namespace."
                                   (cond
                                     ;; FOL <symbol> wrapper - check if module is set and different from default
                                     ((typep x 'fol.classes:<symbol>)
                                      (cl:let ((mod (fol.symbol:symbol-package-str x)))
                                        (cl:and mod
                                                (cl:not (string= mod fol.symbol:+default-module+)))))
                                     ;; Raw CL symbol (non-keyword)
                                     ((cl:and (cl:symbolp x) (cl:not (keywordp x)))
                                      ;; For raw CL symbols, check if it has a non-standard package
                                      (cl:and (cl:symbol-package x)
                                              (cl:not (eq (cl:symbol-package x)
                                                          (cl:find-package :cl-user)))))
                                     ;; Keywords or anything else
                                     (t nil)))
            'simple-keyword? #'(lambda (x)
                                 "Returns true if x is a keyword without a namespace."
                                 (cl:and (keywordp x)
                                         (cl:not (cl:find #\/ (cl:symbol-name x)))))
            'simple-symbol? #'(lambda (x)
                                "Returns true if x is a symbol without a namespace qualifier."
                                (cond
                                  ;; FOL <symbol> wrapper - simple if no module or default module
                                  ((typep x 'fol.classes:<symbol>)
                                   (cl:let ((mod (fol.symbol:symbol-package-str x)))
                                     (cl:or (null mod)
                                            (string= mod fol.symbol:+default-module+))))
                                  ;; Raw CL symbol (non-keyword) - always simple since read without qualifier
                                  ((cl:and (cl:symbolp x) (cl:not (keywordp x)))
                                   t)
                                  ;; Keywords or anything else
                                  (t nil)))
            'inst? #'(lambda (x)
                       "Returns true if x is an inst (timestamp/date).
                        In FOL, this is represented as an integer timestamp or local-time object."
                       ;; For now, just check if it's a number (Unix timestamp)
                       (cl:integerp x))
            'uuid? #'(lambda (x)
                       "Returns true if x is a UUID."
                       (typep x 'fol.classes:<uuid>))
            'associative? #'(lambda (x)
                              "Returns true if x implements the Associative interface (assoc, get by key)."
                              (cl:or (fol.collection:<dict>? x)
                                     (fol.collection:<vector>? x)
                                     (fol.collection:<array>? x)))
            'indexed? #'(lambda (x)
                          "Returns true if x implements the Indexed interface (nth, count)."
                          (cl:or (fol.collection:<vector>? x)
                                 (fol.collection:<deque>? x)
                                 (fol.collection:<array>? x)
                                 (cl:stringp x)
                                 (cl:vectorp x)))
            'seqable? #'(lambda (x)
                          "Returns true if (seq x) is possible."
                          (cl:or (null x)
                                 (cl:listp x)
                                 (fol.collection:<collection>? x)
                                 (cl:stringp x)
                                 (cl:vectorp x)))
            'any? #'(lambda (x)
                      "Returns true for any value. Useful as a predicate placeholder."
                      (declare (ignore x))
                      t)
            ;; ============================================================
            ;; Clojure Transducer Infrastructure
            ;; ============================================================
            'completing #'(lambda (f &optional cf)
                            "Takes a reducing function f of 2 args and returns a fn suitable for
                             transduce by adding an arity-1 signature that calls cf (default - identity)
                             on the result argument."
                            (let ((complete-fn (cl:or cf #'cl:identity)))
                              #'(lambda (&rest args)
                                  (cl:case (cl:length args)
                                    (1 (apply-function complete-fn (cl:list (cl:first args))))
                                    (2 (apply-function f (cl:list (cl:first args) (cl:second args))))
                                    (otherwise (error "completing: wrong number of arguments"))))))
            'ensure-reduced #'(lambda (x)
                                "If x is already reduced?, returns it, else returns (reduced x)."
                                (if (fol.collection:<reduced>? x)
                                    x
                                    (fol.collection:reduced x)))
            'transduce #'(lambda (xform f &rest args)
                           "reduce with a transformation of f (xf). If init is not supplied,
                            (f) will be called to produce it. f should be a reducing function
                            that accepts either an accumulator and an input, or just an accumulator
                            for completion. Returns the result of applying (the transformed) xf
                            to init and the first item in coll, then applying xf to that result
                            and the second item, etc."
                           (let* ((has-init (cl:= (cl:length args) 2))
                                  (init (if has-init (cl:first args) (apply-function f nil)))
                                  (coll (if has-init (cl:second args) (cl:first args)))
                                  ;; Wrap f with completing to ensure proper arity handling
                                  (cf #'(lambda (&rest cf-args)
                                          (cl:case (cl:length cf-args)
                                            (0 (apply-function f nil))
                                            (1 (cl:first cf-args))  ; completion just returns result
                                            (2 (apply-function f cf-args)))))
                                  (xf (funcall xform cf))
                                  (s (fol.seqop:seq coll))
                                  (acc init))
                             (loop while (cl:and s (cl:not (fol.seqop:empty? s))
                                                 (cl:not (fol.collection:<reduced>? acc)))
                                   do (setf acc (funcall xf acc (fol.seqop:first s)))
                                      (setf s (fol.seqop:rest s)))
                             ;; Call completion arity
                             (funcall xf (fol.collection:unreduced acc))))
            'eduction #'(lambda (xform &rest colls)
                          "Returns a reducible/iterable application of the transducers
                           to the items in colls. Transducers are applied in order as if
                           combined with comp. The transducer is applied lazily when the
                           eduction is consumed."
                          ;; Returns a lazy sequence that applies the transducer
                          (let ((coll (if (cl:= (cl:length colls) 1)
                                          (cl:first colls)
                                          (error "eduction: only single collection supported"))))
                            ;; For simplicity, eagerly apply the transducer and return a lazy seq
                            ;; This is similar to (sequence xform coll) but wrapped in a lazy-seq
                            (let* ((result nil)
                                   ;; Create reducing function that accumulates into result list
                                   (rf #'(lambda (&rest args)
                                           (cl:case (cl:length args)
                                             (0 nil)  ; init arity
                                             (1 (cl:first args))  ; completion arity
                                             (2 (cl:push (cl:second args) (cl:first args))
                                                (cl:first args)))))  ; reducing arity
                                   (xf (funcall xform rf))
                                   (s (fol.seqop:seq coll))
                                   (acc nil))
                              ;; Process all items through the transducer
                              (loop while (cl:and s (cl:not (fol.seqop:empty? s))
                                                  (cl:not (fol.collection:<reduced>? acc)))
                                    do (setf acc (funcall xf acc (fol.seqop:first s)))
                                       (setf s (fol.seqop:rest s)))
                              (setf result (fol.collection:unreduced acc))
                              ;; Call completion arity
                              (setf result (funcall xf result))
                              ;; Return as a lazy seq (even though we've processed it)
                              (apply #'fol.collection:make-list (cl:nreverse result)))))
            ;; ============================================================
            ;; Clojure Transducers
            ;; ============================================================
            ;; Note: Many of these functions (map, filter, etc.) already exist
            ;; but we update them to return transducers when called with arity 1
            ;; ============================================================
            'cat #'(lambda (rf)
                     "A transducer which concatenates the contents of each input, which must be a
                      collection, into the reduction."
                     #'(lambda (&rest args)
                         (cl:case (cl:length args)
                           (0 (funcall rf))  ; init
                           (1 (funcall rf (cl:first args)))  ; completion
                           (2 (fol.seqop:reduce rf (cl:first args) (cl:second args))))))
            'halt-when #'(lambda (pred &optional retf)
                           "Returns a transducer that ends transduction when pred returns true for an input.
                            When retf is supplied it must be a fn of 2 arguments - it will be passed
                            the (completed) result so far and the input that triggered the predicate."
                           (let ((ret-fn (cl:or retf (lambda (result input) (declare (ignore input)) result))))
                             #'(lambda (rf)
                                 #'(lambda (&rest args)
                                     (cl:case (cl:length args)
                                       (0 (funcall rf))
                                       (1 (funcall rf (cl:first args)))
                                       (2 (let ((result (cl:first args))
                                                (input (cl:second args)))
                                            (if (apply-function pred (cl:list input))
                                                (fol.collection:reduced
                                                 (funcall ret-fn (funcall rf result) input))
                                                (funcall rf result input)))))))))
            ;; Atom functions
            'atom #'fol.atom:atom
            'atom? #'fol.atom:<atom>?
            'deref #'fol.atom:deref
            'reset! #'fol.atom:reset!
            'swap! #'fol.atom:swap!
            ;; Number predicates
            'number? #'fol.number:<number>?
            'complex? #'fol.number:<complex>?
            'real? #'fol.number:<real>?
            'float? #'fol.number:<float>?
            'integer? #'fol.number:<integer>?
            'rational? #'fol.number:<rational>?
            'ratio? #'fol.number:<ratio>?
            ;; Intern function
            'intern #'(lambda (ns name)
                        "Finds or creates a var named by the symbol name in a namespace ns.
                         In FOL, this creates a symbol in the given module."
                        (fol.symbol:fol-intern (cl:if (cl:stringp name) name (cl:symbol-name name))
                                               (cl:if (cl:stringp ns) ns (cl:symbol-name ns))))
            ;; Standard macros
            'when (make-when-macro)
            'unless (make-unless-macro)
            'with-seed (make-with-seed-macro)
            ;; Threading macros
            'as-> (make-as->-macro)
            'cond-> (make-cond->-macro)
            'cond->> (make-cond->>-macro)
            'some-> (make-some->-macro)
            'some->> (make-some->>-macro)
            ;; Control flow macros
            'when-not (make-when-not-macro)
            'when-let (make-when-let-macro)
            'when-first (make-when-first-macro)
            'if-not (make-if-not-macro)
            'if-let (make-if-let-macro)
            'condp (make-condp-macro)
            'when-some (make-when-some-macro)
            'if-some (make-if-some-macro)
            ;; Loop macros
            'dotimes (make-dotimes-macro)
            'doseq (make-doseq-macro)
            'for (make-for-macro)
            ;; Lazy and misc macros
            'lazy-cat (make-lazy-cat-macro)
            'delay (make-delay-macro)
            'assert (make-assert-macro)
            'comment (make-comment-macro)
            ;; Internal functions
            '%time% (make-%time%-macro)
            '%time-thunk% #'fol-time-thunk
            '%test% #'fol.repl:fol-test)))
    ;; Export all symbols from the module
    (let ((items (fol.persistent:pslot-value module 'fol.collection::items)))
      (fset:do-map (key val items)
        (declare (ignore val))
        (fol.module:module-export module key)))
    module))

(defun make-zip-module ()
  "Create a module with FOL zipper functions for navigating and editing tree structures.
   All symbols are exported."
  (let* ((module (fol.module:make-module "fol.zip"
            ;; Zipper creation
            'zipper? #'fol.seqop:<zipper>?
            'zipper #'fol.seqop:zipper
            'seq-zip #'fol.seqop:seq-zip
            'vector-zip #'fol.seqop:vector-zip
            ;; Accessors
            'node #'fol.seqop:node
            'branch? #'fol.seqop:branch?
            'children #'fol.seqop:children
            'make-node #'fol.seqop:make-node
            'path #'fol.seqop:path
            'lefts #'fol.seqop:lefts
            'rights #'fol.seqop:rights
            ;; Navigation
            'up #'fol.seqop:up
            'down #'fol.seqop:down
            'left #'fol.seqop:left
            'right #'fol.seqop:right
            'leftmost #'fol.seqop:leftmost
            'rightmost #'fol.seqop:rightmost
            ;; Editing
            'replace #'fol.seqop:zip-replace
            'edit #'fol.seqop:edit
            'insert-child #'fol.seqop:insert-child
            'append-child #'fol.seqop:append-child
            'insert-left #'fol.seqop:insert-left
            'insert-right #'fol.seqop:insert-right
            'zip-remove #'fol.seqop:zip-remove
            ;; Traversal
            'zip-next #'fol.seqop:zip-next
            'prev #'fol.seqop:prev
            'root #'fol.seqop:root
            'end? #'fol.seqop:end?))
         (items (fol.persistent:pslot-value module 'fol.collection::items))
         (updated-module module))
    ;; Export all symbols from the module
    (fset:do-map (key val items)
      (declare (ignore val))
      (setf updated-module (fol.module:module-export updated-module key)))
    ;; Re-register the updated module
    (fol.module:register-module "fol.zip" updated-module)
    updated-module))

(defun make-walk-module ()
  "Create a module with FOL walk functions for tree traversal and transformation.
   All symbols are exported."
  (let* ((module (fol.module:make-module "fol.walk"
            ;; Walk functions
            'walk #'fol.walk:walk
            'prewalk #'fol.walk:prewalk
            'prewalk-demo #'fol.walk:prewalk-demo
            'prewalk-replace #'fol.walk:prewalk-replace
            'postwalk #'fol.walk:postwalk
            'postwalk-demo #'fol.walk:postwalk-demo
            'postwalk-replace #'fol.walk:postwalk-replace))
         (items (fol.persistent:pslot-value module 'fol.collection::items))
         (updated-module module))
    ;; Export all symbols from the module
    (fset:do-map (key val items)
      (declare (ignore val))
      (setf updated-module (fol.module:module-export updated-module key)))
    ;; Re-register the updated module
    (fol.module:register-module "fol.walk" updated-module)
    updated-module))

;;; ============================================================================
;;; Initialize Standard Modules
;;; ============================================================================

;; Create and register the standard walk and zip modules when this file is loaded
;; Note: make-module automatically registers modules in the global registry
(make-zip-module)
(make-walk-module)
