;;; FOL Compiler - Collection Constructor Functions
;;;
;;; Runtime functions for constructing FOL collections.
;;; These are called directly by compiled FOL code:
;;;   (vector 1 2 3)     => <vector> of 1, 2, 3
;;;   (dict :a 1 :b 2)   => <dict> with :a->1, :b->2
;;;   (set 1 2 3)         => <set> of 1, 2, 3

(in-package :fol.compiler.functions)

(defun vector (&rest args)
  "Create a new <vector> from ARGS.
   (vector)       => empty vector
   (vector 1 2 3) => vector of 1, 2, 3"
  (apply #'make '<vector> args))

(defun dict (&rest args)
  "Create a new <dict> from alternating key-value ARGS.
   (dict)            => empty dict
   (dict :a 1 :b 2)  => dict with :a->1, :b->2"
  (apply #'make '<dict> args))

(defun ordered-dict (&rest args)
  "Create a new <ordered-dict> from alternating key-value ARGS.
   Preserves insertion order of keys.
   (ordered-dict)            => empty ordered dict
   (ordered-dict :a 1 :b 2)  => ordered dict with :a->1, :b->2"
  (apply #'make '<ordered-dict> args))

(defun array-dict (&rest args)
  "Create a new <array-dict> from alternating key-value ARGS.
   Preserves insertion order of keys.  Optimized for small, dense mappings.
   (array-dict)            => empty array dict
   (array-dict :a 1 :b 2)  => array dict with :a->1, :b->2"
  (apply #'make '<array-dict> args))

(defun set (&rest args)
  "Create a new <set> from ARGS.
   (set)       => empty set
   (set 1 2 3) => set of 1, 2, 3"
  (apply #'make '<set> args))

(defun ordered-set (&rest args)
  "Create a new <ordered-set> from ARGS.
   Duplicates are silently dropped; insertion order is preserved.
   (ordered-set)       => empty ordered set
   (ordered-set 1 2 3) => ordered set of 1, 2, 3"
  (apply #'make '<ordered-set> args))

(defun sorted-set (&rest args)
  "Create a new <sorted-set>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are elements.
   (sorted-set #'my-cmp 5 3 1) => sorted set of 1, 3, 5
   (sorted-set nil 5 3 1)      => sorted set with default numeric order"
  (apply #'make '<sorted-set> args))

(defun sorted-set-by (fn &rest items)
  "Create a new <sorted-set> with comparator FN and ITEMS.
   Equivalent to (sorted-set fn item1 item2 ...).
   (sorted-set-by #'my-cmp 5 3 1) => sorted set of 1, 3, 5
   (sorted-set-by nil 5 3 1)      => sorted set with default numeric order"
  (apply #'make '<sorted-set> fn items))

(defun int-set (&rest args)
  "Create a new <int-set> from integer ARGS.
   (int-set)       => empty int set
   (int-set 5 3 1) => int set of 1, 3, 5"
  (apply #'make '<int-set> args))

(defun sorted-dict (&rest args)
  "Create a new <sorted-dict>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are alternating key-value pairs.
   (sorted-dict #'my-cmp :b 2 :a 1) => sorted dict with :a->1, :b->2
   (sorted-dict nil 2 :b 1 :a)      => sorted dict with default numeric order"
  (apply #'make '<sorted-dict> args))

(defun sorted-dict-by (fn &rest pairs)
  "Create a new <sorted-dict> with comparator FN and alternating key-value PAIRS.
   Equivalent to (sorted-dict fn key1 val1 key2 val2 ...).
   (sorted-dict-by #'my-cmp :b 2 :a 1) => sorted dict with :a->1, :b->2"
  (apply #'make '<sorted-dict> fn pairs))

(defun int-dict (&rest args)
  "Create a new <int-dict> from alternating integer-key value ARGS.
   Keys are maintained in numeric order via a hardcoded fixnum comparator.
   (int-dict)          => empty int dict
   (int-dict 1 :a 2 :b) => int dict with 1->:a, 2->:b"
  (apply #'make '<int-dict> args))

(defun int-dict-by (fn &rest pairs)
  "Create a new <int-dict> with comparator FN and alternating key-value PAIRS.
   FN must accept two integers and return a negative fixnum, zero, or positive
   fixnum.  NIL uses the default ascending fixnum comparator.
   (int-dict-by #'my-cmp 2 :b 1 :a) => int dict with custom integer ordering"
  (apply #'make '<int-dict> fn pairs))

(defun priority-dict (&rest args)
  "Create a new <priority-dict> from alternating key-priority ARGS.
   Entries are ordered by priority ascending (min-first).
   (priority-dict)            => empty priority dict
   (priority-dict :a 1 :b 3)  => priority dict with :a→1, :b→3"
  (apply #'make '<priority-dict> args))

(defun dense-int-set (&rest args)
  "Create a new <dense-int-set> from integer ARGS.
   (dense-int-set)       => empty dense int set
   (dense-int-set 5 3 1) => dense int set of 1, 3, 5"
  (apply #'make '<dense-int-set> args))

(defun bag (&rest args)
  "Create a new <bag> from ARGS.
   Duplicate elements increase the count.
   (bag)       => empty bag
   (bag 1 1 2) => bag with two 1s and one 2"
  (apply #'make '<bag> args))

(defun deque (&rest args)
  "Create a new <deque> from ARGS.
   (deque)       => empty deque
   (deque 1 2 3) => deque with 1 at front, 3 at back"
  (apply #'make '<deque> args))

(defun list (&rest args)
  "Create a new <list> from ARGS.
   (list)       => empty list
   (list 1 2 3) => list of 1, 2, 3"
  (apply #'make '<list> args))

(defun lazy-seq (thunk)
  "Create a new <lazy-seq> from THUNK (a zero-argument function).
   (lazy-seq (lambda () (make '<list> 1 2 3))) => lazy sequence"
  (make '<lazy-seq> thunk))
