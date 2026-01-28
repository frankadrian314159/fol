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
  (make-macro
   '(seed)                    ; params: seed value
   '((syntax-quote            ; body: expand to (call-with-seed seed (fn [] body...))
      (call-with-seed (unquote seed)
                      (fn [] (unquote-splicing body)))))
   nil                        ; env
   :rest-param 'body          ; rest param captures all body forms
   :name 'with-seed))

;;; ============================================================================
;;; Standard Environment
;;; ============================================================================

(defun make-standard-env ()
  "Create an environment with standard FOL bindings for arithmetic,
   comparison, and logical operations."
  (make-env nil
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
            '<list>? #'fol.collection:<list>?
            '<dict>? #'fol.collection:<dict>?
            '<set>? #'fol.collection:<set>?
            '<bag>? #'fol.collection:<bag>?
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
                                  (tail-seq (fol.collection:seq last-arg)))
                             ;; Build list from the tail backwards
                             (let ((result (if (null tail-seq)
                                               (fol.collection:make-list)
                                               ;; Convert tail-seq to a <list>
                                               (cl:labels ((seq-to-list (s)
                                                             (if (cl:or (null s) (fol.collection:empty? s))
                                                                 (fol.collection:make-list)
                                                                 (fol.collection:conj
                                                                  (seq-to-list (fol.collection:rest s))
                                                                  (fol.collection:first s)))))
                                                 (seq-to-list tail-seq)))))
                               ;; Prepend the other args in reverse order
                               (dolist (item (cl:reverse all-but-last))
                                 (setf result (fol.collection:conj result item)))
                               result))))
            ;; cons prepends to FOL collections (Clojure-style)
            ;; Use cl-cons for macro form construction (building CL cons cells)
            'cons #'(lambda (x coll)
                      "Returns a new seq where x is the first element and coll is the rest."
                      (if (null coll)
                          (fol.collection:make-list x)
                          (fol.collection:conj (fol.collection:seq coll) x)))
            'cl-cons #'cl:cons
            'peek #'fol.collection:peek
            'pop #'fol.collection:pop
            'push #'fol.collection:push
            ;; CL sequence operations (for compatibility)
            'append #'cl:append
            ;; String operations
            'str #'(lambda (&rest args)
                     (apply #'concatenate 'string
                            (mapcar #'princ-to-string args)))
            'sub #'fol.collection:sub
            'blank? #'fol.string:blank?
            'trim #'fol.string:trim
            'triml #'fol.string:triml
            'trimr #'fol.string:trimr
            'trim-newline #'fol.string:trim-newline
            'capitalize #'fol.string:capitalize
            'starts-with? #'fol.string:starts-with?
            'ends-with? #'fol.string:ends-with?
            'includes? #'fol.string:includes?
            'replace #'fol.string:replace
            'replace-first #'fol.string:replace-first
            'join #'fol.string:join
            'escape #'fol.string:escape
            'split #'fol.string:split
            'split-lines #'fol.string:split-lines
            'reverse #'fol.collection:reverse
            'index-of #'fol.collection:index-of
            'last-index-of #'fol.collection:last-index-of
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
                      "Returns a function that applies each fn to its args and returns the results as multiple values.
                       (juxt f g h) returns a function that, when called with args, returns (values (f args) (g args) (h args))."
                      (lambda (&rest args)
                        (values-list
                         (loop for fn in fns
                               collect (apply-function fn args)))))
            'print #'cl:print
            'type #'fol.wrappers:fol-type-of
            ;; Generic constructor
            'make #'make
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
            'conj #'fol.collection:conj
            'first #'fol.collection:first
            'rest #'fol.collection:rest
            'second #'fol.collection:second
            'third #'fol.collection:third
            'nth #'fol.collection:nth
            'size #'fol.collection:size
            'empty? #'fol.collection:empty?
            'get #'fol.collection:get
            'contains? #'fol.collection:contains?
            'seq #'fol.collection:seq
            'add #'fol.collection:add
            'remove #'fol.collection:remove
            'disj #'fol.collection:disj
            'sized? #'fol.collection:sized?
            'bounded-size #'fol.collection:bounded-size
            'into #'fol.collection:into
            'vector #'fol.collection:vector
            'vec #'fol.collection:vec
            'mapv #'fol.collection:mapv
            'filterv #'fol.collection:filterv
            'assoc #'fol.collection:assoc
            'assoc-in #'fol.collection:assoc-in
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
                                  (s (fol.collection:seq coll)))
                             (if (or (null s) (fol.collection:empty? s))
                                 (apply-function f nil)  ; call f with no args for empty coll
                                 (let ((acc (fol.collection:first s))
                                       (s (fol.collection:rest s)))
                                   (loop until (or (null s) (fol.collection:empty? s)
                                                   (fol.collection:<reduced>? acc))
                                         do (setf acc (apply-function f (cl:list acc (fol.collection:first s))))
                                            (setf s (fol.collection:rest s)))
                                   (fol.collection:unreduced acc)))))
                          ;; (reduce f init coll) - with initial value, f is binary (acc, elem) -> acc
                          ((= (cl:length args) 2)
                           (let* ((init (cl:first args))
                                  (coll (cl:second args))
                                  (s (fol.collection:seq coll))
                                  (acc init))
                             (loop until (or (null s) (fol.collection:empty? s)
                                             (fol.collection:<reduced>? acc))
                                   do (setf acc (apply-function f (cl:list acc (fol.collection:first s))))
                                      (setf s (fol.collection:rest s)))
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
                            #'(lambda (result input)
                                (funcall rf result (apply-function f (cl:list input))))))
                       ;; (map f coll) - return lazy-seq
                       ((= (cl:length args) 1)
                        (let ((coll (cl:first args)))
                          (cl:labels ((map-seq (s)
                                        (fol.collection:make-lazy-seq
                                         (lambda ()
                                           (if (or (null s) (fol.collection:empty? s))
                                               nil
                                               (cl:cons (apply-function f (cl:list (fol.collection:first s)))
                                                        (map-seq (fol.collection:rest s))))))))
                            (map-seq (fol.collection:seq coll)))))
                       (t (error "map requires 1 or 2 arguments"))))
            'filter #'(lambda (pred &rest args)
                        "Return elements from coll for which pred returns truthy.
                         (filter pred) - returns a transducer
                         (filter pred coll) - returns a lazy-seq of elements where (pred elem) is truthy"
                        (cond
                          ;; (filter pred) - return a transducer
                          ((= (cl:length args) 0)
                           #'(lambda (rf)
                               #'(lambda (result input)
                                   (if (apply-function pred (cl:list input))
                                       (funcall rf result input)
                                       result))))
                          ;; (filter pred coll) - return lazy-seq
                          ((= (cl:length args) 1)
                           (let ((coll (cl:first args)))
                             (cl:labels ((filter-seq (s)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (cl:labels ((find-next (current)
                                                            (cond
                                                              ((or (null current) (fol.collection:empty? current))
                                                               nil)
                                                              ((apply-function pred (cl:list (fol.collection:first current)))
                                                               (cl:cons (fol.collection:first current)
                                                                        (filter-seq (fol.collection:rest current))))
                                                              (t (find-next (fol.collection:rest current))))))
                                                (find-next s))))))
                               (filter-seq (fol.collection:seq coll)))))
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
                                                              ((or (null current) (fol.collection:empty? current))
                                                               nil)
                                                              ((not (apply-function pred (cl:list (fol.collection:first current))))
                                                               (cl:cons (fol.collection:first current)
                                                                        (remove-seq (fol.collection:rest current))))
                                                              (t (find-next (fol.collection:rest current))))))
                                                (find-next s))))))
                               (remove-seq (fol.collection:seq coll)))))
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
                                                            ((or (null current) (fol.collection:empty? current))
                                                             nil)
                                                            (t (let ((v (apply-function f (cl:list (fol.collection:first current)))))
                                                                 (if v
                                                                     (cl:cons v (keep-seq (fol.collection:rest current)))
                                                                     (find-next (fol.collection:rest current))))))))
                                              (find-next s))))))
                             (keep-seq (fol.collection:seq coll)))))
                        (t (error "keep requires 1 or 2 arguments"))))
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
                                          (s (fol.collection:seq coll))
                                          (acc result))
                                     (loop until (or (null s) (fol.collection:empty? s))
                                           do (setf acc (funcall rf acc (fol.collection:first s)))
                                              (setf s (fol.collection:rest s)))
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
                                                                       (cl:not (fol.collection:empty? inner-s)))
                                                               (cl:cons (fol.collection:first inner-s)
                                                                        (concat-seqs outer-s (fol.collection:rest inner-s))))
                                                              ;; Otherwise, get next from outer
                                                              ((cl:or (null outer-s) (fol.collection:empty? outer-s))
                                                               nil)
                                                              (t
                                                               (let* ((elem (fol.collection:first outer-s))
                                                                      (new-inner (fol.collection:seq
                                                                                  (apply-function f (cl:list elem)))))
                                                                 (funcall (fol.collection::lazy-seq-thunk
                                                                           (concat-seqs (fol.collection:rest outer-s) new-inner))))))))
                                                (next-elem))))))
                               (concat-seqs (fol.collection:seq coll) nil))))
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
                                                 (if (cl:some (lambda (s) (or (null s) (fol.collection:empty? s))) seqs)
                                                     nil
                                                     ;; Take first from each, then recurse with rests
                                                     (let ((firsts (cl:mapcar #'fol.collection:first seqs))
                                                           (rests (cl:mapcar #'fol.collection:rest seqs)))
                                                       (cl:labels ((build-result (items rest-seqs)
                                                                     (if (null items)
                                                                         (funcall (fol.collection::lazy-seq-thunk
                                                                                   (interleave-seqs rest-seqs)))
                                                                         (cl:cons (cl:first items)
                                                                                  (fol.collection:make-lazy-seq
                                                                                   (lambda ()
                                                                                     (build-result (cl:rest items) rest-seqs)))))))
                                                         (build-result firsts rests))))))))
                                  (interleave-seqs (cl:mapcar #'fol.collection:seq colls)))))
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
                                                   ((or (null s) (fol.collection:empty? s))
                                                    nil)
                                                   (first-elem
                                                    ;; First element: just return it
                                                    (cl:cons (fol.collection:first s)
                                                             (interpose-seq (fol.collection:rest s) nil)))
                                                   (t
                                                    ;; Not first: emit sep, then element
                                                    (cl:cons sep
                                                             (fol.collection:make-lazy-seq
                                                              (lambda ()
                                                                (cl:cons (fol.collection:first s)
                                                                         (interpose-seq (fol.collection:rest s) nil)))))))))))
                                  (interpose-seq (fol.collection:seq coll) t))))
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
                       (let ((s (fol.collection:seq coll)))
                         (if (or (null s) (fol.collection:empty? s))
                             (fol.collection:make-lazy-seq (lambda () nil))
                             (cl:labels ((cycle-seq (current)
                                           (fol.collection:make-lazy-seq
                                            (lambda ()
                                              (if (or (null current) (fol.collection:empty? current))
                                                  ;; Restart from beginning
                                                  (funcall (fol.collection::lazy-seq-thunk (cycle-seq s)))
                                                  (cl:cons (fol.collection:first current)
                                                           (cycle-seq (fol.collection:rest current))))))))
                               (cycle-seq s)))))
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
                                                       (fol.collection:empty? s))
                                                nil
                                                (cl:cons (fol.collection:first s)
                                                         (take-seq (cl:1- remaining)
                                                                   (fol.collection:rest s))))))))
                             (take-seq n (fol.collection:seq coll)))))
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
                                                    (fol.collection:empty? s))
                                             s
                                             (drop-items (cl:1- remaining) (fol.collection:rest s)))))
                             (let ((remaining-seq (drop-items n (fol.collection:seq coll))))
                               ;; Wrap remaining sequence in a lazy-seq for consistency
                               (cl:labels ((lazy-rest (s)
                                             (fol.collection:make-lazy-seq
                                              (lambda ()
                                                (if (cl:or (null s) (fol.collection:empty? s))
                                                    nil
                                                    (cl:cons (fol.collection:first s)
                                                             (lazy-rest (fol.collection:rest s))))))))
                                 (lazy-rest remaining-seq))))))
                        (t (error "drop requires 1 or 2 arguments"))))
            ;; Standard macros
            'when (make-when-macro)
            'unless (make-unless-macro)
            'with-seed (make-with-seed-macro)))
