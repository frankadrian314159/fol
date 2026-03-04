(in-package :fol.tests)

(def-suite zip-suite :in fol-suite)
(def-suite* :fol.zip-tests :in zip-suite)

;;; ============================================================================
;;; Zipper Creation Tests
;;; ============================================================================

(test vector-zip-creation
  "Test creating a zipper from a vector."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root)))
    (is-true (fol.seqop:<zipper>? z))
    (is (equal (fol.seqop:node z) root))))

(test seq-zip-creation
  "Test creating a zipper from a list."
  (let* ((root (make-list 1 (make-list 2 3) 4))
         (z (fol.seqop:seq-zip root)))
    (is-true (fol.seqop:<zipper>? z))
    (is (equal (fol.seqop:node z) root))))

(test zipper-custom-creation
  "Test creating a custom zipper."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:zipper
             (lambda (node) (fol.collection:<vector>? node))
             (lambda (node) (fol.seqop:seq node))
             (lambda (node children)
               (declare (ignore node))
               (apply #'make-vector
                      (if (listp children) children
                          (let ((items nil)
                                (s (fol.seqop:seq children)))
                            (loop while (and s (not (fol.seqop:empty? s)))
                                  do (cl:push (fol.seqop:first s) items)
                                     (setf s (fol.seqop:rest s)))
                            (nreverse items)))))
             root)))
    (is-true (fol.seqop:<zipper>? z))
    (is (equal (fol.seqop:node z) root))))

;;; ============================================================================
;;; Navigation Tests
;;; ============================================================================

(test zip-down-navigation
  "Test moving down into children."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z)))
    (is-true z-down)
    (is (= 1 (fol.seqop:node z-down)))))

(test zip-down-on-leaf
  "Test that down returns nil on a leaf node."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-down-again (fol.seqop:down z-down)))
    (is (null z-down-again))))

(test zip-up-navigation
  "Test moving up to parent."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-up (fol.seqop:up z-down)))
    (is-true z-up)
    (is (equal (fol.seqop:node z-up) root))))

(test zip-up-at-root
  "Test that up returns nil at the root."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root)))
    (is (null (fol.seqop:up z)))))

(test zip-right-navigation
  "Test moving to right sibling."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down)))
    (is-true z-right)
    (is-true (fol.collection:<vector>? (fol.seqop:node z-right)))))

(test zip-left-navigation
  "Test moving to left sibling."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down))
         (z-left (fol.seqop:left z-right)))
    (is-true z-left)
    (is (= 1 (fol.seqop:node z-left)))))

(test zip-leftmost-navigation
  "Test moving to leftmost sibling."
  (let* ((root (make-vector 1 2 3 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down))
         (z-right2 (fol.seqop:right z-right))
         (z-leftmost (fol.seqop:leftmost z-right2)))
    (is (= 1 (fol.seqop:node z-leftmost)))))

(test zip-rightmost-navigation
  "Test moving to rightmost sibling."
  (let* ((root (make-vector 1 2 3 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-rightmost (fol.seqop:rightmost z-down)))
    (is (= 4 (fol.seqop:node z-rightmost)))))

;;; ============================================================================
;;; Traversal Tests
;;; ============================================================================

(test zip-next-traversal
  "Test depth-first traversal with next."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (nodes nil))
    ;; Collect all nodes in order
    (loop for loc = z then (fol.seqop:zip-next loc)
          until (fol.seqop:end? loc)
          do (cl:push (fol.seqop:node loc) nodes))
    ;; Should have visited: root, 1, [2 3], 2, 3, 4
    (is (= 6 (length nodes)))))

(test zip-end-detection
  "Test that end? detects end of traversal."
  (let* ((root (make-vector 1))
         (z (fol.seqop:vector-zip root)))
    (is-false (fol.seqop:end? z))
    (let ((z-next (fol.seqop:zip-next z)))
      (is-false (fol.seqop:end? z-next))
      (let ((z-next2 (fol.seqop:zip-next z-next)))
        (is-true (fol.seqop:end? z-next2))))))

;;; ============================================================================
;;; Editing Tests
;;; ============================================================================

(test zip-replace-node
  "Test replacing a node."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-replaced (fol.seqop:zip-replace z-down 99))
         (new-root (fol.seqop:root z-replaced)))
    (is (= 99 (fol.seqop:get new-root 0)))
    (is (= 2 (fol.seqop:get new-root 1)))
    (is (= 3 (fol.seqop:get new-root 2)))))

(test zip-edit-node
  "Test editing a node with a function."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-edited (fol.seqop:edit z-down #'1+))
         (new-root (fol.seqop:root z-edited)))
    (is (= 2 (fol.seqop:get new-root 0)))
    (is (= 2 (fol.seqop:get new-root 1)))
    (is (= 3 (fol.seqop:get new-root 2)))))

