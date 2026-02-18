;;; FOL Compiler - Zipper Tests

(in-package :fol.compiler.tests.lib)

(in-suite zip-tests)

;;; Basic Navigation

(test vector-zip-basic-nav
      (let* ((z (fol.compiler.zip:vector-zip #(1 2 3)))
             (n (fol.compiler.zip:node z)))
        (is (equalp #(1 2 3) n))
        (is (fol.compiler.zip:branch? z))

        (let ((z1 (fol.compiler.zip:down z)))
          (is (not (null z1)))
          (is (eql 1 (fol.compiler.zip:node z1)))
          (is (null (fol.compiler.zip:left z1)))

          (let ((z2 (fol.compiler.zip:right z1)))
            (is (not (null z2)))
            (is (eql 2 (fol.compiler.zip:node z2)))
            (is (eql 1 (fol.compiler.zip:node (fol.compiler.zip:left z2))))

            (let ((z3 (fol.compiler.zip:right z2)))
              (is (not (null z3)))
              (is (eql 3 (fol.compiler.zip:node z3)))
              (is (null (fol.compiler.zip:right z3)))
              (is (eql 2 (fol.compiler.zip:node (fol.compiler.zip:left z3))))

              (let ((root (fol.compiler.zip:up z3)))
                (is (not (null root)))
                (is (equalp #(1 2 3) (fol.compiler.zip:node root)))
                (is (null (fol.compiler.zip:up root)))))))))

(test seq-zip-basic-nav
      (let* ((z (fol.compiler.zip:seq-zip '(1 (2 3) 4))))
        (is (equal '(1 (2 3) 4) (fol.compiler.zip:node z)))

        (let ((z1 (fol.compiler.zip:down z))) ; 1
          (is (eql 1 (fol.compiler.zip:node z1)))

          (let ((z2 (fol.compiler.zip:right z1))) ; (2 3)
            (is (equal '(2 3) (fol.compiler.zip:node z2)))

            (let ((z2-child (fol.compiler.zip:down z2))) ; 2
              (is (eql 2 (fol.compiler.zip:node z2-child)))
              (is (eql 3 (fol.compiler.zip:node (fol.compiler.zip:right z2-child))))

              (let ((z2-up (fol.compiler.zip:up z2-child))) ; (2 3)
                (is (equal '(2 3) (fol.compiler.zip:node z2-up)))

                (let ((z3 (fol.compiler.zip:right z2-up))) ; 4
                  (is (eql 4 (fol.compiler.zip:node z3)))
                  (is (null (fol.compiler.zip:right z3))))))))))

;;; Modification

(test replace-node
      (let* ((z (fol.compiler.zip:vector-zip #(1 2 3)))
             (z1 (fol.compiler.zip:down z))
             (z2 (fol.compiler.zip:replace z1 10))
             (root (fol.compiler.zip:root z2)))
        (is (equalp #(10 2 3) root))))

(test edit-node
      (let* ((z (fol.compiler.zip:vector-zip #(1 2 3)))
             (z1 (fol.compiler.zip:down z))
             (z2 (fol.compiler.zip:edit z1 #'1+))
             (root (fol.compiler.zip:root z2)))
        (is (equalp #(2 2 3) root))))

(test insert-siblings-and-children
      (let* ((z (fol.compiler.zip:vector-zip #(1)))
             (z-down (fol.compiler.zip:down z))
             (z1 (fol.compiler.zip:insert-right z-down 2))
             (z2 (fol.compiler.zip:insert-left z1 0))
             (root (fol.compiler.zip:root z2)))
        (is (equalp #(0 1 2) root)))

      (let* ((z (fol.compiler.zip:seq-zip '(1)))
             (z1 (fol.compiler.zip:insert-child z 0))
             (z2 (fol.compiler.zip:append-child z1 2))
             (root (fol.compiler.zip:root z2)))
        (is (equal '(0 1 2) root))))

(test remove-node
      ;; Remove middle
      (let* ((z (fol.compiler.zip:vector-zip #(1 2 3)))
             (z-2 (fol.compiler.zip:right (fol.compiler.zip:down z)))
             (z-removed (fol.compiler.zip:remove z-2))
             (root (fol.compiler.zip:root z-removed)))
        (is (equalp #(1 3) root))
        ;; remove returns predecessor
        (is (eql 1 (fol.compiler.zip:node z-removed))))

      ;; Remove first
      (let* ((z (fol.compiler.zip:vector-zip #(1 2 3)))
             (z-1 (fol.compiler.zip:down z))
             (z-removed (fol.compiler.zip:remove z-1))
             (root (fol.compiler.zip:root z-removed)))
        (is (equalp #(2 3) root))
        ;; remove returns parent (vector)
        (is (equalp #(2 3) (fol.compiler.zip:node z-removed)))))

(test remove-nested
      (let* ((z (fol.compiler.zip:seq-zip '(1 (2 3) 4)))
             ;; Go to 3
             (z-3 (fol.compiler.zip:right (fol.compiler.zip:down (fol.compiler.zip:right (fol.compiler.zip:down z)))))
             (z-removed (fol.compiler.zip:remove z-3))
             (root (fol.compiler.zip:root z-removed)))
        (is (equal '(1 (2) 4) root))
        ;; Predecessor of 3 is 2
        (is (eql 2 (fol.compiler.zip:node z-removed)))))

;;; Traversal (next/prev)

(test next-traversal
      (let ((z (fol.compiler.zip:vector-zip #(#(1) 2 #(3 #(4))))))
        (let ((nodes (loop for loc = z then (fol.compiler.zip:next loc)
                           while (not (fol.compiler.zip:end? loc))
                           collect (fol.compiler.zip:node loc))))
          ;; Pre-order: root, #(1), 1, 2, #(3 #(4)), 3, #(4), 4
          (is (equal 8 (length nodes)))
          (is (equalp #(#(1) 2 #(3 #(4))) (nth 0 nodes)))
          (is (equalp #(1) (nth 1 nodes)))
          (is (eql 1 (nth 2 nodes)))
          (is (eql 2 (nth 3 nodes)))
          (is (equalp #(3 #(4)) (nth 4 nodes)))
          (is (eql 3 (nth 5 nodes)))
          (is (equalp #(4) (nth 6 nodes)))
          (is (eql 4 (nth 7 nodes))))))

(test prev-traversal
      ;; Go to end (4), traverse back
      (let* ((z (fol.compiler.zip:vector-zip #(#(1) 2)))
             ;; Manual nav to 2
             (z-2 (fol.compiler.zip:right (fol.compiler.zip:down z)))) ; down -> #(1). right -> 2.
        (is (eql 2 (fol.compiler.zip:node z-2)))

        (let ((p1 (fol.compiler.zip:prev z-2))) ; should be 1 inside #(1)
          (is (eql 1 (fol.compiler.zip:node p1)))

          (let ((p2 (fol.compiler.zip:prev p1))) ; should be #(1)
            (is (equalp #(1) (fol.compiler.zip:node p2)))

            (let ((p3 (fol.compiler.zip:prev p2))) ; should be root
              (is (equalp #(#(1) 2) (fol.compiler.zip:node p3)))
              (is (null (fol.compiler.zip:prev p3))))))))
