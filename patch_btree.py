import re

with open('btree_code.lisp') as f:
    text = f.read()

prefix = '''
;;; --------------------------------- Transients -------------------------------

(defstruct (btree-transient-leaf (:constructor %make-btree-transient-leaf (token count keys vals)))
  (token nil)
  (count 0 :type fixnum)
  (keys #() :type simple-vector)
  (vals #() :type simple-vector))

(defstruct (btree-transient-node (:constructor %make-btree-transient-node (token count keys children)))
  (token nil)
  (count 0 :type fixnum)
  (keys #() :type simple-vector)
  (children #() :type simple-vector))

(defun ensure-editable-btree-leaf (node token)
  (if (and (btree-transient-leaf-p node) (eq token (btree-transient-leaf-token node)))
      node
      (let* ((is-p (btree-leaf-p node))
             (keys (if is-p (btree-leaf-keys node) (btree-transient-leaf-keys node)))
             (vals (if is-p (btree-leaf-vals node) (btree-transient-leaf-vals node)))
             (count (if is-p (length keys) (btree-transient-leaf-count node)))
             (new-keys (make-array 32 :initial-element nil))
             (new-vals (make-array 32 :initial-element nil)))
        (replace new-keys keys :end2 count)
        (replace new-vals vals :end2 count)
        (%make-btree-transient-leaf token count new-keys new-vals))))

(defun ensure-editable-btree-node (node token)
  (if (and (btree-transient-node-p node) (eq token (btree-transient-node-token node)))
      node
      (let* ((is-p (btree-node-p node))
             (keys (if is-p (btree-node-keys node) (btree-transient-node-keys node)))
             (children (if is-p (btree-node-children node) (btree-transient-node-children node)))
             (count (if is-p (length children) (btree-transient-node-count node)))
             (new-keys (make-array 32 :initial-element nil))
             (new-children (make-array 32 :initial-element nil)))
        (replace new-keys keys :end2 (max 0 (1- count)))
        (replace new-children children :end2 count)
        (%make-btree-transient-node token count new-keys new-children))))

(defun freeze-btree-node (node)
  (cond
   ((btree-transient-leaf-p node)
    (let* ((count (btree-transient-leaf-count node))
           (new-keys (make-array count))
           (new-vals (make-array count)))
      (replace new-keys (btree-transient-leaf-keys node) :end2 count)
      (replace new-vals (btree-transient-leaf-vals node) :end2 count)
      (%make-btree-leaf new-keys new-vals)))
   ((btree-transient-node-p node)
    (let* ((count (btree-transient-node-count node))
           (keys (make-array (max 0 (1- count))))
           (children (make-array count)))
      (replace keys (btree-transient-node-keys node) :end2 (max 0 (1- count)))
      (loop for i from 0 below count
            do (setf (svref children i) (freeze-btree-node (svref (btree-transient-node-children node) i))))
      (%make-btree-node keys children)))
   ((btree-node-p node)
    (let* ((children (btree-node-children node))
           (new-children (make-array (length children))))
      (loop for i from 0 below (length children)
            do (setf (svref new-children i) (freeze-btree-node (svref children i))))
      (%make-btree-node (btree-node-keys node) new-children)))
   (t node)))

(defun btree-get-transient-aware (node key cmp &optional not-found)
  (cond
   ((null node) (values not-found nil))
   ((btree-leaf-p node)
    (let* ((keys (btree-leaf-keys node))
           (idx (bsearch-keys keys key cmp)))
      (if (and (< idx (length keys)) (zerop (funcall cmp key (svref keys idx))))
          (values (svref (btree-leaf-vals node) idx) t)
          (values not-found nil))))
   ((btree-transient-leaf-p node)
    (let* ((keys (btree-transient-leaf-keys node))
           (count (btree-transient-leaf-count node))
           (idx (bsearch-keys (subseq keys 0 count) key cmp)))
      (if (and (< idx count) (zerop (funcall cmp key (svref keys idx))))
          (values (svref (btree-transient-leaf-vals node) idx) t)
          (values not-found nil))))
   ((btree-node-p node)
    (let* ((keys (btree-node-keys node))
           (idx (bsearch-keys keys key cmp)))
      (btree-get-transient-aware (svref (btree-node-children node) idx) key cmp not-found)))
   ((btree-transient-node-p node)
    (let* ((keys (btree-transient-node-keys node))
           (count (btree-transient-node-count node))
           (idx (bsearch-keys (subseq keys 0 (max 0 (1- count))) key cmp)))
      (btree-get-transient-aware (svref (btree-transient-node-children node) idx) key cmp not-found)))))

(defun btree-assoc-node! (node key val cmp token)
  "Transient version of assoc-node."
  (if (null node)
      (values (%make-btree-leaf (vector key) (vector val)) nil nil nil nil)
      
      (if (or (btree-leaf-p node) (btree-transient-leaf-p node))
          (let* ((enode (ensure-editable-btree-leaf node token))
                 (keys (btree-transient-leaf-keys enode))
                 (vals (btree-transient-leaf-vals enode))
                 (count (btree-transient-leaf-count enode))
                 ;; Bsearch over the active range
                 (idx (bsearch-keys (subseq keys 0 count) key cmp)))
            
            (if (and (< idx count) (zerop (funcall cmp key (svref keys idx))))
                (let ((old-val (svref vals idx)))
                  (setf (svref vals idx) val)
                  (values enode nil nil old-val t))
                
                (if (< count 32)
                    (progn
                      ;; Shift right
                      (replace keys keys :start1 (1+ idx) :start2 idx :end2 count)
                      (replace vals vals :start1 (1+ idx) :start2 idx :end2 count)
                      (setf (svref keys idx) key)
                      (setf (svref vals idx) val)
                      (incf (btree-transient-leaf-count enode))
                      (values enode nil nil nil nil))
                    
                    ;; Full: split
                    (let* ((new-keys (make-array 33))
                           (new-vals (make-array 33)))
                      (replace new-keys keys :end2 idx)
                      (setf (svref new-keys idx) key)
                      (replace new-keys keys :start1 (1+ idx) :start2 idx :end2 32)
                      (replace new-vals vals :end2 idx)
                      (setf (svref new-vals idx) val)
                      (replace new-vals vals :start1 (1+ idx) :start2 idx :end2 32)
                      (multiple-value-bind (left sk right) (split-leaf new-keys new-vals)
                        (values left sk right nil nil))))))

          ;; Internal routing node
          (let* ((enode (ensure-editable-btree-node node token))
                 (keys (btree-transient-node-keys enode))
                 (children (btree-transient-node-children enode))
                 (count (btree-transient-node-count enode))
                 (idx (bsearch-keys (subseq keys 0 (max 0 (1- count))) key cmp)))
            (multiple-value-bind (new-child split-key split-right old-val found-p)
                (btree-assoc-node! (svref children idx) key val cmp token)
              (setf (svref children idx) new-child)
              (if found-p
                  (values enode nil nil old-val t)
                  (if split-key
                      (if (< count 32)
                          (progn
                            (replace keys keys :start1 (1+ idx) :start2 idx :end2 (1- count))
                            (setf (svref keys idx) split-key)
                            (replace children children :start1 (+ 2 idx) :start2 (1+ idx) :end2 count)
                            (setf (svref children (1+ idx)) split-right)
                            (incf (btree-transient-node-count enode))
                            (values enode nil nil nil nil))
                          ;; Split node
                          (let* ((new-keys (make-array 32))
                                 (new-children (make-array 33)))
                            (replace new-keys keys :end2 idx)
                            (setf (svref new-keys idx) split-key)
                            (replace new-keys keys :start1 (1+ idx) :start2 idx :end2 31)
                            
                            (replace new-children children :end2 idx)
                            (setf (svref new-children idx) new-child)
                            (setf (svref new-children (1+ idx)) split-right)
                            (replace new-children children :start1 (+ 2 idx) :start2 (1+ idx) :end2 32)
                            (multiple-value-bind (left sk right) (split-node new-keys new-children)
                              (values left sk right nil nil))))
                      (values enode nil nil nil nil))))))))
                      
(defun btree-dissoc-node! (node key cmp token)
  (cond
   ((null node) (values nil nil nil))
   ((or (btree-leaf-p node) (btree-transient-leaf-p node))
    (let* ((enode (ensure-editable-btree-leaf node token))
           (keys (btree-transient-leaf-keys enode))
           (vals (btree-transient-leaf-vals enode))
           (count (btree-transient-leaf-count enode))
           (idx (bsearch-keys (subseq keys 0 count) key cmp)))
      (if (and (< idx count) (zerop (funcall cmp key (svref keys idx))))
          (let ((old-val (svref vals idx)))
            (replace keys keys :start1 idx :start2 (1+ idx) :end2 count)
            (replace vals vals :start1 idx :start2 (1+ idx) :end2 count)
            (decf (btree-transient-leaf-count enode))
            (if (zerop (btree-transient-leaf-count enode))
                (values nil old-val t)
                (values enode old-val t)))
          (values enode nil nil))))
   (t
    (let* ((enode (ensure-editable-btree-node node token))
           (keys (btree-transient-node-keys enode))
           (children (btree-transient-node-children enode))
           (count (btree-transient-node-count enode))
           (idx (bsearch-keys (subseq keys 0 (max 0 (1- count))) key cmp)))
      (multiple-value-bind (new-child old-val found-p)
          (btree-dissoc-node! (svref children idx) key cmp token)
        (if (not found-p)
            (values enode nil nil)
            (if (null new-child)
                (progn
                  (if (zerop idx)
                      (replace keys keys :start1 0 :start2 1 :end2 (1- count))
                      (replace keys keys :start1 (1- idx) :start2 idx :end2 (1- count)))
                  (replace children children :start1 idx :start2 (1+ idx) :end2 count)
                  (decf (btree-transient-node-count enode))
                  (if (zerop (btree-transient-node-count enode))
                      (values nil old-val t)
                      (values enode old-val t)))
                (progn
                  (setf (svref children idx) new-child)
                  (values enode old-val t)))))))))

(defun first-key-transient-aware (node)
  (cond
   ((btree-leaf-p node) (svref (btree-leaf-keys node) 0))
   ((btree-transient-leaf-p node) (svref (btree-transient-leaf-keys node) 0))
   ((btree-node-p node) (first-key-transient-aware (svref (btree-node-children node) 0)))
   ((btree-transient-node-p node) (first-key-transient-aware (svref (btree-transient-node-children node) 0)))))

'''

text = text.replace('(defun btree-get', prefix + '\n(defun btree-get')
text = text.replace('(defun bsearch-keys', '(declaim (notinline bsearch-keys insert-at remove-at update-at btree-get split-leaf split-node btree-assoc-node btree-dissoc-node first-key btree-bulk-load))\n(defun bsearch-keys')

# redefine btree-get globally in here
text = text.replace('(defun btree-get (node', '(defun btree-get (node') # it is going to just be redefined later in our replaced text

with open('patch.py', 'w') as f:
    pass

with open('btree_code_out.lisp', 'w') as out:
    out.write(text)
