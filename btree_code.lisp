(defun btree-get (node key cmp &optional not-found)
  "O(log32 N) search. Returns (VALUES val found-p)."
  (cond
   ((null node) (values not-found nil))
   ((btree-leaf-p node)
     (let* ((keys (btree-leaf-keys node))
            (idx (bsearch-keys keys key cmp)))
       (if (and (< idx (length keys))
                (zerop (funcall cmp key (svref keys idx))))
           (values (svref (btree-leaf-vals node) idx) t)
           (values not-found nil))))
   ((btree-node-p node)
     (let* ((keys (btree-node-keys node))
            (idx (bsearch-keys keys key cmp)))
       (btree-get (svref (btree-node-children node) idx) key cmp not-found)))))

(defun split-leaf (keys vals)
  (let* ((mid 16)
         (len (length keys)))
    (values (%make-btree-leaf (subseq keys 0 mid) (subseq vals 0 mid))
      (svref keys mid) ; The key that routes the right half
      (%make-btree-leaf (subseq keys mid len) (subseq vals mid len)))))

(defun split-node (keys children)
  (let* ((mid 16)
         (split-key (svref keys mid))) ; The routing key moves UP
    (values (%make-btree-node (subseq keys 0 mid) (subseq children 0 (1+ mid)))
      split-key
      (%make-btree-node (subseq keys (1+ mid)) (subseq children (1+ mid))))))

(defun btree-assoc-node (node key val cmp)
  "Returns (VALUES new-node split-key split-right old-val found-p)."
  (if (null node)
      (values (%make-btree-leaf (vector key) (vector val)) nil nil nil nil)

      (if (btree-leaf-p node)
          (let* ((keys (btree-leaf-keys node))
                 (vals (btree-leaf-vals node))
                 (idx (bsearch-keys keys key cmp)))
            (if (and (< idx (length keys)) (zerop (funcall cmp key (svref keys idx))))
                (values (%make-btree-leaf keys (update-at vals idx val)) nil nil (svref vals idx) t)
                (let ((new-keys (insert-at keys idx key))
                      (new-vals (insert-at vals idx val)))
                  (if (<= (length new-keys) +b-tree-order+)
                      (values (%make-btree-leaf new-keys new-vals) nil nil nil nil)
                      (multiple-value-bind (left sk right) (split-leaf new-keys new-vals)
                        (values left sk right nil nil))))))

          ;; Internal routing node
          (let* ((keys (btree-node-keys node))
                 (children (btree-node-children node))
                 (idx (bsearch-keys keys key cmp)))
            (multiple-value-bind (new-child split-key split-right old-val found-p)
                (btree-assoc-node (svref children idx) key val cmp)
              (if found-p
                  (values (%make-btree-node keys (update-at children idx new-child)) nil nil old-val t)
                  (if split-key
                      (let ((new-keys (insert-at keys idx split-key))
                            (new-children (let ((arr (make-array (1+ (length children)))))
                                            (replace arr children :end1 idx :end2 idx)
                                            (setf (svref arr idx) new-child)
                                            (setf (svref arr (1+ idx)) split-right)
                                            (replace arr children :start1 (+ 2 idx) :start2 (1+ idx))
                                            arr)))
                        (if (<= (length new-children) +b-tree-order+)
                            (values (%make-btree-node new-keys new-children) nil nil nil nil)
                            (multiple-value-bind (left sk right) (split-node new-keys new-children)
                              (values left sk right nil nil))))
                      (values (%make-btree-node keys (update-at children idx new-child)) nil nil nil nil))))))))

(defun btree-dissoc-node (node key cmp)
  "Returns (VALUES new-node old-val found-p). Implements relaxed removal for massive speed."
  (cond
   ((null node) (values nil nil nil))
   ((btree-leaf-p node)
     (let* ((keys (btree-leaf-keys node))
            (idx (bsearch-keys keys key cmp)))
       (if (and (< idx (length keys)) (zerop (funcall cmp key (svref keys idx))))
           (let ((new-keys (remove-at keys idx))
                 (new-vals (remove-at (btree-leaf-vals node) idx)))
             (if (zerop (length new-keys))
                 (values nil (svref (btree-leaf-vals node) idx) t)
                 (values (%make-btree-leaf new-keys new-vals) (svref (btree-leaf-vals node) idx) t)))
           (values node nil nil))))
   ((btree-node-p node)
     (let* ((keys (btree-node-keys node))
            (children (btree-node-children node))
            (idx (bsearch-keys keys key cmp)))
       (multiple-value-bind (new-child old-val found-p)
           (btree-dissoc-node (svref children idx) key cmp)
         (if (not found-p)
             (values node nil nil)
             (if (null new-child)
                 (let ((new-keys (if (zerop idx) (remove-at keys 0) (remove-at keys (1- idx))))
                       (new-children (remove-at children idx)))
                   (if (zerop (length new-children))
                       (values nil old-val t)
                       (values (%make-btree-node new-keys new-children) old-val t)))
                 (values (%make-btree-node keys (update-at children idx new-child)) old-val t))))))))

;;; --------------------------------------------------------------------
;;; Bulk load O(N).
;;; --------------------------------------------------------------------

(defun first-key (node)
  (if (btree-leaf-p node)
      (svref (btree-leaf-keys node) 0)
      (first-key (svref (btree-node-children node) 0))))

