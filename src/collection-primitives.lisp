(in-package :fol.compiler.collection-primitives)


(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +branch-factor+ 32)
  (defconstant +bit-mask+ 31)
  (defconstant +bit-shift+ 5))

(deftype internal-node () `(simple-vector ,+branch-factor+))

;;; ============================================================================
;;; Shared Utility Functions
;;; ============================================================================

(declaim (inline %clone-node))
(defun %clone-node (node)
  (declare (type internal-node node) (optimize (speed 3) (safety 0)))
  (copy-seq node))

(defun %column-major-idx (dimensions indices)
  "Computes a linear index into a vector from array dimensions and indices.
   Uses column-major indexing: index = i0 + i1*d0 + i2*d0*d1 + ..."
  (declare (optimize (speed 3) (safety 0)))
  (let ((idx 0)
        (stride 1))
    (loop for i fixnum from 0 below (length indices)
          for dim fixnum = (aref dimensions i)
          for index fixnum = (aref indices i)
          do (progn
              (incf idx (* index stride))
              (setf stride (* stride dim))))
    idx))

;;; ============================================================================
;;; %vec-f64 Implementation
;;; ============================================================================


(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %pvec-mk-sym (fmt &rest args)
    (intern (apply #'format nil fmt (mapcar #'string args)))))

(defmacro define-pvec-trie (name conc-name leaf-type element-type fallback-val accessor)
  (let* ((make-name (%pvec-mk-sym "%MAKE-~A" (subseq (string name) 1)))
         (pred-name (%pvec-mk-sym "~A?" name))
         (count-acc (%pvec-mk-sym "~ACOUNT" conc-name))
         (shift-acc (%pvec-mk-sym "~ASHIFT" conc-name))
         (root-acc (%pvec-mk-sym "~AROOT" conc-name))
         (tail-acc (%pvec-mk-sym "~ATAIL" conc-name))

         (api-count (%pvec-mk-sym "~A-COUNT" name))
         (api-tail-off (%pvec-mk-sym "~A-TAIL-OFF" name))
         (api-ref (%pvec-mk-sym "~A-REF" name))
         (api-conj (%pvec-mk-sym "~A-CONJ" name))
         (api-assoc (%pvec-mk-sym "~A-ASSOC" name))

         (empty-vec (%pvec-mk-sym "%EMPTY-~A" (subseq (string name) 1)))
         (make-filled (%pvec-mk-sym "%MAKE-FILLED-~A" (subseq (string name) 1)))
         (build-vec (%pvec-mk-sym "%BUILD-~A-FROM-LIST" (subseq (string name) 1)))
         (build-vec-v (%pvec-mk-sym "%BUILD-~A-FROM-VECTOR" (subseq (string name) 1)))

         (clone-leaf (%pvec-mk-sym "~ACLONE-LEAF" conc-name))
         (new-path (%pvec-mk-sym "~ANEW-PATH" conc-name))
         (trans-name (%pvec-mk-sym "TRANSIENT-~A" name))
         (make-trans (%pvec-mk-sym "MAKE-TRANSIENT-~A" name))
         (trans-name-p (%pvec-mk-sym "TRANSIENT-~A-P" name))
         (trans-conc (%pvec-mk-sym "TRANS-~A-" name))
         (trans-count (%pvec-mk-sym "TRANS-~A-COUNT" name))
         (trans-shift (%pvec-mk-sym "TRANS-~A-SHIFT" name))
         (trans-root (%pvec-mk-sym "TRANS-~A-ROOT" name))
         (trans-tail (%pvec-mk-sym "TRANS-~A-TAIL" name))
         (trans-token (%pvec-mk-sym "TRANS-~A-TOKEN" name))

         (api-transient (%pvec-mk-sym "TRANSIENT-~A" name))
         (api-transient-conj (%pvec-mk-sym "TRANSIENT-~A-CONJ!" name))
         (api-transient-assoc (%pvec-mk-sym "TRANSIENT-~A-ASSOC!" name))
         (api-transient-persistent (%pvec-mk-sym "TRANSIENT-~A-PERSISTENT!" name))
         (push-tail (%pvec-mk-sym "~APUSH-TAIL" conc-name))

         (leaf-type-def (if (eq element-type 't)
                            `(simple-vector ,+branch-factor+)
                            `(simple-array ,element-type (,+branch-factor+))))
         (root-type (if (eq element-type 't)
                        'simple-vector
                        `(simple-array t (*))))
         (tail-type (if (eq element-type 't)
                        'simple-vector
                        `(simple-array ,element-type (*))))
         (make-tail-empty (if (eq element-type 't)
                              `(make-array 0)
                              `(make-array 0 :element-type ',element-type)))
         (make-tail-len (if (eq element-type 't)
                            `(make-array (1+ tail-len))
                            `(make-array (1+ tail-len) :element-type ',element-type)))
         (make-tail-1 (if (eq element-type 't)
                          `(make-array 1)
                          `(make-array 1 :element-type ',element-type)))
         (make-new-tail-len (if (eq element-type 't)
                                `(make-array (length old-tail))
                                `(make-array (length old-tail) :element-type ',element-type))))
    `(progn
      (deftype ,leaf-type () ',leaf-type-def)

      (defstruct (,name (:constructor ,make-name)
                   (:predicate ,pred-name)
                   (:conc-name ,conc-name))
        (count 0 :type fixnum)
        (shift 0 :type fixnum)
        (root #() :type ,root-type)
        (tail ,make-tail-empty :type ,tail-type))

      (defun ,api-count (v) (declare (type ,name v)) (,count-acc v))

      (defun ,api-tail-off (v)
        (declare (type ,name v) (optimize (speed 3) (safety 0)))
        (let ((cnt (,count-acc v)))
          (if (< cnt +branch-factor+) 0 (ash (ash (1- cnt) (- +bit-shift+)) +bit-shift+))))

      (defun ,api-ref (v index &optional not-found)
        (declare (type ,name v)
                 (type fixnum index)
                 (optimize (speed 3) (safety 0)))
        (let ((cnt (,count-acc v)))
          (if (or (< index 0) (>= index cnt))
              (values not-found nil)
              (if (>= index (if (< cnt 32) 0 (logand (1- cnt) -32)))
                  (values (,accessor (,tail-acc v) (logand index 31)) t)
                  (let ((node (,root-acc v))
                        (shift (,shift-acc v)))
                    (loop for level-shift fixnum from shift downto 5 by 5
                          do (setf node (svref (the simple-vector node) (logand (ash index (- level-shift)) 31))))
                    (values (,accessor (the ,leaf-type node) (logand index 31)) t))))))

      (defun ,clone-leaf (leaf)
        (declare (type ,leaf-type leaf) (optimize (speed 3) (safety 0)))
        (copy-seq leaf))

      (defun ,new-path (shift leaf)
        (if (<= shift 0) leaf
            (let ((node (make-array +branch-factor+ :initial-element nil)))
              (setf (svref node 0) (,new-path (- shift +bit-shift+) leaf))
              node)))

      (defun ,push-tail (shift node idx tail-node)
        (let ((new-node (%clone-node node))
              (sub-idx (logand (ash idx (- shift)) +bit-mask+)))
          (if (= shift +bit-shift+)
              (setf (svref new-node sub-idx) tail-node)
              (let ((child (svref node sub-idx)))
                (if child
                    (setf (svref new-node sub-idx) (,push-tail (- shift +bit-shift+) child idx tail-node))
                    (setf (svref new-node sub-idx) (,new-path (- shift +bit-shift+) tail-node)))))
          new-node))

      (defun ,api-conj (v val)
        (declare (type ,name v) ,@(when (not (eq element-type 't)) `((type ,element-type val))) (optimize (speed 3) (safety 0)))
        (let* ((cnt (,count-acc v))
               (tail (,tail-acc v))
               (tail-len (if (zerop cnt) 0 (1+ (logand (1- cnt) 31)))))
          (if (< tail-len 32)
              (let ((new-tail ,make-tail-len))
                (replace new-tail tail)
                (setf (,accessor new-tail tail-len) val)
                (,make-name :count (1+ cnt) :shift (,shift-acc v) :root (,root-acc v) :tail new-tail))
              (let* ((tail-node tail) Issue
                                     (new-tail ,make-tail-1)
                                     (root (,root-acc v))
                                     (shift (,shift-acc v)))
                (setf (,accessor new-tail 0) val)
                (cond
                 ((zerop (length root))
                   (let ((new-root (make-array 32)))
                     (setf (svref new-root 0) tail-node)
                     (,make-name :count (1+ cnt) :shift 5 :root new-root :tail new-tail)))
                 ((> (ash cnt -5) (ash 1 shift))
                   (let ((new-root (make-array 32 :initial-element nil)))
                     (setf (svref new-root 0) root)
                     (setf (svref new-root 1) (,new-path shift tail-node))
                     (,make-name :count (1+ cnt) :shift (+ shift 5) :root new-root :tail new-tail)))
                 (t (,make-name :count (1+ cnt) :shift shift :root (,push-tail shift root (1- cnt) tail-node) :tail new-tail)))))))

      (defun ,api-assoc (v index new-val)
        (declare (type ,name v) (type fixnum index) ,@(when (not (eq element-type 't)) `((type ,element-type new-val))) (optimize (speed 3) (safety 0)))
        (let ((cnt (,count-acc v)))
          (if (>= index (if (< cnt 32) 0 (logand (1- cnt) -32)))
              (let* ((old-tail (,tail-acc v))
                     (old-val (,accessor old-tail (logand index 31))))
                (if (eql old-val new-val)
                    v
                    (let ((new-tail ,make-new-tail-len))
                      (replace new-tail old-tail)
                      (setf (,accessor new-tail (logand index 31)) new-val)
                      (,make-name :count cnt :shift (,shift-acc v) :root (,root-acc v) :tail new-tail))))
              (labels ((update (node level-shift)
                               (if (= level-shift 0)
                                   (if (eql (,accessor node (logand index 31)) new-val)
                                       node
                                       (let ((new-leaf (,clone-leaf node)))
                                         (setf (,accessor new-leaf (logand index 31)) new-val)
                                         new-leaf))
                                   (let* ((child-idx (logand (ash index (- level-shift)) 31))
                                          (child (svref node child-idx))
                                          (new-child (update child (- level-shift 5))))
                                     (if (eq new-child child)
                                         node
                                         (let ((new-node (%clone-node node)))
                                           (setf (svref new-node child-idx) new-child)
                                           new-node))))))
                (let ((new-root (update (,root-acc v) (,shift-acc v))))
                  (if (eq new-root (,root-acc v))
                      v
                      (,make-name :count cnt :shift (,shift-acc v)
                        :root new-root
                        :tail (,tail-acc v))))))))

      (defstruct (,trans-name (:constructor ,make-trans)
                   (:predicate ,trans-name-p)
                   (:conc-name ,trans-conc))
        (count 0 :type fixnum)
        (shift 0 :type fixnum)
        (root #() :type ,root-type)
        (tail ,make-tail-empty :type ,tail-type)
        (token nil))

      (defun ,api-transient (v)
        (let* ((token (bt:current-thread))
               (cnt (,count-acc v))
               (persistent-tail (,tail-acc v))
               (tail (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)))))
          (replace tail persistent-tail)
          (,make-trans :count cnt
            :shift (,shift-acc v)
            :root (,root-acc v)
            :tail tail
            :token token)))

      (defun ,api-transient-conj (tv val)
        (declare ,@(when (not (eq element-type 't)) `((type ,element-type val))) (optimize (speed 3) (safety 0)))
        (unless (eq (,trans-token tv) (bt:current-thread))
          (error "Transient used in different thread or after persistent! call"))
        (let* ((cnt (,trans-count tv)))
          (when (and (> cnt 0) (zerop (logand cnt 31)))
                (let ((root (,trans-root tv))
                      (shift (,trans-shift tv))
                      (node-to-push (,trans-tail tv)))
                  (let ((new-tail (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)))))
                    (setf (,trans-tail tv) new-tail))
                  (cond
                   ((zerop (length root))
                     (let ((new-root (make-array +branch-factor+)))
                       (setf (svref new-root 0) node-to-push)
                       (setf (,trans-root tv) new-root)
                       (setf (,trans-shift tv) +bit-shift+)))
                   ((> (ash cnt (- +bit-shift+)) (ash 1 shift))
                     (let ((new-root (make-array +branch-factor+ :initial-element nil)))
                       (setf (svref new-root 0) root)
                       (setf (svref new-root 1) (,new-path shift node-to-push))
                       (setf (,trans-root tv) new-root)
                       (setf (,trans-shift tv) (+ shift +bit-shift+))))
                   (t
                     (setf (,trans-root tv) (,push-tail shift root (1- cnt) node-to-push))))))
          (let ((tail-idx (logand cnt 31)))
            (setf (,accessor (,trans-tail tv) tail-idx) val)
            (incf (,trans-count tv))
            tv)))

      (defun ,api-transient-assoc (tv index new-val)
        "In-place index-set on a transient trie. The tail is always a
         freshly-allocated array private to this transient (API-TRANSIENT
         copies it, line above), so an index landing there is mutated
         directly. An index landing in the tree is updated by cloning only
         the spine down to the target leaf -- the same discipline
         API-TRANSIENT-CONJ's own tree-growth path already uses (PUSH-TAIL/
         NEW-PATH clone rather than mutate), since interior nodes may still
         be shared with the persistent structure this transient started
         from or with other outstanding references; only the tail is
         exclusively owned."
        (declare (type fixnum index) ,@(when (not (eq element-type 't)) `((type ,element-type new-val))) (optimize (speed 3) (safety 0)))
        (unless (eq (,trans-token tv) (bt:current-thread))
          (error "Transient used in different thread or after persistent! call"))
        (let ((cnt (,trans-count tv)))
          (when (or (< index 0) (>= index cnt))
            (error "Index ~D out of bounds for transient vector of count ~D" index cnt))
          (if (>= index (if (< cnt 32) 0 (logand (1- cnt) -32)))
              (progn
                (setf (,accessor (,trans-tail tv) (logand index 31)) new-val)
                tv)
              (labels ((update (node level-shift)
                         (if (= level-shift 0)
                             (if (eql (,accessor node (logand index 31)) new-val)
                                 node
                                 (let ((new-leaf (,clone-leaf node)))
                                   (setf (,accessor new-leaf (logand index 31)) new-val)
                                   new-leaf))
                             (let* ((child-idx (logand (ash index (- level-shift)) 31))
                                    (child (svref node child-idx))
                                    (new-child (update child (- level-shift 5))))
                               (if (eq new-child child)
                                   node
                                   (let ((new-node (%clone-node node)))
                                     (setf (svref new-node child-idx) new-child)
                                     new-node))))))
                (setf (,trans-root tv) (update (,trans-root tv) (,trans-shift tv)))
                tv))))

      (defun ,api-transient-persistent (tv)
        (unless (eq (,trans-token tv) (bt:current-thread))
          (error "Transient used in different thread or after persistent! call"))
        (setf (,trans-token tv) nil)
        (let* ((cnt (,trans-count tv))
               (tail (,trans-tail tv))
               (real-tail-len (if (zerop cnt) 0 (1+ (logand (1- cnt) 31))))
               (frozen-tail (make-array real-tail-len ,@(when (not (eq element-type 't)) `(:element-type ',element-type)))))
          (replace frozen-tail tail :end1 real-tail-len :end2 real-tail-len)
          (,make-name :count cnt
            :shift (,trans-shift tv)
            :root (,trans-root tv)
            :tail frozen-tail)))

      (defparameter ,empty-vec (,make-name))

      (defun ,make-filled (size initial-value)
        (declare (type fixnum size) (optimize (speed 3) (safety 0)))
        (if (<= size 32)
            (let ((tail (make-array size ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element initial-value)))
              (,make-name :count size :shift 0 :root #() :tail tail))
            (let* ((tree-count (if (< size 32) 0 (ash (ash (1- size) -5) 5)))
                   (tail-len (- size tree-count))
                   (tail (make-array tail-len ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element initial-value))
                   (shared-leaf (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element initial-value))
                   (nodes nil))
              (loop repeat (ash tree-count -5) do (push shared-leaf nodes))
              (let ((shift 0))
                (loop while (> (length nodes) 1)
                      do (let ((next-level nil) (current nodes))
                           (loop while current
                                 do (let ((internal (make-array 32 :initial-element nil)))
                                      (loop for i from 0 below 32 while current
                                            do (setf (svref internal i) (pop current)))
                                      (push internal next-level)))
                           (setf nodes (nreverse next-level))
                           (incf shift 5)))
                (,make-name :count size :shift shift :root (car nodes) :tail tail)))))

      (defun ,build-vec (lst)
        (let ((count (length lst)))
          (if (<= count 32)
              (let ((tail (make-array count ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element ,fallback-val)))
                (loop for item in lst for i from 0 do (setf (,accessor tail i) item))
                (,make-name :count count :shift 0 :root #() :tail tail))
              (let* ((tree-count (if (< count 32) 0 (ash (ash (1- count) -5) 5)))
                     (tail-len (- count tree-count))
                     (tail (make-array tail-len ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element ,fallback-val))
                     (nodes nil)
                     (current lst))
                (loop repeat (ash tree-count -5)
                      do (let ((leaf (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element ,fallback-val)))
                           (loop for i from 0 below 32
                                 do (setf (,accessor leaf i) (car current)
                                      current (cdr current)))
                           (push leaf nodes)))
                (setf nodes (nreverse nodes))
                (loop for i from 0 below tail-len
                      do (setf (,accessor tail i) (car current)
                           current (cdr current)))
                (let ((shift 0))
                  (loop while (> (length nodes) 1)
                        do (let ((next-level nil))
                             (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                                   do (let ((internal (make-array 32 :initial-element nil)))
                                        (loop for node in chunk for i from 0 below 32
                                              do (setf (svref internal i) node))
                                        (push internal next-level)))
                             (setf nodes (nreverse next-level))
                             (incf shift 5)))
                  (,make-name :count count :shift shift :root (car nodes) :tail tail))))))

      (defun ,build-vec-v (vec)
        (let ((count (length vec)))
          (if (<= count 32)
              (let ((tail (make-array count ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element ,fallback-val)))
                (loop for i from 0 below count do (setf (,accessor tail i) (aref vec i)))
                (,make-name :count count :shift 0 :root #() :tail tail))
              (let* ((tree-count (if (< count 32) 0 (ash (ash (1- count) -5) 5)))
                     (tail-len (- count tree-count))
                     (tail (make-array tail-len ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element ,fallback-val))
                     (nodes nil))
                (loop for leaf-idx from 0 below (ash tree-count -5)
                      do (let ((leaf (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)) :initial-element ,fallback-val)))
                           (loop for i from 0 below 32
                                 do (setf (,accessor leaf i) (aref vec (+ (* leaf-idx 32) i))))
                           (push leaf nodes)))
                (setf nodes (nreverse nodes))
                (loop for i from 0 below tail-len
                      do (setf (,accessor tail i) (aref vec (+ tree-count i))))
                (let ((shift 0))
                  (loop while (> (length nodes) 1)
                        do (let ((next-level nil))
                             (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                                   do (let ((internal (make-array 32 :initial-element nil)))
                                        (loop for node in chunk for i from 0 below 32
                                              do (setf (svref internal i) node))
                                        (push internal next-level)))
                             (setf nodes (nreverse next-level))
                             (incf shift 5)))
                  (,make-name :count count :shift shift :root (car nodes) :tail tail)))))))))

(define-pvec-trie %vec-f64 %f64- f64-leaf double-float 0.0d0 aref)


;;; ============================================================================
;;; %vec-f32 Implementation
;;; ============================================================================

(define-pvec-trie %vec-f32 %f32- f32-leaf single-float 0.0f0 aref)

;;; ============================================================================
;;; %vec-t Implementation
;;; ============================================================================

(define-pvec-trie %vec-t %t- t-leaf t nil svref)

(defun %vec-t-iterator (v)
  "Returns a closure that lazily yields elements from the vector one at a time, or :eof."
  (declare (type %vec-t v) (optimize (speed 3) (safety 0)))
  (let* ((count (%t-count v))
         (tail-off (%vec-t-tail-off v))
         (shift (%t-shift v))
         (root (%t-root v))
         (tail (%t-tail v))
         (index 0)
         (current-leaf nil))
    (declare (type fixnum count tail-off shift index))

    ;; 1. Initialize the very first leaf before we return the closure
    (setf current-leaf
      (if (zerop count)
          #()
          (if (>= 0 tail-off)
              tail
              (let ((node root))
                (loop for level-shift from shift downto 5 by 5
                      do (setf node (svref node 0)))
                node))))

    ;; 2. Return the generator closure
    (lambda ()
      (if (>= index count)
          :eof
          (let* ((idx-in-leaf (logand index 31))
                 (val (svref current-leaf idx-in-leaf)))

            (incf index)

            ;; 3. If we just finished a 32-element chunk, fetch the NEXT leaf into the cache
            (when (and (< index count) (zerop (logand index 31)))
                  (setf current-leaf
                    (if (>= index tail-off)
                        tail
                        ;; Standard tree traversal for the specific boundary index
                        (let ((node root))
                          (loop for level-shift from shift downto 5 by 5
                                do (setf node (svref (the simple-vector node)
                                                     (logand (ash index (- level-shift)) 31))))
                          node))))
            val)))))

(defun vec->lazy-seq (vec)
  "Wraps a vector generator into a fol.compiler.collections:<lazy-seq>."
  (let* ((storage-vec (storage vec))
         (iter (fol.compiler.collection-primitives::%vec-t-iterator storage-vec))
         (total-size (fol.compiler.collection-primitives::%vec-t-count storage-vec)))

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
                                                    (make-instance 'fol.compiler.collections::<list>
                                                      :first-elem val
                                                      :rest-list (build-lazy-chain (1- remaining-size))
                                                      :list-size remaining-size))))))))

      (build-lazy-chain total-size))))

;;; ============================================================================
;;; %vec-fix64 Implementation
;;; ============================================================================

(define-pvec-trie %vec-fix64 %fix64- fix64-leaf fixnum 0 aref)

;;; ------------------------------------------------------------------------------
;;; Vector storage interfaces
;;; ------------------------------------------------------------------------------

(defclass <vec-t-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-t :accessor storage)))

(defclass <vec-f64-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-f64 :accessor storage)))

(defclass <vec-f32-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-f32 :accessor storage)))

(defclass <vec-fix64-storage-mixin> () ((storage :initarg :storage :initform %empty-vec-fix64 :accessor storage)))


(defgeneric storage-items (coll)
  (:documentation "Returns the underlying storage object for a collection."))

(defmethod storage-items ((coll <vec-t-storage-mixin>)) (storage coll))
(defmethod storage-items ((coll <vec-f64-storage-mixin>)) (storage coll))
(defmethod storage-items ((coll <vec-f32-storage-mixin>)) (storage coll))
(defmethod storage-items ((coll <vec-fix64-storage-mixin>)) (storage coll))

;;; -----------------------------------------------------------------------------
;;; Protocol Generics
;;; -----------------------------------------------------------------------------

(defgeneric size (coll))
(defgeneric ref (coll index &optional not-found))
(defgeneric conj (coll val))
(defgeneric assoc (coll index val))
(defgeneric empty? (coll))
(defgeneric seq (coll))

;;; -----------------------------------------------------------------------------
;;; Implementations for mixins
;;; -----------------------------------------------------------------------------

(defmethod size ((vec <vec-t-storage-mixin>)) (%vec-t-count (storage vec)))
(defmethod size ((vec <vec-f64-storage-mixin>)) (%vec-f64-count (storage vec)))
(defmethod size ((vec <vec-f32-storage-mixin>)) (%vec-f32-count (storage vec)))
(defmethod size ((vec <vec-fix64-storage-mixin>)) (%vec-fix64-count (storage vec)))

(defmethod ref ((vec <vec-t-storage-mixin>) index &optional not-found) (%vec-t-ref (storage vec) index not-found))
(defmethod ref ((vec <vec-f64-storage-mixin>) index &optional not-found) (%vec-f64-ref (storage vec) index not-found))
(defmethod ref ((vec <vec-f32-storage-mixin>) index &optional not-found) (%vec-f32-ref (storage vec) index not-found))
(defmethod ref ((vec <vec-fix64-storage-mixin>) index &optional not-found) (%vec-fix64-ref (storage vec) index not-found))

(defmethod conj ((vec <vec-t-storage-mixin>) val)
  (let ((new-storage (%vec-t-conj (storage vec) val)))
    (make-instance (class-of vec) :storage new-storage)))
(defmethod conj ((vec <vec-f64-storage-mixin>) (val double-float))
  (let ((new-storage (%vec-f64-conj (storage vec) val)))
    (make-instance (class-of vec) :storage new-storage)))
(defmethod conj ((vec <vec-f32-storage-mixin>) (val single-float))
  (let ((new-storage (%vec-f32-conj (storage vec) val)))
    (make-instance (class-of vec) :storage new-storage)))
(defmethod conj ((vec <vec-fix64-storage-mixin>) (val fixnum))
  (let ((new-storage (%vec-fix64-conj (storage vec) val)))
    (make-instance (class-of vec) :storage new-storage)))

(defmethod assoc ((vec <vec-t-storage-mixin>) (index integer) val)
  (let ((new-storage (%vec-t-assoc (storage vec) index val)))
    (make-instance (class-of vec) :storage new-storage)))
(defmethod assoc ((vec <vec-f64-storage-mixin>) (index integer) (val double-float))
  (let ((new-storage (%vec-f64-assoc (storage vec) index val)))
    (make-instance (class-of vec) :storage new-storage)))
(defmethod assoc ((vec <vec-f32-storage-mixin>) (index integer) (val single-float))
  (let ((new-storage (%vec-f32-assoc (storage vec) index val)))
    (make-instance (class-of vec) :storage new-storage)))
(defmethod assoc ((vec <vec-fix64-storage-mixin>) (index integer) (val fixnum))
  (let ((new-storage (%vec-fix64-assoc (storage vec) index val)))
    (make-instance (class-of vec) :storage new-storage)))

(defmethod empty? ((vec <vec-t-storage-mixin>)) (zerop (%vec-t-count (storage vec))))
(defmethod empty? ((vec <vec-f64-storage-mixin>)) (zerop (%vec-f64-count (storage vec))))
(defmethod empty? ((vec <vec-f32-storage-mixin>)) (zerop (%vec-f32-count (storage vec))))
(defmethod empty? ((vec <vec-fix64-storage-mixin>)) (zerop (%vec-fix64-count (storage vec))))

(defmethod seq ((vec <vec-t-storage-mixin>)) (vec->lazy-seq vec))
(defmethod seq ((vec <vec-f64-storage-mixin>)) (vec->lazy-seq vec))
(defmethod seq ((vec <vec-f32-storage-mixin>)) (vec->lazy-seq vec))
(defmethod seq ((vec <vec-fix64-storage-mixin>)) (vec->lazy-seq vec))


;;; ---------------------------------------------------------------------------
;;; HAMT for regular dicts, sets, etc.
;;; ---------------------------------------------------------------------------

;;; ----------------------------------------------------------------------------
;;; Core Types
;;; ----------------------------------------------------------------------------

(defstruct (hamt (:constructor %make-hamt))
  (count 0 :type fixnum)
  (root nil))

(defstruct (transient-hamt (:constructor %make-transient-hamt))
  (count 0 :type fixnum)
  (root nil)
  (token nil))

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

(defun find-node (node shift hash key not-found)
  "Traverses the HAMT to find the key. Returns (VALUES value found-p)."
  (declare (type fixnum shift hash)
           (optimize (speed 3) (safety 0)))
  (cond
   ;; Base Case 1: Empty branch. The key does not exist.
   ((null node)
     (values not-found nil))

   ;; Base Case 2: We hit a leaf. Verify the key matches exactly.
   ((hamt-leaf-p node)
     (if (equal (hamt-leaf-key node) key) ; Use your language's generic equality here
         (values (hamt-leaf-value node) t)
         (values not-found nil)))

   ;; Base Case 3: We hit a hash collision bucket. Search the list.
   ((hamt-collision-p node)
     (let ((leaf (find key (hamt-collision-leaves node)
                   :key #'hamt-leaf-key
                   :test #'equal)))
       (if leaf
           (values (hamt-leaf-value leaf) t)
           (values not-found nil))))

   ;; Recursive Case: Internal routing node.
   ((hamt-node-p node)
     (let* ((chunk (logand (ash hash (- shift)) +bit-mask+))
            (bit (ash 1 chunk))
            (bitmap (hamt-node-bitmap node)))

       ;; Check if the bit for this chunk is flipped on
       (if (zerop (logand bitmap bit))
           ;; The bit is 0. The path dead-ends here.
           (values not-found nil)

           ;; The bit is 1. Calculate the actual array index and recurse.
           (let* ((idx (hamt-index bitmap bit))
                  (children (hamt-node-children node)))
             (find-node (svref children idx)
                        (+ shift +bit-shift+)
                        hash key not-found)))))))

(defun hamt-get (h key &optional not-found)
  "Retrieves the value mapped to KEY in the HAMT. 
   Returns two values: (VALUES value found-p)."
  (let ((hash (sxhash key)))
    (find-node (hamt-root h) 0 hash key not-found)))

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

(defun insert-destructive (arr idx item)
  "Allocates a larger array, but doesn't bother cloning if we don't need to preserve the old one."
  (declare (type simple-vector arr) (type fixnum idx)
           (optimize (speed 3) (safety 0)))
  (let* ((len (length arr))
         (new-arr (make-array (1+ len))))
    (replace new-arr arr :end1 idx :end2 idx)
    (setf (svref new-arr idx) item)
    (replace new-arr arr :start1 (1+ idx) :start2 idx)
    new-arr))

(defun update-destructive (arr idx item)
  "Mutates the array IN-PLACE. Only safe for transient-owned nodes!"
  (declare (type simple-vector arr) (type fixnum idx)
           (optimize (speed 3) (safety 0)))
  (setf (svref arr idx) item)
  arr)

;; An internal marker to track ownership
(defstruct hamt-transient-node
  (token nil)
  (bitmap 0 :type (unsigned-byte 32))
  (children #() :type simple-vector))

(defun ensure-editable-hamt-node (node token)
  "Returns the node if we own it, otherwise clones it and claims it."
  (if (and (hamt-transient-node-p node) (eq (hamt-transient-node-token node) token))
      node
      (make-hamt-transient-node :token token
                                :bitmap (hamt-node-bitmap node)
                                :children (copy-seq (hamt-node-children node)))))

(defun assoc-node! (node shift hash key value token)
  (if (null node)
      (values (%make-hamt-leaf :hash hash :key key :value value) t)

      (cond
       ((hamt-leaf-p node)
         (if (equal (hamt-leaf-key node) key)
             (values (%make-hamt-leaf :hash hash :key key :value value) nil)
             (values (merge-leaves shift node (%make-hamt-leaf :hash hash :key key :value value)) t)))

       ;; Transient internal node logic
       (t
         (let* ((editable-node (ensure-editable-hamt-node node token))
                (chunk (logand (ash hash (- shift)) 31))
                (bit (ash 1 chunk))
                (bitmap (hamt-transient-node-bitmap editable-node))
                (idx (logcount (logand bitmap (1- bit))))
                (children (hamt-transient-node-children editable-node)))

           (if (zerop (logand bitmap bit))
               ;; Slot is empty: We MUST allocate a new array to grow, but we update the node.
               (progn
                (setf (hamt-transient-node-bitmap editable-node) (logior bitmap bit))
                (setf (hamt-transient-node-children editable-node)
                  (insert-destructive children idx (%make-hamt-leaf :hash hash :key key :value value)))
                (values editable-node t))

               ;; Slot is occupied: Recurse!
               (multiple-value-bind (new-child added-p)
                   (assoc-node! (svref children idx) (+ shift 5) hash key value token)
                 ;; Mutate the children array IN-PLACE
                 (setf (hamt-transient-node-children editable-node)
                   (update-destructive children idx new-child))
                 (values editable-node added-p))))))))

(defun remove-destructive (arr idx)
  (let ((new-arr (make-array (1- (length arr)))))
    (replace new-arr arr :end2 idx)
    (replace new-arr arr :start1 idx :start2 (1+ idx))
    new-arr))

(defun dissoc-node! (node shift hash key token)
  (cond
   ((null node) (values nil nil))
   ((hamt-leaf-p node)
     (if (equal (hamt-leaf-key node) key)
         (values nil t)
         (values node nil)))
   ((hamt-collision-p node)
     (let* ((leaves (hamt-collision-leaves node))
            (existing (find key leaves :key #'hamt-leaf-key :test #'equal)))
       (if existing
           (let ((new-leaves (remove existing leaves)))
             (if (= (length new-leaves) 1)
                 (values (car new-leaves) t)
                 (values (%make-hamt-collision :hash hash :leaves new-leaves) t)))
           (values node nil))))
   (t
     (let* ((editable-node (ensure-editable-hamt-node node token))
            (chunk (logand (ash hash (- shift)) 31))
            (bit (ash 1 chunk))
            (bitmap (hamt-transient-node-bitmap editable-node)))
       (if (zerop (logand bitmap bit))
           (values editable-node nil)
           (let* ((idx (logcount (logand bitmap (1- bit))))
                  (children (hamt-transient-node-children editable-node)))
             (multiple-value-bind (new-child removed-p)
                 (dissoc-node! (svref children idx) (+ shift 5) hash key token)
               (if (not removed-p)
                   (values editable-node nil)
                   (if (null new-child)
                       (let ((new-bitmap (logandc2 bitmap bit)))
                         (if (zerop new-bitmap)
                             (values nil t)
                             (progn
                              (setf (hamt-transient-node-bitmap editable-node) new-bitmap)
                              (setf (hamt-transient-node-children editable-node)
                                (remove-destructive children idx))
                              (values editable-node t))))
                       (progn
                        (setf (hamt-transient-node-children editable-node)
                          (update-destructive children idx new-child))
                        (values editable-node t)))))))))))

(defun hamt-dissoc! (th key)
  (let ((token (transient-hamt-token th))
        (hash (sxhash key)))
    (unless token (error "Transient used after persistent!"))
    (multiple-value-bind (new-root removed-p)
        (dissoc-node! (transient-hamt-root th) 0 hash key token)
      (setf (transient-hamt-root th) new-root)
      (when removed-p (decf (transient-hamt-count th))))
    th))

(defun freeze-hamt-node (node)
  (cond
   ((hamt-transient-node-p node)
     (let* ((children (hamt-transient-node-children node))
            (frozen-children (make-array (length children))))
       (loop for i from 0 below (length children)
             do (setf (svref frozen-children i) (freeze-hamt-node (svref children i))))
       (%make-hamt-node :bitmap (hamt-transient-node-bitmap node)
                        :children frozen-children)))
   (t node))) ; Leaves and collisions are already frozen

(defun hamt-bulk-load (flat-sequence)
  "Creates a high-speed HAMT from a flat sequence of alternating keys and values 
   (k1 v1 k2 v2 ...) using transients."
  (let ((token (cons nil nil)) ; Unique identity for this batch
                              (root nil)
                              (count 0))

    ;; 1. Step through the list two items at a time
    (loop for (key value) on flat-sequence by #'cddr
          do (multiple-value-bind (new-root added-p)
                 (assoc-node! root 0 (sxhash key) key value token)
               (setf root new-root)
               ;; Only increment the total count if it was a new key
               (when added-p (incf count))))

    ;; 2. Freeze the mutated nodes and return the persistent wrapper
    (%make-hamt :count count :root (freeze-hamt-node root))))

(defun api-transient-hamt (h)
  (%make-transient-hamt :count (hamt-count h)
                        :root (hamt-root h)
                        :token (bt:current-thread)))

(defun hamt-assoc! (th key value)
  (let ((token (transient-hamt-token th))
        (hash (sxhash key)))
    (unless (eq token (bt:current-thread))
      (error "Transient used in different thread or after persistent! call"))
    (multiple-value-bind (new-root added-p)
        (assoc-node! (transient-hamt-root th) 0 hash key value token)
      (setf (transient-hamt-root th) new-root)
      (when added-p (incf (transient-hamt-count th))))
    th))

(defun hamt-persistent! (th)
  (let ((token (transient-hamt-token th)))
    (unless (eq token (bt:current-thread))
      (error "Transient used in different thread or after persistent! call"))
    (setf (transient-hamt-token th) nil)
    (%make-hamt :count (transient-hamt-count th)
                :root (freeze-hamt-node (transient-hamt-root th)))))

(defun hamt-transfer-ownership! (th new-thread)
  "Transfer ownership of a transient HAMT to NEW-THREAD.
   The calling thread must be the current owner.  After this call the calling
   thread's token is replaced with NEW-THREAD's identity; any subsequent
   assoc!/dissoc!/persistent! by the original thread will signal an error."
  (let ((token (transient-hamt-token th)))
    (unless token
      (error "Cannot transfer ownership: transient has already been frozen via persistent!"))
    (unless (eq token (bt:current-thread))
      (error "Cannot transfer ownership: not the owner of this transient."))
    (setf (transient-hamt-token th) new-thread)
    th))

;;; ----------------------------------------------------------------------------
;;; Transient-aware reads (step 3.5)
;;; ----------------------------------------------------------------------------
;;; FIND-NODE only understands persistent HAMT-NODEs; after a hamt-assoc! the
;;; root subtree contains HAMT-TRANSIENT-NODEs, so reads on an in-progress
;;; transient need a traversal that handles both node kinds.

(defun find-node-transient (node shift hash key not-found)
  "FIND-NODE that also traverses in-progress transient nodes."
  (declare (type fixnum shift hash))
  (cond
    ((null node) (values not-found nil))
    ((hamt-leaf-p node)
     (if (equal (hamt-leaf-key node) key)
         (values (hamt-leaf-value node) t)
         (values not-found nil)))
    ((hamt-collision-p node)
     (let ((leaf (find key (hamt-collision-leaves node)
                       :key #'hamt-leaf-key :test #'equal)))
       (if leaf
           (values (hamt-leaf-value leaf) t)
           (values not-found nil))))
    (t
     (multiple-value-bind (bitmap children)
         (if (hamt-transient-node-p node)
             (values (hamt-transient-node-bitmap node)
                     (hamt-transient-node-children node))
             (values (hamt-node-bitmap node)
                     (hamt-node-children node)))
       (let* ((chunk (logand (ash hash (- shift)) +bit-mask+))
              (bit (ash 1 chunk)))
         (if (zerop (logand bitmap bit))
             (values not-found nil)
             (find-node-transient (svref children (hamt-index bitmap bit))
                                  (+ shift +bit-shift+)
                                  hash key not-found)))))))

(defun hamt-get-transient (th key &optional not-found)
  "Look KEY up in an in-progress transient HAMT.
   Returns (VALUES value found-p)."
  (find-node-transient (transient-hamt-root th) 0 (sxhash key) key not-found))

(defun %transient-vec-t-ref (tv index &optional not-found)
  "Indexed read on an in-progress transient %vec-t.
   Tree nodes are plain simple-vectors (the transient owns only its tail),
   so the persistent descent logic applies directly."
  (let ((cnt (trans-%vec-t-count tv)))
    (if (or (< index 0) (>= index cnt))
        not-found
        (let ((tail-off (if (< cnt 32) 0 (logand (- cnt 1) -32))))
          (if (>= index tail-off)
              (svref (trans-%vec-t-tail tv) (logand index 31))
              (let ((node (trans-%vec-t-root tv)))
                (loop for level from (trans-%vec-t-shift tv) downto +bit-shift+ by +bit-shift+
                      do (setf node (svref node (logand (ash index (- level)) +bit-mask+))))
                (svref node (logand index +bit-mask+))))))))

;;; --------------------------------- <dict-mixin> -------------------------------------
(defclass <dict-mixin> () ((dict-storage :initarg :dict-storage :initform (%make-hamt) :accessor dict-storage)))

;;; ------------------------------- dict functions -------------------------------------
(defmethod storage-items ((coll <dict-mixin>)) (dict-storage coll))

(defmethod size ((d <dict-mixin>))
  (hamt-count (dict-storage d)))

(defmethod empty? ((d <dict-mixin>))
  (zerop (size d)))

(defmethod assoc ((d <dict-mixin>) key value)
  (let ((hash (sxhash key))
        (h (dict-storage d)))
    (multiple-value-bind (new-root added-p) (assoc-node (hamt-root h) 0 hash key value)
      (let ((new-hamt (%make-hamt :count (if added-p (1+ (hamt-count h)) (hamt-count h))
                                  :root new-root)))
        (make-instance (class-of d) :dict-storage new-hamt)))))

(defmethod dissoc ((d <dict-mixin>) key)
  (let ((hash (sxhash key))
        (h (dict-storage d)))
    (multiple-value-bind (new-root removed-p) (dissoc-node (hamt-root h) 0 hash key)
      (if removed-p
          (make-instance (class-of d) :dict-storage
            (%make-hamt :count (1- (hamt-count h)) :root new-root))
          d)))) ; Return unmodified object if key wasn't found

(defmethod seq ((d <dict-mixin>))
  (hamt->lazy-seq (dict-storage d)))

(defmethod ref ((d <dict-mixin>) key &optional not-found)
  "Retrieves the value mapped to KEY in the HAMT.
   Returns two values: (VALUES value found-p)."
  (multiple-value-bind (val foundp) (hamt-get (dict-storage d) key)
    (if foundp
        (values val t)
        (values not-found nil))))

(defclass <sorted-dict-mixin> () ((sorted-dict-storage :initarg :sorted-dict-storage :initform (%make-btree-dict) :accessor sorted-dict-storage)))

(defmethod storage-items ((coll <sorted-dict-mixin>)) (sorted-dict-storage coll))

(defgeneric kv-conj (coll key val))

(defmethod kv-conj ((d <dict-mixin>) key val)
  (assoc d key val))

(defmethod kv-conj ((d <sorted-dict-mixin>) key val)
  (assoc d key val))

;;; -------------------------------------------------------------------------------
;;; B-Tree for sorted dicts, sets, etc.
;;; -------------------------------------------------------------------------------

;;; ----------------------------------------------------------------------
;;; Core data structures
;;; ----------------------------------------------------------------------

(defconstant +b-tree-order+ 32)

(defstruct (btree-dict (:constructor %make-btree-dict))
  (count 0 :type fixnum)
  (root nil))

(defstruct (btree-leaf (:constructor %make-btree-leaf (keys vals)))
  (keys #() :type simple-vector)
  (vals #() :type simple-vector))

(defstruct (btree-node (:constructor %make-btree-node (keys children)))
  (keys #() :type simple-vector)
  (children #() :type simple-vector))

;;; --- Array Helpers ---

(declaim (inline bsearch-keys insert-at remove-at update-at))


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

(defun bsearch-keys (keys key cmp &optional (low 0) (high (length keys)))
  "Performs a native binary search with standard comparator convention
   (-1 = less-than, 0 = equal, 1 = greater-than)."
  (declare (type simple-vector keys) (type function cmp) (type fixnum low high)
           (optimize (speed 3) (safety 0)))
  (loop while (< low high)
        do (let* ((mid (ash (+ low high) -1))
                  (c (funcall cmp key (svref keys mid))))
             ;; If c is -1 (key < mid) or 0 (key == mid), go left
             (if (<= (the fixnum c) 0)
                 (setf high mid)
                 (setf low (1+ mid)))))
  low)

(defun insert-at (arr idx val)
  (declare (type simple-vector arr) (type fixnum idx))
  (let* ((len (length arr))
         (new-arr (make-array (1+ len))))
    (replace new-arr arr :end1 idx :end2 idx)
    (setf (svref new-arr idx) val)
    (replace new-arr arr :start1 (1+ idx) :start2 idx)
    new-arr))

(defun remove-at (arr idx)
  (declare (type simple-vector arr) (type fixnum idx))
  (let* ((len (length arr))
         (new-arr (make-array (1- len))))
    (replace new-arr arr :end1 idx :end2 idx)
    (replace new-arr arr :start1 idx :start2 (1+ idx))
    new-arr))

(defun update-at (arr idx val)
  (declare (type simple-vector arr) (type fixnum idx))
  (let ((new-arr (copy-seq arr)))
    (setf (svref new-arr idx) val)
    new-arr))

;;; -----------------------------------------------------------------------
;;; Lookup and mutation logic.
;;; -----------------------------------------------------------------------

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
            (idx (bsearch-keys keys key cmp 0 count)))
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
            (idx (bsearch-keys keys key cmp 0 (max 0 (1- count)))))
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
                 (idx (bsearch-keys keys key cmp 0 count)))

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
                 (idx (bsearch-keys keys key cmp 0 (max 0 (1- count)))))
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
            (idx (bsearch-keys keys key cmp 0 count)))
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
            (idx (bsearch-keys keys key cmp 0 (max 0 (1- count)))))
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

(defun btree-bulk-load (flat-sequence cmp)
  "Creates a highly optimized B+ Tree from a flat sequence of alternating keys and values."
  (let ((pairs nil) (idx 0))
    ;; 1. Tag with original index to preserve 'last-in-wins' dict semantics
    (loop for (k v) on flat-sequence by #'cddr
          do (push (list k v idx) pairs) (incf idx))

    ;; 2. Sort natively
    (setf pairs (sort pairs (lambda (a b)
                              (let ((c (funcall cmp (car a) (car b))))
                                (if (zerop c) (> (third a) (third b)) (< c 0))))))

    ;; 3. Deduplicate
    (let ((unique-pairs nil))
      (loop for p in pairs
            do (when (or (null unique-pairs) (not (zerop (funcall cmp (car p) (caar unique-pairs)))))
                     (push (cons (car p) (cadr p)) unique-pairs)))
      (setf unique-pairs (nreverse unique-pairs))

      ;; 4. Build Tree Bottom-Up
      (let* ((count (length unique-pairs))
             (nodes nil))
        (if (zerop count)
            (%make-btree-dict :count 0 :root nil)
            (progn
             (loop for chunk on unique-pairs by (lambda (x) (nthcdr 32 x))
                   do (let* ((chunk-len (min 32 (length chunk)))
                             (keys (make-array chunk-len))
                             (vals (make-array chunk-len)))
                        (loop for i from 0 below chunk-len for pair in chunk
                              do (setf (svref keys i) (car pair) (svref vals i) (cdr pair)))
                        (push (%make-btree-leaf keys vals) nodes)))
             (setf nodes (nreverse nodes))

             (loop while (> (length nodes) 1)
                   do (let ((next-level nil))
                        (loop for chunk on nodes by (lambda (x) (nthcdr 32 x))
                              do (let* ((chunk-len (min 32 (length chunk)))
                                        (children (make-array chunk-len))
                                        (keys (make-array (1- chunk-len))))
                                   (loop for i from 0 below chunk-len for node in chunk
                                         do (setf (svref children i) node)
                                           (when (> i 0) (setf (svref keys (1- i)) (first-key node))))
                                   (push (%make-btree-node keys children) next-level)))
                        (setf nodes (nreverse next-level))))

             (%make-btree-dict :count count :root (car nodes))))))))

;;; -------------------------------------------------------------------------
;;; Lazy output.
;;; -------------------------------------------------------------------------

(defun btree-iterator (root)
  (let ((stack (if root (list (cons root 0)) nil)))
    (lambda ()
      (loop
       (if (null stack)
           (return :eof)
           (let* ((top (car stack))
                  (node (car top))
                  (idx (cdr top)))
             (cond
              ((btree-leaf-p node)
                (if (< idx (length (btree-leaf-keys node)))
                    (progn
                     (incf (cdr top))
                     (return (values (svref (btree-leaf-keys node) idx)
                               (svref (btree-leaf-vals node) idx))))
                    (pop stack)))
              ((btree-node-p node)
                (if (< idx (length (btree-node-children node)))
                    (progn
                     (incf (cdr top))
                     (push (cons (svref (btree-node-children node) idx) 0) stack))
                    (pop stack))))))))))

;;; --------------------------- sorted-dict ----------------------------

;;; --------------------------------------------------------------------
;;; Collection methods for <sorted-dict>.
;;; NOTE: These are commented out because <sorted-dict> is defined in
;;; collections.lisp which loads after this file. Move these there or
;;; to a file that loads after collections.
;;; --------------------------------------------------------------------

(defmethod size ((d <sorted-dict-mixin>))
  (fol.compiler.collection-primitives::btree-dict-count (storage-items d)))

(defmethod empty? ((d <sorted-dict-mixin>))
  (zerop (size d)))

(defmethod ref ((d <sorted-dict-mixin>) key &optional not-found)
  (let ((bd (storage-items d)))
    (multiple-value-bind (val foundp)
        (fol.compiler.collection-primitives::btree-get (fol.compiler.collection-primitives::btree-dict-root bd)
                                                       key (fol.compiler.collections:cmp-fn d))
      (if foundp (values val t) (values not-found nil)))))

(defmethod assoc ((d <sorted-dict-mixin>) key val)
  (let ((bd (storage-items d)))
    (multiple-value-bind (new-root split-key split-right old-val found-p)
        (fol.compiler.collection-primitives::btree-assoc-node (fol.compiler.collection-primitives::btree-dict-root bd)
                                                              key val (fol.compiler.collections:cmp-fn d))

      ;; If the root split, create a new parent over it
      (let* ((final-root (if split-key
                             (fol.compiler.collection-primitives::%make-btree-node (vector split-key) (vector new-root split-right))
                             new-root))
             (new-count (if found-p (fol.compiler.collection-primitives::btree-dict-count bd)
                            (1+ (fol.compiler.collection-primitives::btree-dict-count bd)))))

        (make-instance (class-of d)
          :sorted-dict-storage (fol.compiler.collection-primitives::%make-btree-dict :count new-count :root final-root)
          :cmp-fn (fol.compiler.collections:cmp-fn d))))))

(defmethod dissoc ((d <sorted-dict-mixin>) key)
  (let ((bd (storage-items d)))
    (multiple-value-bind (new-root old-val found-p)
        (fol.compiler.collection-primitives::btree-dissoc-node (fol.compiler.collection-primitives::btree-dict-root bd)
                                                               key (fol.compiler.collections:cmp-fn d))
      (declare (ignore old-val))
      (if found-p
          (make-instance (class-of d)
            :sorted-dict-storage (fol.compiler.collection-primitives::%make-btree-dict
                                  :count (1- (fol.compiler.collection-primitives::btree-dict-count bd))
                                  :root new-root)
            :cmp-fn (fol.compiler.collections:cmp-fn d))
          d))))
;;; --------------------------------------------------------------------------------
;;; Deque functions.
;;; --------------------------------------------------------------------------------

(defun %vec-t-pop (v)
  "Removes the last element of the vector. 
   Uses O(1) tail-slicing, falling back to an O(N) rebuild strictly on 32-element boundaries."
  (let* ((count (%t-count v))
         (tail-len (length (%t-tail v))))
    (cond
     ((<= count 1)
       (%make-vec-t :count 0 :shift 0 :root #() :tail #()))

     ((> tail-len 1)
       ;; FAST PATH: O(1) tail slice. The tree root is perfectly shared.
       (let ((new-tail (make-array (1- tail-len))))
         (replace new-tail (%t-tail v))
         (%make-vec-t :count (1- count)
                      :shift (%t-shift v)
                      :root (%t-root v)
                      :tail new-tail)))

     (t
       ;; AMORTIZED PATH: We exhausted a chunk. Rebuild the trie.
       (let ((lst nil)
             (iter (%vec-t-iterator v)))
         ;; Stream everything except the last element
         (loop repeat (1- count)
               do (push (funcall iter) lst))
         (%build-vec-t-from-list (nreverse lst)))))))

(defun %int-compare (a b)
  "Comparator for integers returning -1 (a < b), 1 (a > b), or 0 (a == b).
   Standard convention: -1 = less-than, 0 = equal, 1 = greater-than."
  (declare (type fixnum a b) (optimize (speed 3) (safety 0)))
  (if (cl:< a b) -1 (if (cl:> a b) 1 0)))

;;; -------------------------------------------------------------------------
;;; Aliases
;;; -------------------------------------------------------------------------

(defun %vec-t-push (v val) (%vec-t-conj v val))

;;; -------------------------------------------------------------------------
;;; HAMT convenience helpers (operate on HAMT structs, not collection objects)
;;; -------------------------------------------------------------------------

(defun hamt-assoc (h key value)
  "Returns a new HAMT with key→value added/updated."
  (multiple-value-bind (new-root added-p)
      (assoc-node (hamt-root h) 0 (sxhash key) key value)
    (%make-hamt :count (if added-p (1+ (hamt-count h)) (hamt-count h))
                :root new-root)))

(defun hamt-dissoc (h key)
  "Returns a new HAMT with key removed."
  (multiple-value-bind (new-root removed-p)
      (dissoc-node (hamt-root h) 0 (sxhash key) key)
    (if removed-p
        (%make-hamt :count (1- (hamt-count h)) :root new-root)
        h)))

(defmacro do-hamt ((key val hamt &optional result) &body body)
  "Iterates over all key-value pairs in the HAMT."
  (let ((iter-var (gensym "ITER"))
        (pair-var (gensym "PAIR")))
    `(let ((,iter-var (hamt-iterator ,hamt)))
       (loop (let ((,pair-var (funcall ,iter-var)))
               (when (eq ,pair-var :eof) (return ,result))
               (let ((,key (car ,pair-var))
                     (,val (cdr ,pair-var)))
                 ,@body))))))

(defun hamt-to-list (h)
  "Returns HAMT entries as a list of (key . value) cons cells."
  (let ((result nil))
    (do-hamt (k v h (nreverse result))
             (push (cons k v) result))))

;;; -------------------------------------------------------------------------
;;; B-Tree convenience helpers
;;; -------------------------------------------------------------------------

(defmacro do-btree ((key val btree-dict &optional result) &body body)
  "Iterates over all key-value pairs in a btree-dict."
  (let ((iter-var (gensym "ITER"))
        (done-var (gensym "DONE")))
    `(let ((,iter-var (btree-iterator (btree-dict-root ,btree-dict))))
       (loop (multiple-value-bind (,key ,val)
                 (funcall ,iter-var)
               (when (eq ,key :eof) (return ,result))
               ,@body)))))

(defun btree-to-list (bd)
  "Returns btree-dict entries as a list of (key . value) cons cells."
  (let ((result nil))
    (do-btree (k v bd (nreverse result))
              (push (cons k v) result))))