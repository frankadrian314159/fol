;;; FOL Compiler - Zippers (Functional Tree Editing)
;;;
;;; Implementation of Huet's Zipper, modeled after Clojure's clojure.zip.
;;; Allows functional navigation and modification of tree structures.

(defpackage fol.compiler.zip
  (:use cl)
  (:shadow replace remove next)
  (:export
   zipper seq-zip vector-zip
   up down left right
   leftmost rightmost
   lefts rights path children
   make-node
   replace edit
   insert-child insert-left insert-right append-child
   remove
   next prev
   root node
   branch? end?))

(in-package :fol.compiler.zip)

;;; ===========================================================================
;;; Zipper Structure
;;; ===========================================================================

(defstruct (zipper-loc (:conc-name loc-) (:constructor %make-loc))
  node ; The current node
  path ; The path structure (or nil if root)
  meta) ; Meta information (branch?, children, make-node functions)

(defstruct (zipper-path (:conc-name path-) (:constructor %make-path))
  l ; Left siblings (list, reversed)
  pnodes ; Parent nodes (list) path from root
  ppath ; Parent path structure
  r ; Right siblings (list)
  changed? ; Boolean, true if node or children have changed
  )

(defstruct (zipper-meta (:conc-name meta-) (:constructor %make-meta))
  branch?
  children
  make-node)

;;; ===========================================================================
;;; Creation
;;; ===========================================================================

(defun zipper (branch? children make-node root)
  "Creates a new zipper structure."
  (%make-loc :node root
             :path nil
             :meta (%make-meta :branch? branch?
                               :children children
                               :make-node make-node)))

