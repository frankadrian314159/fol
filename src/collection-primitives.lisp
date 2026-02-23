(in-package :fol.compiler.collection-primitives)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +branch-factor+ 32)
  (defconstant +bit-mask+ 31)
  (defconstant +bit-shift+ 5))

(deftype internal-node () `(simple-vector ,+branch-factor+))

;;; ============================================================================
;;; Shared Utility Functions
;;; ============================================================================

(defun %clone-node (node)
  (declare (type internal-node node) (optimize (speed 3) (safety 0)))
  (copy-seq node))

;;; ============================================================================
;;; %vec-f64 Implementation
;;; ============================================================================

(deftype f64-leaf () `(simple-array double-float (,+branch-factor+)))

(defstruct (%vec-f64 (:constructor %make-vec-f64)
                     (:predicate %vec-f64?)
                     (:conc-name %f64-))
  (count 0 :type fixnum)
  (shift 0 :type fixnum)
  (root #() :type simple-vector)
  (tail (make-array 0 :element-type 'double-float) :type (simple-array double-float (*))))

(defun %vec-f64-count (v) (declare (type %vec-f64 v)) (%f64-count v))

(defun %vec-f64-tail-off (v)
  (declare (type %vec-f64 v) (optimize (speed 3) (safety 0)))
  (let ((cnt (%f64-count v)))
    (if (< cnt +branch-factor+) 0 (ash (ash (1- cnt) (- +bit-shift+)) +bit-shift+))))

(defun %vec-f64-ref (v index &optional not-found)
  (declare (type %vec-f64 v) 
           (type fixnum index) 
           (optimize (speed 3) (safety 0)))
           
  ;; 1. The Safe Bounds Check
  (if (or (< index 0) (>= index (%f64-count v)))
      (values not-found nil) ;; Return (fallback-value, NIL)
      
      ;; 2. The Tail Fast-Path
      (if (>= index (%vec-f64-tail-off v))
          (values (svref (%f64-tail v) (logand index +bit-mask+)) t) ;; Return (value, T)
          
          ;; 3. The Tree Traversal
          (let ((node (%f64-root v))
                (shift (%f64-shift v)))
            (loop for level-shift from shift downto +bit-shift+ by +bit-shift+
                  do (setf node (svref (the internal-node node) 
                                       (logand (ash index (- level-shift)) +bit-mask+))))
            (values (svref (the f64-leaf node) (logand index +bit-mask+)) t))))) ;; Return (value, T)

(defun %f64-clone-leaf (leaf)
  (declare (type f64-leaf leaf) (optimize (speed 3) (safety 0)))
  (copy-seq leaf))

(defun %f64-new-path (shift leaf)
  (if (<= shift 0) leaf
      (let ((node (make-array +branch-factor+ :initial-element nil)))
        (setf (svref node 0) (%f64-new-path (- shift +bit-shift+) leaf))
        node)))

(defun %f64-push-tail (shift node idx tail-node)
  (let ((new-node (%clone-node node))
        (sub-idx (logand (ash idx (- shift)) +bit-mask+)))
    (if (= shift +bit-shift+)
        (setf (svref new-node sub-idx) tail-node)
        (let ((child (svref node sub-idx)))
          (if child
              (setf (svref new-node sub-idx) (%f64-push-tail (- shift +bit-shift+) child idx tail-node))
              (setf (svref new-node sub-idx) (%f64-new-path (- shift +bit-shift+) tail-node)))))
    new-node))

(defun %vec-f64-conj (v val)
  (declare (type %vec-f64 v) (type double-float val) (optimize (speed 3) (safety 0)))
  (let* ((cnt (%f64-count v))
         (tail (%f64-tail v))
         (tail-len (length tail)))
    (if (< tail-len +branch-factor+)
        (let ((new-tail (make-array (1+ tail-len) :element-type 'double-float)))
          (replace new-tail tail)
          (setf (aref new-tail tail-len) val)
          (%make-vec-f64 :count (1+ cnt) :shift (%f64-shift v) :root (%f64-root v) :tail new-tail))
        (let* ((tail-node tail)
               (new-tail (make-array 1 :element-type 'double-float))
               (root (%f64-root v))
               (shift (%f64-shift v)))
          (setf (aref new-tail 0) val)
          (cond
           ((zerop (length root))
             (let ((new-root (make-array +branch-factor+)))
               (setf (svref new-root 0) tail-node)
               (%make-vec-f64 :count (1+ cnt) :shift +bit-shift+ :root new-root :tail new-tail)))
           ((> (ash cnt (- +bit-shift+)) (ash 1 shift))
             (let ((new-root (make-array +branch-factor+ :initial-element nil)))
               (setf (svref new-root 0) root)
               (setf (svref new-root 1) (%f64-new-path shift tail-node))
               (%make-vec-f64 :count (1+ cnt) :shift (+ shift +bit-shift+) :root new-root :tail new-tail)))
           (t (%make-vec-f64 :count (1+ cnt) :shift shift :root (%f64-push-tail shift root (1- cnt) tail-node) :tail new-tail)))))))

(defun %vec-f64-assoc (v index new-val)
  (declare (type %vec-f64 v) (type fixnum index) (type double-float new-val) (optimize (speed 3) (safety 0)))
  (let ((cnt (%f64-count v)))
    (if (>= index (%vec-f64-tail-off v))
        (let* ((old-tail (%f64-tail v))
               (new-tail (make-array (length old-tail) :element-type 'double-float)))
          (replace new-tail old-tail)
          (setf (aref new-tail (logand index +bit-mask+)) new-val)
          (%make-vec-f64 :count cnt :shift (%f64-shift v) :root (%f64-root v) :tail new-tail))
        (labels ((update (node level-shift)
                         (if (= level-shift 0)
                             (let ((new-leaf (%f64-clone-leaf (the f64-leaf node))))
                               (setf (aref new-leaf (logand index +bit-mask+)) new-val)
                               new-leaf)
                             (let ((new-node (%clone-node (the internal-node node)))
                                   (child-idx (logand (ash index (- level-shift)) +bit-mask+)))
                               (setf (svref new-node child-idx)
                                 (update (svref (the internal-node node) child-idx)
                                         (- level-shift +bit-shift+)))
                               new-node))))
          (%make-vec-f64 :count cnt :shift (%f64-shift v)
                         :root (update (%f64-root v) (%f64-shift v))
                         :tail (%f64-tail v))))))

(defparameter %empty-vec-f64 (%make-vec-f64))


(defun %make-filled-vec-f64 (size initial-value)
  "Creates a persistent vector of SIZE filled with INITIAL-VALUE in O(N) time but O(log N) memory."
  (declare (type fixnum size) (optimize (speed 3) (safety 0)))

  ;; Base Case: The vector fits entirely within the tail array
  (if (<= size 32)
      (let ((tail (make-array size :element-type 'double-float :initial-element initial-value)))
        (%make-vec-f64 :count size :shift 0 :root #() :tail tail))

      ;; General Case: We need to build a tree
      (let* ((tail-len (logand size 31))
             (tree-count (- size tail-len))
             ;; 1. Allocate the Tail
             (tail (make-array tail-len :element-type 'double-float :initial-element initial-value))
             ;; 2. The Magic: Allocate ONE leaf to represent all identical leaves
             (shared-leaf (make-array 32 :element-type 'double-float :initial-element initial-value))
             (nodes nil))

        ;; 3. Populate the bottom layer using the exact same shared leaf pointer
        (loop repeat (ash tree-count -5) ; Equivalent to (tree-count / 32)
              do (push shared-leaf nodes))

        ;; 4. Build the internal routing nodes bottom-up
        (let ((shift 0))
          (loop while (> (length nodes) 1)
                do (let ((next-level nil)
                         (current nodes))
                     ;; Group nodes into chunks of 32
                     (loop while current
                           do (let ((internal (make-array 32 :initial-element nil)))
                                (loop for i from 0 below 32
                                      while current
                                      do (setf (svref internal i) (pop current)))
                                (push internal next-level)))
                     ;; Prepare for the next level up
                     (setf nodes (nreverse next-level))
                     (incf shift 5)))

          ;; 5. The final remaining node is the root
          (%make-vec-f64 :count size
                         :shift shift
                         :root (car nodes)
                         :tail tail)))))

(defun %build-vec-f64-from-list (lst)
  "Bulk-loads a list of elements into a persistent vector trie in strict O(N) time."
  (let ((count (length lst)))
    (if (<= count 32)
        ;; Base Case: Fits entirely in the tail
        (let ((tail (make-array count :initial-element nil)))
          (loop for item in lst for i from 0 do (setf (svref tail i) item))
          (%make-vec-f64 :count count :shift 0 :root #() :tail tail))
          
        ;; General Case: Build the tree bottom-up
        (let* ((tail-len (logand count 31))
               (tree-count (- count tail-len))
               (tail (make-array tail-len :element-type double-float :initial-element 0.0d0))
               (nodes nil)
               (current lst))
               
          ;; 1. Build all the bottom-level leaf nodes (32 elements each)
          (loop repeat (ash tree-count -5)
                do (let ((leaf (make-array 32 :element-type double-float :initial-element 0.0f0)))
                     (loop for i from 0 below 32
                           do (setf (svref leaf i) (car current)
                                    current (cdr current)))
                     (push leaf nodes)))
          (setf nodes (nreverse nodes))

          ;; 2. Fill the tail array with the remaining elements
          (loop for i from 0 below tail-len
                do (setf (svref tail i) (car current)
                         current (cdr current)))

          ;; 3. Build the internal routing nodes bottom-up
          (let ((shift 0))
            (loop while (> (length nodes) 1)
                  do (let ((next-level nil))
                       ;; Group nodes into chunks of 32
                       (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                             do (let ((internal (make-array 32 :initial-element nil)))
                                  (loop for node in chunk for i from 0 below 32
                                        do (setf (svref internal i) node))
                                  (push internal next-level)))
                       (setf nodes (nreverse next-level))
                       (incf shift 5)))

            ;; 4. The final remaining node is our root
            (%make-vec-t :count count
                         :shift shift
                         :root (car nodes)
                         :tail tail))))))


;;; ============================================================================
;;; %vec-f32 Implementation
;;; ============================================================================

(deftype f32-leaf () `(simple-array single-float (,+branch-factor+)))

(defstruct (%vec-f32 (:constructor %make-vec-f32)
                     (:predicate %vec-f32?)
                     (:conc-name %f32-))
  (count 0 :type fixnum)
  (shift 0 :type fixnum)
  (root #() :type simple-vector)
  (tail (make-array 0 :element-type 'single-float) :type (simple-array single-float (*))))

(defun %vec-f32-count (v) (declare (type %vec-f32 v)) (%f32-count v))

(defun %vec-f32-tail-off (v)
  (declare (type %vec-f32 v) (optimize (speed 3) (safety 0)))
  (let ((cnt (%f32-count v)))
    (if (< cnt +branch-factor+) 0 (ash (ash (1- cnt) (- +bit-shift+)) +bit-shift+))))

(defun %vec-f32-ref (v index &optional not-found)
  (declare (type %vec-f32 v) 
           (type fixnum index) 
           (optimize (speed 3) (safety 0)))
           
  ;; 1. The Safe Bounds Check
  (if (or (< index 0) (>= index (%f32-count v)))
      (values not-found nil) ;; Return (fallback-value, NIL)
      
      ;; 2. The Tail Fast-Path
      (if (>= index (%vec-f32-tail-off v))
          (values (svref (%f32-tail v) (logand index +bit-mask+)) t) ;; Return (value, T)
          
          ;; 3. The Tree Traversal
          (let ((node (%f32-root v))
                (shift (%f32-shift v)))
            (loop for level-shift from shift downto +bit-shift+ by +bit-shift+
                  do (setf node (svref (the internal-node node) 
                                       (logand (ash index (- level-shift)) +bit-mask+))))
            (values (svref (the f32-leaf node) (logand index +bit-mask+)) t))))) ;; Return (value, T)

(defun %f32-clone-leaf (leaf)
  (declare (type f32-leaf leaf) (optimize (speed 3) (safety 0)))
  (copy-seq leaf))


(defun %f32-new-path (shift leaf)
  (if (<= shift 0) leaf
      (let ((node (make-array +branch-factor+ :initial-element nil)))
        (setf (svref node 0) (%f32-new-path (- shift +bit-shift+) leaf))
        node)))

(defun %f32-push-tail (shift node idx tail-node)
  (let ((new-node (%clone-node node))
        (sub-idx (logand (ash idx (- shift)) +bit-mask+)))
    (if (= shift +bit-shift+)
        (setf (svref new-node sub-idx) tail-node)
        (let ((child (svref node sub-idx)))
          (if child
              (setf (svref new-node sub-idx) (%f32-push-tail (- shift +bit-shift+) child idx tail-node))
              (setf (svref new-node sub-idx) (%f32-new-path (- shift +bit-shift+) tail-node)))))
    new-node))

(defun %vec-f32-conj (v val)
  (declare (type %vec-f32 v) (type single-float val) (optimize (speed 3) (safety 0)))
  (let* ((cnt (%f32-count v))
         (tail (%f32-tail v))
         (tail-len (length tail)))
    (if (< tail-len +branch-factor+)
        (let ((new-tail (make-array (1+ tail-len) :element-type 'single-float)))
          (replace new-tail tail)
          (setf (aref new-tail tail-len) val)
          (%make-vec-f32 :count (1+ cnt) :shift (%f32-shift v) :root (%f32-root v) :tail new-tail))
        (let* ((tail-node tail)
               (new-tail (make-array 1 :element-type 'single-float))
               (root (%f32-root v))
               (shift (%f32-shift v)))
          (setf (aref new-tail 0) val)
          (cond
           ((zerop (length root))
             (let ((new-root (make-array +branch-factor+)))
               (setf (svref new-root 0) tail-node)
               (%make-vec-f32 :count (1+ cnt) :shift +bit-shift+ :root new-root :tail new-tail)))
           ((> (ash cnt (- +bit-shift+)) (ash 1 shift))
             (let ((new-root (make-array +branch-factor+ :initial-element nil)))
               (setf (svref new-root 0) root)
               (setf (svref new-root 1) (%f32-new-path shift tail-node))
               (%make-vec-f32 :count (1+ cnt) :shift (+ shift +bit-shift+) :root new-root :tail new-tail)))
           (t (%make-vec-f32 :count (1+ cnt) :shift shift :root (%f32-push-tail shift root (1- cnt) tail-node) :tail new-tail)))))))

(defun %vec-f32-assoc (v index new-val)
  (declare (type %vec-f32 v) (type fixnum index) (type single-float new-val) (optimize (speed 3) (safety 0)))
  (let ((cnt (%f32-count v)))
    (if (>= index (%vec-f32-tail-off v))
        (let* ((old-tail (%f32-tail v))
               (new-tail (make-array (length old-tail) :element-type 'single-float)))
          (replace new-tail old-tail)
          (setf (aref new-tail (logand index +bit-mask+)) new-val)
          (%make-vec-f32 :count cnt :shift (%f32-shift v) :root (%f32-root v) :tail new-tail))
        (labels ((update (node level-shift)
                         (if (= level-shift 0)
                             (let ((new-leaf (%f32-clone-leaf (the f32-leaf node))))
                               (setf (aref new-leaf (logand index +bit-mask+)) new-val)
                               new-leaf)
                             (let ((new-node (%clone-node (the internal-node node)))
                                   (child-idx (logand (ash index (- level-shift)) +bit-mask+)))
                               (setf (svref new-node child-idx)
                                 (update (svref (the internal-node node) child-idx)
                                         (- level-shift +bit-shift+)))
                               new-node))))
          (%make-vec-f32 :count cnt :shift (%f32-shift v)
                         :root (update (%f32-root v) (%f32-shift v))
                         :tail (%f32-tail v))))))

(defparameter %empty-vec-f32 (%make-vec-f32))

(defun %make-filled-vec-f32 (size initial-value)
  "Creates a persistent vector of SIZE filled with INITIAL-VALUE in O(N) time but O(log N) memory."
  (declare (type fixnum size) (optimize (speed 3) (safety 0)))

  ;; Base Case: The vector fits entirely within the tail array
  (if (<= size 32)
      (let ((tail (make-array size :element-type single-float :initial-element initial-value)))
        (%make-vec-f32 :count size :shift 0 :root #() :tail tail))

      ;; General Case: We need to build a tree
      (let* ((tail-len (logand size 31))
             (tree-count (- size tail-len))
             ;; 1. Allocate the Tail
             (tail (make-array tail-len :element-type single-float :initial-element initial-value))
             ;; 2. The Magic: Allocate ONE leaf to represent all identical leaves
             (shared-leaf (make-array 32 :element-type single-float :initial-element initial-value))
             (nodes nil))

        ;; 3. Populate the bottom layer using the exact same shared leaf pointer
        (loop repeat (ash tree-count -5) ; Equivalent to (tree-count / 32)
              do (push shared-leaf nodes))

        ;; 4. Build the internal routing nodes bottom-up
        (let ((shift 0))
          (loop while (> (length nodes) 1)
                do (let ((next-level nil)
                         (current nodes))
                     ;; Group nodes into chunks of 32
                     (loop while current
                           do (let ((internal (make-array 32 :initial-element nil)))
                                (loop for i from 0 below 32
                                      while current
                                      do (setf (svref internal i) (pop current)))
                                (push internal next-level)))
                     ;; Prepare for the next level up
                     (setf nodes (nreverse next-level))
                     (incf shift 5)))

          ;; 5. The final remaining node is the root
          (%make-vec-f32 :count size
                         :shift shift
                         :root (car nodes)
                         :tail tail)))))

(defun %build-vec-f32-from-list (lst)
  "Bulk-loads a list of elements into a persistent vector trie in strict O(N) time."
  (let ((count (length lst)))
    (if (<= count 32)
        ;; Base Case: Fits entirely in the tail
        (let ((tail (make-array count :initial-element nil)))
          (loop for item in lst for i from 0 do (setf (svref tail i) item))
          (%make-vec-f32 :count count :shift 0 :root #() :tail tail))
          
        ;; General Case: Build the tree bottom-up
        (let* ((tail-len (logand count 31))
               (tree-count (- count tail-len))
               (tail (make-array tail-len :element-type single-float :initial-element 0.0f0))
               (nodes nil)
               (current lst))
               
          ;; 1. Build all the bottom-level leaf nodes (32 elements each)
          (loop repeat (ash tree-count -5)
                do (let ((leaf (make-array 32 :element-type single-float :initial-element 0.0f0)))
                     (loop for i from 0 below 32
                           do (setf (svref leaf i) (car current)
                                    current (cdr current)))
                     (push leaf nodes)))
          (setf nodes (nreverse nodes))

          ;; 2. Fill the tail array with the remaining elements
          (loop for i from 0 below tail-len
                do (setf (svref tail i) (car current)
                         current (cdr current)))

          ;; 3. Build the internal routing nodes bottom-up
          (let ((shift 0))
            (loop while (> (length nodes) 1)
                  do (let ((next-level nil))
                       ;; Group nodes into chunks of 32
                       (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                             do (let ((internal (make-array 32 :initial-element nil)))
                                  (loop for node in chunk for i from 0 below 32
                                        do (setf (svref internal i) node))
                                  (push internal next-level)))
                       (setf nodes (nreverse next-level))
                       (incf shift 5)))

            ;; 4. The final remaining node is our root
            (%make-vec-t :count count
                         :shift shift
                         :root (car nodes)
                         :tail tail))))))

;;; ============================================================================
;;; %vec-t Implementation
;;; ============================================================================

(deftype t-leaf () `(simple-vector ,+branch-factor+))

(defstruct (%vec-t (:constructor %make-vec-t)
                   (:predicate %vec-t?)
                   (:conc-name %t-))
  (count 0 :type fixnum)
  (shift 0 :type fixnum)
  (root #() :type simple-vector)
  (tail (make-array 0) :type simple-vector))

(defun %vec-t-count (v) (declare (type %vec-t v)) (%t-count v))

(defun %vec-t-tail-off (v)
  (declare (type %vec-t v) (optimize (speed 3) (safety 0)))
  (let ((cnt (%t-count v)))
    (if (< cnt +branch-factor+) 0 (ash (ash (1- cnt) (- +bit-shift+)) +bit-shift+))))

(defun %vec-t-ref (v index &optional not-found)
  (declare (type %vec-t v) 
           (type fixnum index) 
           (optimize (speed 3) (safety 0)))
           
  ;; 1. The Safe Bounds Check
  (if (or (< index 0) (>= index (%t-count v)))
      (values not-found nil) ;; Return (fallback-value, NIL)
      
      ;; 2. The Tail Fast-Path
      (if (>= index (%vec-t-tail-off v))
          (values (svref (%t-tail v) (logand index +bit-mask+)) t) ;; Return (value, T)
          
          ;; 3. The Tree Traversal
          (let ((node (%t-root v))
                (shift (%t-shift v)))
            (loop for level-shift from shift downto +bit-shift+ by +bit-shift+
                  do (setf node (svref (the internal-node node) 
                                       (logand (ash index (- level-shift)) +bit-mask+))))
            (values (svref (the t-leaf node) (logand index +bit-mask+)) t))))) ;; Return (value, T)

(defun %t-clone-leaf (leaf)
  (declare (type t-leaf leaf) (optimize (speed 3) (safety 0)))
  (copy-seq leaf))


(defun %t-new-path (shift leaf)
  (if (<= shift 0) leaf
      (let ((node (make-array +branch-factor+ :initial-element nil)))
        (setf (svref node 0) (%t-new-path (- shift +bit-shift+) leaf))
        node)))

(defun %t-push-tail (shift node idx tail-node)
  (let ((new-node (%clone-node node))
        (sub-idx (logand (ash idx (- shift)) +bit-mask+)))
    (if (= shift +bit-shift+)
        (setf (svref new-node sub-idx) tail-node)
        (let ((child (svref node sub-idx)))
          (if child
              (setf (svref new-node sub-idx) (%t-push-tail (- shift +bit-shift+) child idx tail-node))
              (setf (svref new-node sub-idx) (%t-new-path (- shift +bit-shift+) tail-node)))))
    new-node))

(defun %vec-t-conj (v val)
  (declare (type %vec-t v) (optimize (speed 3) (safety 0)))
  (let* ((cnt (%t-count v))
         (tail (%t-tail v))
         (tail-len (length tail)))
    (if (< tail-len +branch-factor+)
        (let ((new-tail (make-array (1+ tail-len))))
          (replace new-tail tail)
          (setf (svref new-tail tail-len) val)
          (%make-vec-t :count (1+ cnt) :shift (%t-shift v) :root (%t-root v) :tail new-tail))
        (let* ((tail-node tail)
               (new-tail (make-array 1))
               (root (%t-root v))
               (shift (%t-shift v)))
          (setf (svref new-tail 0) val)
          (cond
           ((zerop (length root))
             (let ((new-root (make-array +branch-factor+)))
               (setf (svref new-root 0) tail-node)
               (%make-vec-t :count (1+ cnt) :shift +bit-shift+ :root new-root :tail new-tail)))
           ((> (ash cnt (- +bit-shift+)) (ash 1 shift))
             (let ((new-root (make-array +branch-factor+ :initial-element nil)))
               (setf (svref new-root 0) root)
               (setf (svref new-root 1) (%t-new-path shift tail-node))
               (%make-vec-t :count (1+ cnt) :shift (+ shift +bit-shift+) :root new-root :tail new-tail)))
           (t (%make-vec-t :count (1+ cnt) :shift shift :root (%t-push-tail shift root (1- cnt) tail-node) :tail new-tail)))))))

(defun %vec-t-assoc (v index new-val)
  (declare (type %vec-t v) (type fixnum index) (optimize (speed 3) (safety 0)))
  (let ((cnt (%t-count v)))
    (if (>= index (%vec-t-tail-off v))
        (let* ((old-tail (%t-tail v))
               (new-tail (make-array (length old-tail))))
          (replace new-tail old-tail)
          (setf (svref new-tail (logand index +bit-mask+)) new-val)
          (%make-vec-t :count cnt :shift (%t-shift v) :root (%t-root v) :tail new-tail))
        (labels ((update (node level-shift)
                         (if (= level-shift 0)
                             (let ((new-leaf (%t-clone-leaf (the t-leaf node))))
                               (setf (svref new-leaf (logand index +bit-mask+)) new-val)
                               new-leaf)
                             (let ((new-node (%clone-node (the internal-node node)))
                                   (child-idx (logand (ash index (- level-shift)) +bit-mask+)))
                               (setf (svref new-node child-idx)
                                 (update (svref (the internal-node node) child-idx)
                                         (- level-shift +bit-shift+)))
                               new-node))))
          (%make-vec-t :count cnt :shift (%t-shift v)
                       :root (update (%t-root v) (%t-shift v))
                       :tail (%t-tail v))))))

(defparameter %empty-vec-t (%make-vec-t))

(defun %make-filled-vec-t (size initial-value)
  "Creates a persistent vector of SIZE filled with INITIAL-VALUE in O(N) time but O(log N) memory."
  (declare (type fixnum size) (optimize (speed 3) (safety 0)))

  ;; Base Case: The vector fits entirely within the tail array
  (if (<= size 32)
      (let ((tail (make-array size :initial-element initial-value)))
        (%make-vec-t :count size :shift 0 :root #() :tail tail))

      ;; General Case: We need to build a tree
      (let* ((tail-len (logand size 31))
             (tree-count (- size tail-len))
             ;; 1. Allocate the Tail
             (tail (make-array tail-len :initial-element initial-value))
             ;; 2. The Magic: Allocate ONE leaf to represent all identical leaves
             (shared-leaf (make-array 32 :initial-element initial-value))
             (nodes nil))

        ;; 3. Populate the bottom layer using the exact same shared leaf pointer
        (loop repeat (ash tree-count -5) ; Equivalent to (tree-count / 32)
              do (push shared-leaf nodes))

        ;; 4. Build the internal routing nodes bottom-up
        (let ((shift 0))
          (loop while (> (length nodes) 1)
                do (let ((next-level nil)
                         (current nodes))
                     ;; Group nodes into chunks of 32
                     (loop while current
                           do (let ((internal (make-array 32 :initial-element nil)))
                                (loop for i from 0 below 32
                                      while current
                                      do (setf (svref internal i) (pop current)))
                                (push internal next-level)))
                     ;; Prepare for the next level up
                     (setf nodes (nreverse next-level))
                     (incf shift 5)))

          ;; 5. The final remaining node is the root
          (%make-vec-t :count size
                       :shift shift
                       :root (car nodes)
                       :tail tail)))))

(defun %build-vec-t-from-list (lst)
  "Bulk-loads a list of elements into a persistent vector trie in strict O(N) time."
  (let ((count (length lst)))
    (if (<= count 32)
        ;; Base Case: Fits entirely in the tail
        (let ((tail (make-array count :initial-element nil)))
          (loop for item in lst for i from 0 do (setf (svref tail i) item))
          (%make-vec-t :count count :shift 0 :root #() :tail tail))
          
        ;; General Case: Build the tree bottom-up
        (let* ((tail-len (logand count 31))
               (tree-count (- count tail-len))
               (tail (make-array tail-len :initial-element nil))
               (nodes nil)
               (current lst))
               
          ;; 1. Build all the bottom-level leaf nodes (32 elements each)
          (loop repeat (ash tree-count -5)
                do (let ((leaf (make-array 32 :initial-element nil)))
                     (loop for i from 0 below 32
                           do (setf (svref leaf i) (car current)
                                    current (cdr current)))
                     (push leaf nodes)))
          (setf nodes (nreverse nodes))

          ;; 2. Fill the tail array with the remaining elements
          (loop for i from 0 below tail-len
                do (setf (svref tail i) (car current)
                         current (cdr current)))

          ;; 3. Build the internal routing nodes bottom-up
          (let ((shift 0))
            (loop while (> (length nodes) 1)
                  do (let ((next-level nil))
                       ;; Group nodes into chunks of 32
                       (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                             do (let ((internal (make-array 32 :initial-element nil)))
                                  (loop for node in chunk for i from 0 below 32
                                        do (setf (svref internal i) node))
                                  (push internal next-level)))
                       (setf nodes (nreverse next-level))
                       (incf shift 5)))

            ;; 4. The final remaining node is our root
            (%make-vec-t :count count
                         :shift shift
                         :root (car nodes)
                         :tail tail))))))
;;; ============================================================================
;;; %vec-fix64 Implementation
;;; ============================================================================

(deftype fix64-leaf () `(simple-array fixnum (,+branch-factor+)))

(defstruct (%vec-fix64 (:constructor %make-vec-fix64)
                       (:predicate %vec-fix64?)
                       (:conc-name %fix64-))
  (count 0 :type fixnum)
  (shift 0 :type fixnum)
  (root #() :type simple-vector)
  (tail (make-array 0 :element-type 'fixnum) :type (simple-array fixnum (*))))

(defun %vec-fix64-count (v) (declare (type %vec-fix64 v)) (%fix64-count v))

(defun %vec-fix64-tail-off (v)
  (declare (type %vec-fix64 v) (optimize (speed 3) (safety 0)))
  (let ((cnt (%fix64-count v)))
    (if (< cnt +branch-factor+) 0 (ash (ash (1- cnt) (- +bit-shift+)) +bit-shift+))))

(defun %vec-fix64-ref (v index &optional not-found)
  (declare (type %vec-fix64 v) 
           (type fixnum index) 
           (optimize (speed 3) (safety 0)))
           
  ;; 1. The Safe Bounds Check
  (if (or (< index 0) (>= index (%fix64-count v)))
      (values not-found nil) ;; Return (fallback-value, NIL)
      
      ;; 2. The Tail Fast-Path
      (if (>= index (%vec-fix64-tail-off v))
          (values (svref (%fix64-tail v) (logand index +bit-mask+)) t) ;; Return (value, T)
          
          ;; 3. The Tree Traversal
          (let ((node (%fix64-root v))
                (shift (%fix64-shift v)))
            (loop for level-shift from shift downto +bit-shift+ by +bit-shift+
                  do (setf node (svref (the internal-node node) 
                                       (logand (ash index (- level-shift)) +bit-mask+))))
            (values (svref (the fix64-leaf node) (logand index +bit-mask+)) t))))) ;; Return (value, T)


(defun %fix64-clone-leaf (leaf)
  (declare (type fix64-leaf leaf) (optimize (speed 3) (safety 0)))
  (copy-seq leaf))


(defun %fix64-new-path (shift leaf)
  (if (<= shift 0) leaf
      (let ((node (make-array +branch-factor+ :initial-element nil)))
        (setf (svref node 0) (%fix64-new-path (- shift +bit-shift+) leaf))
        node)))

(defun %fix64-push-tail (shift node idx tail-node)
  (let ((new-node (%clone-node node))
        (sub-idx (logand (ash idx (- shift)) +bit-mask+)))
    (if (= shift +bit-shift+)
        (setf (svref new-node sub-idx) tail-node)
        (let ((child (svref node sub-idx)))
          (if child
              (setf (svref new-node sub-idx) (%fix64-push-tail (- shift +bit-shift+) child idx tail-node))
              (setf (svref new-node sub-idx) (%fix64-new-path (- shift +bit-shift+) tail-node)))))
    new-node))

(defun %vec-fix64-conj (v val)
  (declare (type %vec-fix64 v) (type fixnum val) (optimize (speed 3) (safety 0)))
  (let* ((cnt (%fix64-count v))
         (tail (%fix64-tail v))
         (tail-len (length tail)))
    (if (< tail-len +branch-factor+)
        (let ((new-tail (make-array (1+ tail-len) :element-type 'fixnum)))
          (replace new-tail tail)
          (setf (aref new-tail tail-len) val)
          (%make-vec-fix64 :count (1+ cnt) :shift (%fix64-shift v) :root (%fix64-root v) :tail new-tail))
        (let* ((tail-node tail)
               (new-tail (make-array 1 :element-type 'fixnum))
               (root (%fix64-root v))
               (shift (%fix64-shift v)))
          (setf (aref new-tail 0) val)
          (cond
           ((zerop (length root))
             (let ((new-root (make-array +branch-factor+)))
               (setf (svref new-root 0) tail-node)
               (%make-vec-fix64 :count (1+ cnt) :shift +bit-shift+ :root new-root :tail new-tail)))
           ((> (ash cnt (- +bit-shift+)) (ash 1 shift))
             (let ((new-root (make-array +branch-factor+ :initial-element nil)))
               (setf (svref new-root 0) root)
               (setf (svref new-root 1) (%fix64-new-path shift tail-node))
               (%make-vec-fix64 :count (1+ cnt) :shift (+ shift +bit-shift+) :root new-root :tail new-tail)))
           (t (%make-vec-fix64 :count (1+ cnt) :shift shift :root (%fix64-push-tail shift root (1- cnt) tail-node) :tail new-tail)))))))

(defun %vec-fix64-assoc (v index new-val)
  (declare (type %vec-fix64 v) (type fixnum index) (type fixnum new-val) (optimize (speed 3) (safety 0)))
  (let ((cnt (%fix64-count v)))
    (if (>= index (%vec-fix64-tail-off v))
        (let* ((old-tail (%fix64-tail v))
               (new-tail (make-array (length old-tail) :element-type 'fixnum)))
          (replace new-tail old-tail)
          (setf (aref new-tail (logand index +bit-mask+)) new-val)
          (%make-vec-fix64 :count cnt :shift (%fix64-shift v) :root (%fix64-root v) :tail new-tail))
        (labels ((update (node level-shift)
                         (if (= level-shift 0)
                             (let ((new-leaf (%fix64-clone-leaf (the fix64-leaf node))))
                               (setf (aref new-leaf (logand index +bit-mask+)) new-val)
                               new-leaf)
                             (let ((new-node (%clone-node (the internal-node node)))
                                   (child-idx (logand (ash index (- level-shift)) +bit-mask+)))
                               (setf (svref new-node child-idx)
                                 (update (svref (the internal-node node) child-idx)
                                         (- level-shift +bit-shift+)))
                               new-node))))
          (%make-vec-fix64 :count cnt :shift (%fix64-shift v)
                           :root (update (%fix64-root v) (%fix64-shift v))
                           :tail (%fix64-tail v))))))

(defparameter %empty-vec-fix64 (%make-vec-fix64))

(defun %make-filled-vec-fix64 (size initial-value)
  "Creates a persistent vector of SIZE filled with INITIAL-VALUE in O(N) time but O(log N) memory."
  (declare (type fixnum size) (optimize (speed 3) (safety 0)))

  ;; Base Case: The vector fits entirely within the tail array
  (if (<= size 32)
      (let ((tail (make-array size :element-type 'fixnum :initial-element initial-value)))
        (%make-vec-fix64 :count size :shift 0 :root #() :tail tail))

      ;; General Case: We need to build a tree
      (let* ((tail-len (logand size 31))
             (tree-count (- size tail-len))
             ;; 1. Allocate the Tail
             (tail (make-array tail-len :element-type 'fixnum :initial-element initial-value))
             ;; 2. The Magic: Allocate ONE leaf to represent all identical leaves
             (shared-leaf (make-array 32 :element-type 'fixnum :initial-element initial-value))
             (nodes nil))

        ;; 3. Populate the bottom layer using the exact same shared leaf pointer
        (loop repeat (ash tree-count -5) ; Equivalent to (tree-count / 32)
              do (push shared-leaf nodes))

        ;; 4. Build the internal routing nodes bottom-up
        (let ((shift 0))
          (loop while (> (length nodes) 1)
                do (let ((next-level nil)
                         (current nodes))
                     ;; Group nodes into chunks of 32
                     (loop while current
                           do (let ((internal (make-array 32 :initial-element nil)))
                                (loop for i from 0 below 32
                                      while current
                                      do (setf (svref internal i) (pop current)))
                                (push internal next-level)))
                     ;; Prepare for the next level up
                     (setf nodes (nreverse next-level))
                     (incf shift 5)))

          ;; 5. The final remaining node is the root
          (%make-vec-fix64 :count size
                           :shift shift
                           :root (car nodes)
                           :tail tail)))))

(defun %build-vec-fix64-from-list (lst)
  "Bulk-loads a list of elements into a persistent vector trie in strict O(N) time."
  (let ((count (length lst)))
    (if (<= count 32)
        ;; Base Case: Fits entirely in the tail
        (let ((tail (make-array count :initial-element nil)))
          (loop for item in lst for i from 0 do (setf (svref tail i) item))
          (%make-vec-fix64 :count count :shift 0 :root #() :tail tail))
          
        ;; General Case: Build the tree bottom-up
        (let* ((tail-len (logand count 31))
               (tree-count (- count tail-len))
               (tail (make-array tail-len :element-type fixnum :initial-element 0))
               (nodes nil)
               (current lst))
               
          ;; 1. Build all the bottom-level leaf nodes (32 elements each)
          (loop repeat (ash tree-count -5)
                do (let ((leaf (make-array 32 :element-type fixnum :initial-element 0)))
                     (loop for i from 0 below 32
                           do (setf (svref leaf i) (car current)
                                    current (cdr current)))
                     (push leaf nodes)))
          (setf nodes (nreverse nodes))

          ;; 2. Fill the tail array with the remaining elements
          (loop for i from 0 below tail-len
                do (setf (svref tail i) (car current)
                         current (cdr current)))

          ;; 3. Build the internal routing nodes bottom-up
          (let ((shift 0))
            (loop while (> (length nodes) 1)
                  do (let ((next-level nil))
                       ;; Group nodes into chunks of 32
                       (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                             do (let ((internal (make-array 32 :initial-element nil)))
                                  (loop for node in chunk for i from 0 below 32
                                        do (setf (svref internal i) node))
                                  (push internal next-level)))
                       (setf nodes (nreverse next-level))
                       (incf shift 5)))

            ;; 4. The final remaining node is our root
            (%make-vec-t :count count
                         :shift shift
                         :root (car nodes)
                         :tail tail))))))

;;; ------------------------------------------------------------------------------
;;; Vector storage interfaces
;;; ------------------------------------------------------------------------------

(defclass <vec-t-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-t :accessor storage)))

(defclass <vec-f32-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-f64 :accessor storage)))

(defclass <vec-f32-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-f32 :accessor storage)))

(defclass <vec-fix64-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-fix64 :accessor storage)))

;;; -----------------------------------------------------------------------------
;;; Protocol Generics
;;; -----------------------------------------------------------------------------

(defgeneric size (vec))
(defgeneric ref (vec index &optional not-found))
(defgeneric conj (vec val))
(defgeneric assoc (vec index val))
(defgeneric empty? (vec))

;;; -----------------------------------------------------------------------------
;;; Implementations for mixins
;;; -----------------------------------------------------------------------------

(defmethod size ((vec <vec-t-storage-mixin>)) (%vec-t-count (storage vec)))
(defmethod size ((vec <vec-f64-storage-mixin>)) (%vec-f64-count (storage vec)))
(defmethod size ((vec <vec-f32-storage-mixin>)) (%vec-f32-count (storage vec)))
(defmethod size ((vec <vec-fix64-storage-mixin>)) (%vec-fix64-count (storage vec)))

(defmethod ref ((vec <vec-t-storage-mixin>) index &optional not-found) (%vec-t-ref (storage vec) index not-found))
(defmethod ref ((vec <vec-f64-storage-mixin>) index &optional not-found)) (%vec-f64-ref (storage vec) index not-found))
(defmethod ref ((vec <vec-f32-storage-mixin>) index &optional not-found)) (%vec-f32-ref (storage vec) index not-found))
(defmethod ref ((vec <vec-fix64-storage-mixin>) index &optional not-found)) (%vec-fix64-ref (storage vec) index not-found))

(defmethod conj ((vec <vec-t-storage-mixin>) val) (%vec-t-conj (storage vec) val))
(defmethod conj ((vec <vec-f64-storage-mixin>) (val double-float)) (%vec-f64-conj (storage vec) val))
(defmethod conj ((vec <vec-f32-storage-mixin>) (val single-float)) (%vec-f32-conj (storage vec) val))
(defmethod conj ((vec <vec-fix64-storage-mixin>) (val fixnum)) (%vec-fix64-conj (storage vec) val))

(defmethod assoc ((vec <vec-t-storage-mixin>) (index integer) val) (%vec-t-assoc (storage vec) index val))
(defmethod assoc ((vec <vec-f64-storage-mixin>) (index integer) (val double-float)) (%vec-f64-assoc (storage vec) index val))
(defmethod assoc ((vec <vec-f32-storage-mixin>) (index integer) (val single-float)) (%vec-f32-assoc (storage vec) index val))
(defmethod assoc ((vec <vec-fix64-storage-mixin>) (index integer) (val fixnum)) (%vec-fix64-assoc (storage vec) index val))

(defmethod empty? ((vec <vec-t-storage-mixin>)) (zerop (%vec-t-count (storage vec))))
(defmethod empty? ((vec <vec-f64-storage-mixin>)) (zerop (%vec-f64-count (storage vec))))
(defmethod empty? ((vec <vec-f32-storage-mixin>)) (zerop (%vec-f32-count (storage vec))))
(defmethod empty? ((vec <vec-fix64-storage-mixin>)) (zerop (%vec-fix64-count (storage vec))))


;;; ---------------------------------------------------------------------------
;;; HAMT for dicts, sets, etc.
;;; ---------------------------------------------------------------------------

;;; ----------------------------------------------------------------------------
;;; Core Types
;;; ----------------------------------------------------------------------------

(defstruct (hamt (:constructor %make-hamt))
  (count 0 :type fixnum)
  (root nil))

(defstruct (hamt-node (:constructor %make-hamt-node))
  (bitmap 0 :type (unsigned-byte 32))
  (children #() :type simple-vector))

(defstruct (hamt-leaf (:constructor %make-hamt-leaf))
  (hash 0 :type fixnum)
  key value)

(defstruct (hamt-collision (:constructor %make-hamt-collision))
  (hash 0 :type fixnum)
  (leaves nil :type list)) ; A list of hamt-leaves that share the exact same hash

;;; ----------------------------------------------------------------------------
;;; Array & Bitmask Helpers
;;; ----------------------------------------------------------------------------

(declaim (inline hamt-index clone-and-insert clone-and-update clone-and-remove))

(defun hamt-index (bitmap bit-mask)
  "Calculates the exact index in the compressed array using hardware POPCNT."
  (logcount (logand bitmap (1- bit-mask))))

(defun clone-and-insert (arr idx item)
  (declare (type simple-vector arr) (type fixnum idx)
           (optimize (speed 3) (safety 0)))
  (let* ((len (length arr))
         (new-arr (make-array (1+ len))))
    (replace new-arr arr :end1 idx :end2 idx)
    (setf (svref new-arr idx) item)
    (replace new-arr arr :start1 (1+ idx) :start2 idx)
    new-arr))

(defun clone-and-update (arr idx item)
  (declare (type simple-vector arr) (type fixnum idx)
           (optimize (speed 3) (safety 0)))
  (let* ((len (length arr))
         (new-arr (make-array len)))
    (replace new-arr arr)
    (setf (svref new-arr idx) item)
    new-arr))

(defun clone-and-remove (arr idx)
  (declare (type simple-vector arr) (type fixnum idx)
           (optimize (speed 3) (safety 0)))
  (let* ((len (length arr))
         (new-arr (make-array (1- len))))
    (replace new-arr arr :end1 idx :end2 idx)
    (replace new-arr arr :start1 idx :start2 (1+ idx))
    new-arr))

(defun merge-leaves (shift leaf1 leaf2)
  "Resolves a hash collision by pushing leaves deeper, or creating a collision node."
  (let ((h1 (hamt-leaf-hash leaf1))
        (h2 (hamt-leaf-hash leaf2)))
    (if (= h1 h2)
        ;; The hashes are completely identical. Create a collision bucket.
        (%make-hamt-collision :hash h1 :leaves (list leaf1 leaf2))

        ;; The hashes differ, but collided at the previous bit chunk. Push them deeper.
        (let* ((chunk1 (logand (ash h1 (- shift)) +bit-mask+))
               (chunk2 (logand (ash h2 (- shift)) +bit-mask+)))
          (if (= chunk1 chunk2)
              ;; Still colliding at this depth! Recurse.
              (let ((child (merge-leaves (+ shift +bit-shift+) leaf1 leaf2)))
                (%make-hamt-node :bitmap (ash 1 chunk1) :children (vector child)))
              ;; They finally diverged. Place them in a new node.
              (let* ((bit1 (ash 1 chunk1))
                     (bit2 (ash 1 chunk2))
                     (bitmap (logior bit1 bit2))
                     (children (if (< chunk1 chunk2)
                                   (vector leaf1 leaf2)
                                   (vector leaf2 leaf1))))
                (%make-hamt-node :bitmap bitmap :children children)))))))

(defun assoc-node (node shift hash key value)
  "Returns (VALUES NEW-NODE ADDED-P)."
  (if (null node)
      (values (%make-hamt-leaf :hash hash :key key :value value) t)

      (cond
       ((hamt-leaf-p node)
         (if (equal (hamt-leaf-key node) key)
             (values (%make-hamt-leaf :hash hash :key key :value value) nil) ; Update
             (values (merge-leaves shift node (%make-hamt-leaf :hash hash :key key :value value)) t))) ; Collision

       ((hamt-collision-p node)
         (let* ((leaves (hamt-collision-leaves node))
                (existing (find key leaves :key #'hamt-leaf-key :test #'equal)))
           (if existing
               (let ((new-leaves (substitute (%make-hamt-leaf :hash hash :key key :value value) existing leaves)))
                 (values (%make-hamt-collision :hash hash :leaves new-leaves) nil))
               (values (%make-hamt-collision :hash hash :leaves
                                             (cons (%make-hamt-leaf :hash hash :key key :value value) leaves)) t))))

       ((hamt-node-p node)
         (let* ((chunk (logand (ash hash (- shift)) +bit-mask+))
                (bit (ash 1 chunk))
                (bitmap (hamt-node-bitmap node))
                (idx (hamt-index bitmap bit))
                (children (hamt-node-children node)))

           (if (zerop (logand bitmap bit))
               ;; The branch doesn't exist. Add it!
               (values (%make-hamt-node :bitmap (logior bitmap bit)
                                        :children (clone-and-insert children idx (%make-hamt-leaf :hash hash :key key :value value)))
                 t)
               ;; The branch exists. Recurse.
               (multiple-value-bind (new-child added-p)
                   (assoc-node (svref children idx) (+ shift +bit-shift+) hash key value)
                 (values (%make-hamt-node :bitmap bitmap
                                          :children (clone-and-update children idx new-child))
                   added-p))))))))

(defun dissoc-node (node shift hash key)
  "Returns (VALUES NEW-NODE REMOVED-P)."
  (cond
   ((null node)
     (values nil nil))

   ((hamt-leaf-p node)
     (if (equal (hamt-leaf-key node) key)
         (values nil t) ; It's gone!
         (values node nil)))

   ((hamt-collision-p node)
     (let* ((leaves (hamt-collision-leaves node))
            (existing (find key leaves :key #'hamt-leaf-key :test #'equal)))
       (if existing
           (let ((new-leaves (remove existing leaves)))
             (if (= (length new-leaves) 1)
                 ;; Shrink the collision node back into a single normal leaf
                 (values (car new-leaves) t)
                 (values (%make-hamt-collision :hash hash :leaves new-leaves) t)))
           (values node nil))))

   ((hamt-node-p node)
     (let* ((chunk (logand (ash hash (- shift)) +bit-mask+))
            (bit (ash 1 chunk))
            (bitmap (hamt-node-bitmap node)))

       (if (zerop (logand bitmap bit))
           (values node nil) ; Key doesn't exist

           (let* ((idx (hamt-index bitmap bit))
                  (children (hamt-node-children node)))
             (multiple-value-bind (new-child removed-p)
                 (dissoc-node (svref children idx) (+ shift +bit-shift+) hash key)
               (if (not removed-p)
                   (values node nil)

                   (if (null new-child)
                       ;; The child was completely removed. Shrink this node!
                       (let ((new-bitmap (logandc2 bitmap bit)))
                         (if (zerop new-bitmap)
                             (values nil t) ; This node is now completely empty
                             ;; Path Compression: If only 1 child is left, and it's a leaf, dissolve the node.
                             (let ((new-children (clone-and-remove children idx)))
                               (if (and (= (length new-children) 1) (hamt-leaf-p (svref new-children 0)))
                                   (values (svref new-children 0) t)
                                   (values (%make-hamt-node :bitmap new-bitmap :children new-children) t)))))
                       ;; The child was updated.
                       (values (%make-hamt-node :bitmap bitmap
                                                :children (clone-and-update children idx new-child))
                         t))))))))))

(defun hamt-iterator (hamt)
  "Returns a closure that lazily yields (key . value) pairs one at a time, or :eof."
  (let ((stack (if (hamt-root hamt) (list (hamt-root hamt)) nil)))
    (lambda ()
      (loop
       (if (null stack)
           (return :eof)
           (let ((node (pop stack)))
             (cond
              ;; 1. It's a leaf: yield the pair and suspend.
              ((hamt-leaf-p node)
                (return (cons (hamt-leaf-key node) (hamt-leaf-value node))))

              ;; 2. It's a collision: push all leaves to the stack and loop.
              ((hamt-collision-p node)
                (setf stack (append (hamt-collision-leaves node) stack)))

              ;; 3. It's an internal branch: push children to the stack.
              ;; We push them in reverse order so they pop off left-to-right.
              ((hamt-node-p node)
                (let ((children (hamt-node-children node)))
                  (loop for i from (1- (length children)) downto 0
                        do (push (svref children i) stack)))))))))))

(defun hamt->lazy-seq (hamt)
  "Wraps a HAMT iterator into a fol.compiler.collections:<lazy-seq>."
  (let ((iter (hamt-iterator hamt)))

    (labels ((build-lazy-chain (remaining-size)
                               (if (<= remaining-size 0)
                                   nil

                                   ;; Return an unresolved lazy sequence...
                                   (make-instance 'fol.compiler.collections::<lazy-seq>
                                     :thunk (lambda ()
                                              (let ((val (funcall iter)))
                                                (if (eq val :eof)
                                                    nil
                                                    ;; ...which resolves into a strictly sized <list> node
                                                    ;; where the tail is the next lazy promise.
                                                    (make-instance 'fol.compiler.collections::<list>
                                                      :first-elem val
                                                      :rest-list (build-lazy-chain (1- remaining-size))
                                                      :list-size remaining-size))))))))

      (build-lazy-chain (hamt-count hamt)))))

(defun hamt-empty ()
  (%make-hamt :count 0 :root nil))

(defun hamt-empty? (h)
  (zerop (hamt-count h)))

(defun hamt-size (h)
  (hamt-count h))

(defun hamt-assoc (h key value)
  (let ((hash (sxhash key)))
    (multiple-value-bind (new-root added-p) (assoc-node (hamt-root h) 0 hash key value)
      (%make-hamt :count (if added-p (1+ (hamt-count h)) (hamt-count h))
                  :root new-root))))

(defun hamt-dissoc (h key)
  (let ((hash (sxhash key)))
    (multiple-value-bind (new-root removed-p) (dissoc-node (hamt-root h) 0 hash key)
      (if removed-p
          (%make-hamt :count (1- (hamt-count h)) :root new-root)
          h)))) ; Return unmodified structure if key wasn't found

(defun hamt-seq (h)
  (hamt->lazy-seq h))