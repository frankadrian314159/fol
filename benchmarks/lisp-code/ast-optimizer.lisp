(defpackage :ast-opt-cl (:use :cl))
(in-package :ast-opt-cl)
(defstruct ast-node)
(defstruct (op-lit (:include ast-node)) val)
(defstruct (op-var (:include ast-node)) name)
(defstruct (op-add (:include ast-node)) left right)
(defstruct (op-sub (:include ast-node)) left right)
(defstruct (op-mul (:include ast-node)) left right)
(defstruct (op-div (:include ast-node)) left right)
(defstruct (op-rem (:include ast-node)) left right)
(defstruct (op-pow (:include ast-node)) left right)
(defstruct (op-band (:include ast-node)) left right)
(defstruct (op-bor (:include ast-node)) left right)
(defstruct (op-bxor (:include ast-node)) left right)
(defstruct (op-shl (:include ast-node)) left right)
(defstruct (op-shr (:include ast-node)) left right)
(defstruct (op-eq (:include ast-node)) left right)
(defstruct (op-neq (:include ast-node)) left right)
(defstruct (op-lt (:include ast-node)) left right)
(defstruct (op-gt (:include ast-node)) left right)
(defstruct (op-le (:include ast-node)) left right)
(defstruct (op-ge (:include ast-node)) left right)
(defstruct (op-and (:include ast-node)) left right)
(defstruct (op-or (:include ast-node)) left right)
(defstruct (op-concat (:include ast-node)) left right)
(defstruct (op-split (:include ast-node)) left right)
(defstruct (op-join (:include ast-node)) left right)
(defstruct (op-map (:include ast-node)) left right)
(defun ast-optimize (n)
  (typecase n
    (op-add
      (let ((l (op-add-left n)) (r (op-add-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-sub
      (let ((l (op-sub-left n)) (r (op-sub-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-mul
      (let ((l (op-mul-left n)) (r (op-mul-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          ((and (op-lit-p l) (eql (op-lit-val l) 1)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 1)) l)
          (t n))))
    (op-div
      (let ((l (op-div-left n)) (r (op-div-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          ((and (op-lit-p l) (eql (op-lit-val l) 1)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 1)) l)
          (t n))))
    (op-rem
      (let ((l (op-rem-left n)) (r (op-rem-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-pow
      (let ((l (op-pow-left n)) (r (op-pow-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-band
      (let ((l (op-band-left n)) (r (op-band-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-bor
      (let ((l (op-bor-left n)) (r (op-bor-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-bxor
      (let ((l (op-bxor-left n)) (r (op-bxor-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-shl
      (let ((l (op-shl-left n)) (r (op-shl-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-shr
      (let ((l (op-shr-left n)) (r (op-shr-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-eq
      (let ((l (op-eq-left n)) (r (op-eq-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-neq
      (let ((l (op-neq-left n)) (r (op-neq-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-lt
      (let ((l (op-lt-left n)) (r (op-lt-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-gt
      (let ((l (op-gt-left n)) (r (op-gt-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-le
      (let ((l (op-le-left n)) (r (op-le-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-ge
      (let ((l (op-ge-left n)) (r (op-ge-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-and
      (let ((l (op-and-left n)) (r (op-and-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-or
      (let ((l (op-or-left n)) (r (op-or-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-concat
      (let ((l (op-concat-left n)) (r (op-concat-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-split
      (let ((l (op-split-left n)) (r (op-split-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-join
      (let ((l (op-join-left n)) (r (op-join-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (op-map
      (let ((l (op-map-left n)) (r (op-map-right n)))
        (cond
          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)
          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)
          (t n))))
    (t n)))
(defun walk (n)
  (typecase n
    (op-add (ast-optimize (make-op-add :left (walk (op-add-left n)) :right (walk (op-add-right n)))))
    (op-sub (ast-optimize (make-op-sub :left (walk (op-sub-left n)) :right (walk (op-sub-right n)))))
    (op-mul (ast-optimize (make-op-mul :left (walk (op-mul-left n)) :right (walk (op-mul-right n)))))
    (op-div (ast-optimize (make-op-div :left (walk (op-div-left n)) :right (walk (op-div-right n)))))
    (op-rem (ast-optimize (make-op-rem :left (walk (op-rem-left n)) :right (walk (op-rem-right n)))))
    (op-pow (ast-optimize (make-op-pow :left (walk (op-pow-left n)) :right (walk (op-pow-right n)))))
    (op-band (ast-optimize (make-op-band :left (walk (op-band-left n)) :right (walk (op-band-right n)))))
    (op-bor (ast-optimize (make-op-bor :left (walk (op-bor-left n)) :right (walk (op-bor-right n)))))
    (op-bxor (ast-optimize (make-op-bxor :left (walk (op-bxor-left n)) :right (walk (op-bxor-right n)))))
    (op-shl (ast-optimize (make-op-shl :left (walk (op-shl-left n)) :right (walk (op-shl-right n)))))
    (op-shr (ast-optimize (make-op-shr :left (walk (op-shr-left n)) :right (walk (op-shr-right n)))))
    (op-eq (ast-optimize (make-op-eq :left (walk (op-eq-left n)) :right (walk (op-eq-right n)))))
    (op-neq (ast-optimize (make-op-neq :left (walk (op-neq-left n)) :right (walk (op-neq-right n)))))
    (op-lt (ast-optimize (make-op-lt :left (walk (op-lt-left n)) :right (walk (op-lt-right n)))))
    (op-gt (ast-optimize (make-op-gt :left (walk (op-gt-left n)) :right (walk (op-gt-right n)))))
    (op-le (ast-optimize (make-op-le :left (walk (op-le-left n)) :right (walk (op-le-right n)))))
    (op-ge (ast-optimize (make-op-ge :left (walk (op-ge-left n)) :right (walk (op-ge-right n)))))
    (op-and (ast-optimize (make-op-and :left (walk (op-and-left n)) :right (walk (op-and-right n)))))
    (op-or (ast-optimize (make-op-or :left (walk (op-or-left n)) :right (walk (op-or-right n)))))
    (op-concat (ast-optimize (make-op-concat :left (walk (op-concat-left n)) :right (walk (op-concat-right n)))))
    (op-split (ast-optimize (make-op-split :left (walk (op-split-left n)) :right (walk (op-split-right n)))))
    (op-join (ast-optimize (make-op-join :left (walk (op-join-left n)) :right (walk (op-join-right n)))))
    (op-map (ast-optimize (make-op-map :left (walk (op-map-left n)) :right (walk (op-map-right n)))))
    (t n)))

(defun build-tree (depth)
  (if (= depth 0)
      (make-op-lit :val 0)
      (make-op-add :left (build-tree (1- depth)) :right (make-op-lit :val 0))))

(defun run-bench (n)
  (let ((tree (build-tree 14)))
    (dotimes (i n)
      (walk tree))))
    