(test zip-insert-left-sibling
  "Test inserting a left sibling."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down))
         (z-inserted (fol.seqop:insert-left z-right :a))
         (new-root (fol.seqop:root z-inserted)))
    (is (= 1 (fol.seqop:get new-root 0)))
    (is (eq :a (fol.seqop:get new-root 1)))
    (is (= 2 (fol.seqop:get new-root 2)))
    (is (= 3 (fol.seqop:get new-root 3)))))

(test zip-insert-right-sibling
  "Test inserting a right sibling."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-inserted (fol.seqop:insert-right z-down :a))
         (new-root (fol.seqop:root z-inserted)))
    (is (= 1 (fol.seqop:get new-root 0)))
    (is (eq :a (fol.seqop:get new-root 1)))
    (is (= 2 (fol.seqop:get new-root 2)))
    (is (= 3 (fol.seqop:get new-root 3)))))

(test zip-insert-child
  "Test inserting a child at the beginning."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down))
         (z-inserted (fol.seqop:insert-child z-right :first))
         (new-root (fol.seqop:root z-inserted)))
    (let ((inner (fol.seqop:get new-root 1)))
      (is (eq :first (fol.seqop:get inner 0)))
      (is (= 2 (fol.seqop:get inner 1)))
      (is (= 3 (fol.seqop:get inner 2))))))

(test zip-append-child
  "Test appending a child at the end."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down))
         (z-appended (fol.seqop:append-child z-right :last))
         (new-root (fol.seqop:root z-appended)))
    (let ((inner (fol.seqop:get new-root 1)))
      (is (= 2 (fol.seqop:get inner 0)))
      (is (= 3 (fol.seqop:get inner 1)))
      (is (eq :last (fol.seqop:get inner 2))))))

(test zip-remove-node
  "Test removing a node."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down))
         (z-removed (fol.seqop:zip-remove z-right))
         (new-root (fol.seqop:root z-removed)))
    (is (= 2 (fol.seqop:size new-root)))
    (is (= 1 (fol.seqop:get new-root 0)))
    (is (= 3 (fol.seqop:get new-root 1)))))

;;; ============================================================================
;;; Accessor Tests
;;; ============================================================================

(test zip-branch-predicate
  "Test branch? predicate."
  (let* ((root (make-vector 1 (make-vector 2 3) 4))
         (z (fol.seqop:vector-zip root)))
    (is-true (fol.seqop:branch? z))
    (let ((z-down (fol.seqop:down z)))
      (is-false (fol.seqop:branch? z-down)))))

(test zip-children-accessor
  "Test children accessor."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (children (fol.seqop:children z)))
    (is-true children)
    (is (= 1 (fol.seqop:first children)))))

(test zip-lefts-accessor
  "Test lefts accessor."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z))
         (z-right (fol.seqop:right z-down)))
    (is (null (fol.seqop:lefts z-down)))
    (is-true (fol.seqop:lefts z-right))
    (is (= 1 (car (fol.seqop:lefts z-right))))))

(test zip-rights-accessor
  "Test rights accessor."
  (let* ((root (make-vector 1 2 3))
         (z (fol.seqop:vector-zip root))
         (z-down (fol.seqop:down z)))
    (is-true (fol.seqop:rights z-down))
    (is (= 2 (car (fol.seqop:rights z-down))))))

;;; ============================================================================
;;; Complex Scenario Tests
;;; ============================================================================

(test zip-nested-edit
  "Test editing a deeply nested node."
  (let* ((root (make-vector 1 (make-vector 2 (make-vector 3 4)) 5))
         (z (fol.seqop:vector-zip root))
         (z1 (fol.seqop:down z))        ; at 1
         (z2 (fol.seqop:right z1))      ; at [2 [3 4]]
         (z3 (fol.seqop:down z2))       ; at 2
         (z4 (fol.seqop:right z3))      ; at [3 4]
         (z5 (fol.seqop:down z4))       ; at 3
         (z-edited (fol.seqop:zip-replace z5 999))
         (new-root (fol.seqop:root z-edited)))
    ;; Check the structure is preserved
    (is (= 1 (fol.seqop:get new-root 0)))
    (is (= 5 (fol.seqop:get new-root 2)))
    ;; Check nested edit
    (let* ((inner1 (fol.seqop:get new-root 1))
           (inner2 (fol.seqop:get inner1 1)))
      (is (= 999 (fol.seqop:get inner2 0)))
      (is (= 4 (fol.seqop:get inner2 1))))))

(test zip-seq-tree
  "Test zipper with seq-based tree."
  (let* ((root (make-list 1 (make-list 2 3) 4))
         (z (fol.seqop:seq-zip root))
         (z-down (fol.seqop:down z)))
    (is (= 1 (fol.seqop:node z-down)))
    (let* ((z-right (fol.seqop:right z-down))
           (z-down2 (fol.seqop:down z-right)))
      (is (= 2 (fol.seqop:node z-down2))))))
