(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; Collection Base Tests
;;; ============================================================================

(test collection-inheritance
  "Test that <collection> inherits from <persistent-object>"
  (let ((c (make-instance '<collection>)))
    ;; Check class hierarchy
    (is (typep c '<collection>))
    (is (typep c '<persistent-object>))
    
    ;; Check predicate
    (is (unwrap (<collection>? c)))
    
    ;; Check metaclass wiring
    (is (eq (class-name (class-of (class-of c))) 'persistent-class))))

(test collection-immutability
  "Test that collections behave as persistent objects"
  (let ((c (make-instance '<collection>)))
    (is (cl:not (null c)))))

;;; ============================================================================
;;; Unordered Collection Tests
;;; ============================================================================

(test unordered-collection-inheritance
  "Test that <unordered-collection> inherits correctly"
  (let ((u (make-instance '<unordered-collection>)))
    ;; Check class hierarchy
    (is (typep u '<unordered-collection>))
    (is (typep u '<collection>))
    
    ;; Check predicates
    (is (unwrap (<unordered-collection>? u)))
    (is (unwrap (<collection>? u)))
    
    ;; Check disjointness (it is NOT an ordered collection)
    (is (unwrap (not (<ordered-collection>? u))))))

;;; ============================================================================
;;; Ordered Collection Tests
;;; ============================================================================

(test ordered-collection-inheritance
  "Test that <ordered-collection> inherits correctly"
  (let ((s (make-instance '<ordered-collection>)))
    ;; Check class hierarchy
    (is (typep s '<ordered-collection>))
    (is (typep s '<collection>))
    
    ;; Check predicates
    (is (unwrap (<ordered-collection>? s)))
    (is (unwrap (<collection>? s)))
    
    ;; Check disjointness (it is NOT an unordered collection)
    (is (unwrap (not (<unordered-collection>? s))))
    (is (unwrap (not (<dict>? s))))))

;;; ============================================================================
;;; Dictionary Tests
;;; ============================================================================

(test dict-creation
  "Test creation of <dict> objects"
  (let ((d (make-dict :x 10 :y 20)))
    (is (typep d '<dict>))
    
    ;; Verify inheritance chain
    (is (unwrap (<dict>? d)))
    (is (unwrap (<unordered-collection>? d))) ; Inherits from Unordered
    (is (unwrap (<collection>? d)))           ; Inherits from Collection
    (is (unwrap (<persistent-object>? d)))    ; Inherits from Persistent Object
    
    ;; Verify it is NOT an ordered collection
    (is (unwrap (not (<ordered-collection>? d))))
    
    ;; Verify we can retrieve the internal items map via pslot-value
    (let ((items (fol.persistent:pslot-value d 'fol.collection::items)))
      (is (= 10 (fset:lookup items :x)))
      (is (= 20 (fset:lookup items :y))))))

(test dict-printing
  "Test that dicts print in the format {key val key val}"
  (let ((d1 (make-dict 'a 1)))
    (is (equal "{'A 1}" (format nil "~A" d1))))
  
  (let* ((d2 (make-dict 'x 10 'y 20))
         (str (format nil "~A" d2)))
    (is (char= #\{ (char str 0)))
    (is (char= #\} (char str (1- (length str)))))
    (is (search "'X 10" str))
    (is (search "'Y 20" str))))

(test dict-reader-syntax
  "Test the { key val } reader syntax directly in code"
  ;; QUOTE the symbols inside the braces: 'a and 'b
  (let ((d { 'a 100 'b 200 }))
    (is (typep d '<dict>))
    (is (unwrap (<dict>? d)))
    (let ((items (fol.persistent:pslot-value d 'fol.collection::items)))
      (is (= 100 (fset:lookup items 'a)))
      (is (= 200 (fset:lookup items 'b))))))

(test dict-round-trip
  "Test printing to string and reading back via READ-FROM-STRING"
  ;; Use symbols p and q
  (let* ((d1 (make-dict 'p 50 'q 60))
         (str (format nil "~A" d1)))
    
    (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
      ;; Because print-object now adds quotes ('P), EVAL works!
      (let ((d2 (eval (read-from-string str))))
        
        (is (typep d2 '<dict>))
        (let ((items (fol.persistent:pslot-value d2 'fol.collection::items)))
          (is (= 50 (fset:lookup items 'p)))
          (is (= 60 (fset:lookup items 'q))))))))

(test type-operations
  "Test various key types"
  (let ((d (make-dict 'sym 1 
                      :key 2 
                      "str" 3 
                      #\c 4 
                      (wrap 42) 5)))
    (let ((items (fol.persistent:pslot-value d 'fol.collection::items)))
      (is (= 1 (fset:lookup items 'sym)))
      (is (= 2 (fset:lookup items :key)))
      (is (= 3 (fset:lookup items "str")))
      (is (= 4 (fset:lookup items #\c)))
      ;; For FOL objects, lookup depends on FSet equality
      (is (= 5 (fset:lookup items (wrap 42)))))))

;;; ============================================================================
;;; Bag Tests
;;; ============================================================================

(test bag-creation
  "Test creation of <bag> objects"
  ;; Create a bag with duplicates: :a appears twice
  (let ((b (make-bag :a :b :a)))
    (is (typep b '<bag>))
    
    ;; Verify inheritance
    (is (unwrap (<bag>? b)))
    (is (unwrap (<dict>? b)))       ; It IS a Dict
    (is (unwrap (<unordered-collection>? b)))
    (is (unwrap (<collection>? b)))
    
    ;; Verify it is NOT an ordered collection
    (is (cl:not (unwrap (<ordered-collection>? b))))
    
    ;; Verify internal counts
    (let ((items (fol.persistent:pslot-value b 'fol.collection::items)))
      (is (= 2 (fset:lookup items :a)))
      (is (= 1 (fset:lookup items :b)))
      (is (null (fset:lookup items :c))))))

(test bag-reader-syntax
  "Test the #M{ ... } reader syntax"
  (let ((b #M{ 'x 'y 'x 'z }))
    (is (typep b '<bag>))
    (let ((items (fol.persistent:pslot-value b 'fol.collection::items)))
      (is (= 2 (fset:lookup items 'x)))
      (is (= 1 (fset:lookup items 'y)))
      (is (= 1 (fset:lookup items 'z))))))

;;; ============================================================================
;;; Set Tests
;;; ============================================================================

(test set-creation
  "Test creation of <set> objects"
  (let ((s (make-set :a :b :a)))
    (is (typep s '<set>))
    (is (unwrap (<set>? s)))
    (let ((items (fol.persistent:pslot-value s 'fol.collection::items)))
      (is (= 2 (fset:size items))))))

(test set-printing
  "Test that sets print as #{ elem ... }"
  (let* ((s (make-set 'x 'y))
         (str (format nil "~A" s)))
    (is (search "#{" str))
    (is (search "}" str))
    (is (search "'X" str))
    (is (search "'Y" str))))

(test set-reader-syntax
  "Test the #{ ... } reader syntax"
  (let ((s #{ 'm 'n 'm })) 
    (is (typep s '<set>))
    (let ((items (fol.persistent:pslot-value s 'fol.collection::items)))
      (is (= 2 (fset:size items)))
      (multiple-value-bind (val found) (fset:lookup items 'm)
        (is (eq val t))
        (is (cl:not (null found)))))))

(test set-round-trip
  "Test Set round-trip printing/reading"
  (let* ((s1 #{ #t #f 123 "foo" 'bar })
         (str (format nil "~A" s1)))
    (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
      (let ((s2 (eval (read-from-string str))))
        (is (typep s2 '<set>))
        (let ((items (fol.persistent:pslot-value s2 'fol.collection::items)))
          (multiple-value-bind (val found) (fset:lookup items fol.singleton:*true-instance*)
            (is (eq val t))
            (is (cl:not (null found))))
          (multiple-value-bind (val found) (fset:lookup items 123)
            (is (eq val t))
            (is (cl:not (null found)))))))))

;;; ============================================================================
;;; Vector Tests
;;; ============================================================================

(test vector-creation
  "Test creation of <vector> objects"
  (let ((v (make-vector 1 2 3)))
    (is (typep v '<vector>))
    (is (unwrap (<vector>? v)))
    (is (unwrap (<ordered-collection>? v)))
    (is (cl:not (unwrap (<dict>? v))))
    (let ((items (fol.persistent:pslot-value v 'fol.collection::items)))
      (is (= 3 (fset:size items)))
      (is (= 1 (fset:first items)))
      (is (= 3 (fset:last items))))))

(test vector-printing
  "Test that vectors print as [ ... ]"
  (let ((v (make-vector 'a 'b)))
    (let ((str (format nil "~A" v)))
      (is (search "[" str))
      (is (search "]" str))
      (is (search "'A" str))
      (is (search "'B" str)))))

(test vector-reader-syntax
  "Test the [ ... ] reader syntax"
  (let ((v [ 'x 'y 'z ]))
    (is (typep v '<vector>))
    (let ((items (fol.persistent:pslot-value v 'fol.collection::items)))
      (is (= 3 (fset:size items)))
      (is (eq 'x (fset:first items)))
      (is (eq 'z (fset:last items))))))

;;; ============================================================================
;;; Array Tests
;;; ============================================================================

(test array-creation
  "Test creation of <array>"
  ;; Create a 2x2 array: Dimensions [2 2], Data: A B C D
  (let ((arr (make-array [ 2 2 ] 'A 'B 'C 'D)))
    (is (typep arr '<array>))
    (is (unwrap (<array>? arr)))
    (is (unwrap (<vector>? arr))) ; Inherits from Vector
    
    ;; Check dimensions slot
    (let ((d (fol.persistent:pslot-value arr 'fol.collection::dimensions)))
      (is (unwrap (<vector>? d)))
      (let ((d-items (fol.persistent:pslot-value d 'fol.collection::items)))
        (is (= 2 (fset:first d-items)))))))

(test array-get-column-major
  "Test access using Column Major Order"
  ;; 2x2 Array. Dims: [2 2]. Elements: A B C D
  ;; Column Major Indexing:
  ;; [0 0] -> 0 + 2*0 = 0 -> A
  ;; [1 0] -> 1 + 2*0 = 1 -> B
  ;; [0 1] -> 0 + 2*1 = 2 -> C
  ;; [1 1] -> 1 + 2*1 = 3 -> D
  
  (let ((arr (make-array [ 2 2 ] 'A 'B 'C 'D)))
    (is (eq 'A (get arr [ 0 0 ])))
    (is (eq 'B (get arr [ 1 0 ])))
    (is (eq 'C (get arr [ 0 1 ])))
    (is (eq 'D (get arr [ 1 1 ])))))

(test array-get-bounds-defaults
  "Test out of bounds and default values"
  (let ((arr (make-array [ 2 2 ] 'A 'B 'C 'D)))
    ;; Out of bounds (Index >= Dimension)
    (is (null (get arr [ 2 0 ])))        ; Default default is NIL
    (is (eq :oops (get arr [ 2 0 ] :oops))) ; Explicit default
    
    ;; Rank mismatch (Too many indices)
    (is (eq :bad-rank (get arr [ 0 0 0 ] :bad-rank)))))

(test array-sparse-access
  "Test access when underlying seq is missing data"
  ;; Array declared 2x2, but only provided 2 elements
  (let ((arr (make-array [ 2 2 ] 'A 'B)))
    (is (eq 'A (get arr [ 0 0 ]))) ; Index 0
    (is (eq 'B (get arr [ 1 0 ]))) ; Index 1
    (is (eq :empty (get arr [ 0 1 ] :empty))) ; Index 2 (Missing)
    (is (eq :empty (get arr [ 1 1 ] :empty))))) ; Index 3 (Missing)

(test generic-ops
  "Test size, empty?, contains?, add, remove"
  ;; 1. DICTIONARY
  (let ((d { :k 1 })) ; Corrected: No space after colon
    (is (= 1 (size d)))
    (is (unwrap (not (empty? d))))
    (is (unwrap (contains? d :k)))
    (is (unwrap (not (contains? d :z))))
    
    ;; Add (Functional update)
    (let ((d2 (add d :z 99)))
      (is (= 2 (size d2)))
      (is (unwrap (contains? d2 :z))))
    
    ;; Remove (Functional update)
    (let ((d3 (remove d :k)))
      (is (= 0 (size d3)))
      (is (unwrap (empty? d3)))))

  ;; 2. BAG
  (let ((b #M{ :a :a })) ; Corrected: No space after colon
    (is (= 1 (size b))) ; size returns number of unique keys (1 key ':a')
    (let ((b2 (add b :a))) ; Add third :a
       (let ((items (fol.persistent:pslot-value b2 'fol.collection::items)))
         (is (= 3 (fset:lookup items :a)))))
    
    (let ((b3 (remove b :a))) ; Remove one :a -> count becomes 1
       (let ((items (fol.persistent:pslot-value b3 'fol.collection::items)))
         (is (= 1 (fset:lookup items :a))))))

  ;; 3. SET
  (let ((s #{ :x })) ; Corrected: No space after colon
    (is (unwrap (contains? s :x)))
    (let ((s2 (add s :x))) ; Idempotent add
      (is (= 1 (size s2))))
    (let ((s3 (remove s :x)))
      (is (unwrap (empty? s3)))))

  ;; 4. VECTOR
  (let ((v [ :a :b ])) ; Corrected: No space after colon
    (is (= 2 (size v)))
    (is (unwrap (contains? v :b)))
    
    ;; Add (Append to end)
    (let ((v2 (add v :c)))
      (is (= 3 (size v2)))
      (is (eq :c (fset:last (fol.persistent:pslot-value v2 'fol.collection::items)))))
    
    ;; Remove (Value-based removal)
    (let ((v3 (remove v :a)))
      (is (= 1 (size v3)))
      (is (eq :b (fset:first (fol.persistent:pslot-value v3 'fol.collection::items)))))))

(test collection-iterator-protocol
  "Test manual iteration using iterator, next, current, and done?"
  (let* ((v [ 10 20 ])
         (iter (iterator v)))
    ;; Check initial state
    (is (unwrap (not (done? iter))))
    (is (= 10 (current iter)))
    
    ;; Advance
    (next iter)
    (is (= 20 (current iter)))
    (is (unwrap (not (done? iter))))
    
    ;; Finish
    (next iter)
    (is (unwrap (done? iter)))))