(defun seq-zip (root)
  "Returns a zipper for nested sequences (lists)."
  (zipper (lambda (n) (or (listp n) (typep n 'sequence)))
          (lambda (n) n)
          (lambda (n children)
            (if (listp n)
                children
                (coerce children (type-of n))))
          root))

(defun vector-zip (root)
  "Returns a zipper for nested vectors."
  (zipper (lambda (n) (vectorp n))
          (lambda (n) (coerce n 'list))
          (lambda (n children) (coerce children 'vector))
          root))

;;; ===========================================================================
;;; Navigation
;;; ===========================================================================

(defun node (loc)
  "Returns the node at the current location."
  (loc-node loc))

(defun branch? (loc)
  "Returns true if the node at loc is a branch."
  (funcall (meta-branch? (loc-meta loc)) (loc-node loc)))

(defun children (loc)
  "Returns a seq of children of the node at loc."
  (if (branch? loc)
      (funcall (meta-children (loc-meta loc)) (loc-node loc))
      (error "Called children on a leaf node")))

(defun make-node (loc node children)
  "Returns a new node created from the given node and children."
  (funcall (meta-make-node (loc-meta loc)) node children))

(defun path (loc)
  "Returns a list of nodes leading to this loc."
  (let ((p (loc-path loc)))
    (if p (path-pnodes p) nil)))

(defun lefts (loc)
  "Returns a seq of the left siblings of this loc."
  (let ((p (loc-path loc)))
    (if p (reverse (path-l p)) nil)))

(defun rights (loc)
  "Returns a seq of the right siblings of this loc."
  (let ((p (loc-path loc)))
    (if p (path-r p) nil)))

(defun down (loc)
  "Returns the loc of the leftmost child of the node at this loc, or nil if no children."
  (if (branch? loc)
      (let ((cs (children loc)))
        (when cs
              (let ((node (if (listp cs) (car cs) (elt cs 0)))
                    (path (%make-path :l nil
                                      :pnodes (if (loc-path loc)
                                                  (append (path-pnodes (loc-path loc)) (list (loc-node loc)))
                                                  (list (loc-node loc)))
                                      :ppath (loc-path loc)
                                      :r (if (listp cs) (cdr cs) (subseq cs 1))
                                      :changed? nil)))
                (%make-loc :node node
                           :path path
                           :meta (loc-meta loc)))))
      nil))

(defun up (loc)
  "Returns the loc of the parent of the node at this loc, or nil if at root."
  (let ((path (loc-path loc)))
    (when path
          (let ((pnodes (path-pnodes path)))
            (if pnodes
                (let ((pnode (car (last pnodes))))
                  (if (path-changed? path)
                      (%make-loc :node (make-node loc pnode (append (reverse (path-l path))
                                                              (cons (loc-node loc)
                                                                    (path-r path))))
                                 :path (let ((pp (path-ppath path)))
                                         (if pp
                                             (%make-path :l (path-l pp)
                                                         :pnodes (path-pnodes pp)
                                                         :ppath (path-ppath pp)
                                                         :r (path-r pp)
                                                         :changed? t)
                                             nil))
                                 :meta (loc-meta loc))
                      (%make-loc :node pnode
                                 :path (path-ppath path)
                                 :meta (loc-meta loc))))
                nil)))))

(defun root (loc)
  "Zips up the tree to the root and returns the root node."
  (loop
   (let ((p (up loc)))
     (if p
         (setf loc p)
         (return (node loc))))))

(defun right (loc)
  "Returns the loc of the right sibling of the node at this loc, or nil."
  (let ((path (loc-path loc)))
    (when (and path (path-r path))
          (let ((l (path-l path))
                (r (path-r path)))
            (%make-loc :node (car r)
                       :path (%make-path :l (cons (loc-node loc) l)
                                         :pnodes (path-pnodes path)
                                         :ppath (path-ppath path)
                                         :r (cdr r)
                                         :changed? (path-changed? path))
                       :meta (loc-meta loc))))))

(defun rightmost (loc)
  "Returns the loc of the rightmost sibling of the node at this loc, or self."
  (let ((path (loc-path loc)))
    (if (and path (path-r path))
        (loop for next = (right loc)
              while next
              do (setf loc next)
              finally (return loc))
        loc)))

(defun left (loc)
  "Returns the loc of the left sibling of the node at this loc, or nil."
  (let ((path (loc-path loc)))
    (when (and path (path-l path))
          (let ((l (path-l path))
                (r (path-r path)))
            (%make-loc :node (car l)
                       :path (%make-path :l (cdr l)
                                         :pnodes (path-pnodes path)
                                         :ppath (path-ppath path)
                                         :r (cons (loc-node loc) r)
                                         :changed? (path-changed? path))
                       :meta (loc-meta loc))))))

(defun leftmost (loc)
  "Returns the loc of the leftmost sibling of the node at this loc, or self."
  (let ((path (loc-path loc)))
    (if (and path (path-l path))
        (loop for next = (left loc)
              while next
              do (setf loc next)
              finally (return loc))
        loc)))

;;; ===========================================================================
;;; Modification
;;; ===========================================================================

(defun replace (loc node)
  "Replaces the node at this loc, without moving."
  (%make-loc :node node
             :path (let ((p (loc-path loc)))
                     (if p
                         (%make-path :l (path-l p)
                                     :pnodes (path-pnodes p)
                                     :ppath (path-ppath p)
                                     :r (path-r p)
                                     :changed? t)
                         nil)) ;; Changing root? logic for root replacement in next up/root call needs to be consistent, but up/root handle nil path as root.
             ;; If we replace root, we just change the node of the loc. The path is nil.
             :meta (loc-meta loc)))

(defun edit (loc f &rest args)
  "Replaces the node at this loc with the value of (f node args)."
  (replace loc (apply f (loc-node loc) args)))

(defun insert-left (loc item)
  "Inserts item as the left sibling of the node at this loc. Returns new loc."
  (let ((path (loc-path loc)))
    (unless path (error "Insert at top"))
    (%make-loc :node (loc-node loc)
               :path (%make-path :l (cons item (path-l path))
                                 :pnodes (path-pnodes path)
                                 :ppath (path-ppath path)
                                 :r (path-r path)
                                 :changed? t)
               :meta (loc-meta loc))))

(defun insert-right (loc item)
  "Inserts item as the right sibling of the node at this loc. Returns new loc."
  (let ((path (loc-path loc)))
    (unless path (error "Insert at top"))
    (%make-loc :node (loc-node loc)
               :path (%make-path :l (path-l path)
                                 :pnodes (path-pnodes path)
                                 :ppath (path-ppath path)
                                 :r (cons item (path-r path))
                                 :changed? t)
               :meta (loc-meta loc))))

(defun insert-child (loc item)
  "Inserts item as the leftmost child of the node at this loc. Returns new loc."
  (replace loc (make-node loc (loc-node loc) (cons item (children loc)))))

(defun append-child (loc item)
  "Inserts item as the rightmost child of the node at this loc. Returns new loc."
  (replace loc (make-node loc (loc-node loc) (append (children loc) (list item)))))

(defun remove (loc)
  "Removes the node at loc, returning the loc that would have preceded it in a depth-first walk."
  (let ((path (loc-path loc)))
    (unless path (error "Remove at top"))
    (if (path-l path)
        (let ((l (path-l path)))
          (loop with start-loc = (%make-loc :node (car l)
                                            :path (%make-path :l (cdr l) ;; Left of new loc is remaining lefts
                                                              :pnodes (path-pnodes path)
                                                              :ppath (path-ppath path)
                                                              :r (path-r path) ;; IMPORTANT: use original rights (skipping current node)
                                                              :changed? t)
                                            :meta (loc-meta loc))
                for p = start-loc then (if (and (branch? p) (down p)) (rightmost (down p)) p)
                while (and (branch? p) (down p))
                finally (return p)))
        ;; No lefts -> up
        (let ((path (loc-path loc)))
          (%make-loc :node (make-node loc (car (last (path-pnodes path))) (path-r path))
                     :path (path-ppath path)
                     :meta (loc-meta loc))))))

;;; ===========================================================================
;;; Enumeration / Traversal
;;; ===========================================================================

(defun end? (loc)
  "Returns true if loc represents the end of a depth-first walk."
  (eq (loc-path loc) :end))

(defun next (loc)
  "Moves to the next loc in the hierarchy, depth-first."
  (if (end? loc)
      loc
      (or
       (and (branch? loc) (down loc))
       (right loc)
       (loop for p = loc then (up p)
             while (and (up p) (not (right p)))
             finally (return (if (up p)
                                 (right p)
                                 ;; At root, can't go up? we are done
                                 (%make-loc :node (loc-node p) :path :end :meta (loc-meta p))))))))

(defun prev (loc)
  "Moves to the previous loc in the hierarchy, depth-first."
  (if (left loc)
      (loop for p = (left loc) then (if (and (branch? p) (down p)) (rightmost (down p)) p)
            while (and (branch? p) (down p))
            finally (return p))
      (up loc)))
