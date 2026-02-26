;;; run-clos-header-tax-bench.lisp
;;;
;;; Quantifies the per-object memory overhead ("CLOS identity tax") of FOL's
;;; persistent objects versus lean native representations.
;;;
;;; Compares, at N = 1, 2, 4, 8, 12, 16 user slots:
;;;   cons        -- 1-slot baseline (2 words, single allocation)
;;;   struct      -- defstruct (inline slots, single allocation)
;;;   CLOS        -- standard-class (2 allocations: instance + slot-vector)
;;;   FOL-Native  -- persistent-class, N <= 8 (native CLOS slots + 2 overhead)
;;;   FOL-Overflow-- persistent-class, N > 8  (native + overflow trie)
;;;
;;; Metrics per representation:
;;;   bytes/obj   -- effective heap bytes consumed per object (alloc probe)
;;;   ns/obj      -- allocation throughput
;;;   GC hits     -- GC invocations during 1M-object live-set build
;;;   live MB     -- heap bytes retained by 1M live objects
;;;
;;; Run:
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/run-clos-header-tax-bench.lisp

(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

(in-package :cl-user)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Object definitions (generated per slot count)
;;;; ─────────────────────────────────────────────────────────────────────────

;;; Generate slot-symbol lists
(defun slot-syms (n)
  (loop for i from 1 to n collect (intern (format nil "S~A" i))))

;;; Struct types (defined statically for each N we test)
(defstruct st1  s1)
(defstruct st2  s1 s2)
(defstruct st4  s1 s2 s3 s4)
(defstruct st8  s1 s2 s3 s4 s5 s6 s7 s8)
(defstruct st12 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12)
(defstruct st16 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12 s13 s14 s15 s16)

;;; CLOS classes
(defclass clos1  () ((s1  :initarg :s1  :initform 0)))
(defclass clos2  () ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)))
(defclass clos4  () ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
                     (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)))
(defclass clos8  () ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
                     (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)
                     (s5  :initarg :s5  :initform 0)(s6  :initarg :s6  :initform 0)
                     (s7  :initarg :s7  :initform 0)(s8  :initarg :s8  :initform 0)))
(defclass clos12 () ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
                     (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)
                     (s5  :initarg :s5  :initform 0)(s6  :initarg :s6  :initform 0)
                     (s7  :initarg :s7  :initform 0)(s8  :initarg :s8  :initform 0)
                     (s9  :initarg :s9  :initform 0)(s10 :initarg :s10 :initform 0)
                     (s11 :initarg :s11 :initform 0)(s12 :initarg :s12 :initform 0)))
(defclass clos16 () ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
                     (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)
                     (s5  :initarg :s5  :initform 0)(s6  :initarg :s6  :initform 0)
                     (s7  :initarg :s7  :initform 0)(s8  :initarg :s8  :initform 0)
                     (s9  :initarg :s9  :initform 0)(s10 :initarg :s10 :initform 0)
                     (s11 :initarg :s11 :initform 0)(s12 :initarg :s12 :initform 0)
                     (s13 :initarg :s13 :initform 0)(s14 :initarg :s14 :initform 0)
                     (s15 :initarg :s15 :initform 0)(s16 :initarg :s16 :initform 0)))

;;; FOL persistent classes (use persistent-class metaclass)
(defclass fol1  (fol.compiler.persistent:<persistent-object>)
  ((s1  :initarg :s1  :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))
(defclass fol2  (fol.compiler.persistent:<persistent-object>)
  ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))
(defclass fol4  (fol.compiler.persistent:<persistent-object>)
  ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
   (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))
(defclass fol8  (fol.compiler.persistent:<persistent-object>)
  ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
   (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)
   (s5  :initarg :s5  :initform 0)(s6  :initarg :s6  :initform 0)
   (s7  :initarg :s7  :initform 0)(s8  :initarg :s8  :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))
;;; fol12 and fol16 use overflow path (> T=8 user slots)
(defclass fol12 (fol.compiler.persistent:<persistent-object>)
  ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
   (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)
   (s5  :initarg :s5  :initform 0)(s6  :initarg :s6  :initform 0)
   (s7  :initarg :s7  :initform 0)(s8  :initarg :s8  :initform 0)
   (s9  :initarg :s9  :initform 0)(s10 :initarg :s10 :initform 0)
   (s11 :initarg :s11 :initform 0)(s12 :initarg :s12 :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))
(defclass fol16 (fol.compiler.persistent:<persistent-object>)
  ((s1  :initarg :s1  :initform 0)(s2  :initarg :s2  :initform 0)
   (s3  :initarg :s3  :initform 0)(s4  :initarg :s4  :initform 0)
   (s5  :initarg :s5  :initform 0)(s6  :initarg :s6  :initform 0)
   (s7  :initarg :s7  :initform 0)(s8  :initarg :s8  :initform 0)
   (s9  :initarg :s9  :initform 0)(s10 :initarg :s10 :initform 0)
   (s11 :initarg :s11 :initform 0)(s12 :initarg :s12 :initform 0)
   (s13 :initarg :s13 :initform 0)(s14 :initarg :s14 :initform 0)
   (s15 :initarg :s15 :initform 0)(s16 :initarg :s16 :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Primitives: direct object size via sb-kernel
;;;; ─────────────────────────────────────────────────────────────────────────

(defun instance-bytes (obj)
  "Total bytes of all allocations associated with a CLOS instance:
   the instance header + its slot vector (if a standard-object)."
  (let ((base (sb-kernel::primitive-object-size obj)))
    (if (typep obj 'standard-object)
        (+ base (sb-kernel::primitive-object-size
                  (sb-pcl::std-instance-slots obj)))
        base)))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Allocation probe: bytes/obj and ns/obj
;;;; ─────────────────────────────────────────────────────────────────────────

(defmacro alloc-probe (label n &body body)
  "Run BODY N times, report bytes/obj and ns/obj."
  (let ((gb (gensym)) (gt (gensym)) (gi (gensym)) (dummy (gensym)))
    `(progn
       (sb-ext:gc :full t)
       (let* ((,gb (sb-ext:get-bytes-consed))
              (,gt (get-internal-real-time))
              (,dummy (dotimes (,gi ,n) ,@body)))
         (declare (ignore ,dummy))
         (let* ((bytes (- (sb-ext:get-bytes-consed) ,gb))
                (ns    (* 1e9 (/ (- (get-internal-real-time) ,gt)
                                 ,n internal-time-units-per-second)))
                (bpo   (/ bytes ,n)))
           (format t "  ~A~35T~6,1f B/obj  ~6,1f ns/obj~%" ,label bpo ns)
           bpo)))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Live-set GC pressure: hold 1M objects, count GC hits, report live MB
;;;; ─────────────────────────────────────────────────────────────────────────

(defmacro gc-pressure (label n &body body)
  "Allocate N objects, hold all live, report total allocation and B/obj."
  (let ((garr (gensym)) (gi (gensym)) (gb0 (gensym)))
    `(progn
       (sb-ext:gc :full t)
       (let* ((,garr (make-array ,n))
              (,gb0  (sb-ext:get-bytes-consed)))
         (dotimes (,gi ,n)
           (setf (svref ,garr ,gi) (progn ,@body)))
         (let* ((total-mb (/ (- (sb-ext:get-bytes-consed) ,gb0) 1e6)))
           (format t "  ~A~35T~6,1f MB total alloc  (~,1f B/obj avg)~%"
                   ,label total-mb (/ (* total-mb 1e6) ,n)))
         ,garr))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Exact size probe using primitive-object-size on a single live object
;;;; ─────────────────────────────────────────────────────────────────────────

(defun report-exact-sizes ()
  (format t "~%=== Exact per-object sizes (primitive-object-size) ===~%")
  (format t "~%  Representation~35T  Instance   SlotVec     Total~%")
  (format t "  ~57,,,'-<~>~%")
  (flet ((row (label obj)
           (let* ((inst (sb-kernel::primitive-object-size obj))
                  (sv   (if (typep obj 'standard-object)
                            (sb-kernel::primitive-object-size
                              (sb-pcl::std-instance-slots obj))
                            0))
                  (tot  (+ inst sv)))
             (format t "  ~A~35T~6A     ~6A     ~6A bytes~%"
                     label inst (if (zerop sv) "--" sv) tot))))
    (row "cons (1-slot baseline)"
         (cons 1 2))
    (row "struct 1-slot"
         (make-st1 :s1 0))
    (row "struct 2-slot"
         (make-st2 :s1 0 :s2 0))
    (row "struct 4-slot"
         (make-st4 :s1 0 :s2 0 :s3 0 :s4 0))
    (row "struct 8-slot"
         (make-st8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (row "struct 12-slot"
         (make-st12 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0 :s9 0 :s10 0 :s11 0 :s12 0))
    (row "struct 16-slot"
         (make-st16 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                    :s9 0 :s10 0 :s11 0 :s12 0 :s13 0 :s14 0 :s15 0 :s16 0))
    (format t "  ~57,,,'-<~>~%")
    (row "CLOS 1-slot"
         (make-instance 'clos1 :s1 0))
    (row "CLOS 2-slot"
         (make-instance 'clos2 :s1 0 :s2 0))
    (row "CLOS 4-slot"
         (make-instance 'clos4 :s1 0 :s2 0 :s3 0 :s4 0))
    (row "CLOS 8-slot"
         (make-instance 'clos8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (row "CLOS 12-slot"
         (make-instance 'clos12 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                                :s9 0 :s10 0 :s11 0 :s12 0))
    (row "CLOS 16-slot"
         (make-instance 'clos16 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                                :s9 0 :s10 0 :s11 0 :s12 0 :s13 0 :s14 0 :s15 0 :s16 0))
    (format t "  ~57,,,'-<~>~%")
    (row "FOL 1-slot  (native path)"
         (make-instance 'fol1 :s1 0))
    (row "FOL 2-slot  (native path)"
         (make-instance 'fol2 :s1 0 :s2 0))
    (row "FOL 4-slot  (native path)"
         (make-instance 'fol4 :s1 0 :s2 0 :s3 0 :s4 0))
    (row "FOL 8-slot  (native path)"
         (make-instance 'fol8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (row "FOL 12-slot (overflow path)"
         (make-instance 'fol12 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                               :s9 0 :s10 0 :s11 0 :s12 0))
    (row "FOL 16-slot (overflow path)"
         (make-instance 'fol16 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                               :s9 0 :s10 0 :s11 0 :s12 0 :s13 0 :s14 0 :s15 0 :s16 0))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Allocation throughput benchmark
;;;; ─────────────────────────────────────────────────────────────────────────

(defun report-throughput ()
  (format t "~%=== Allocation throughput (bytes/obj and ns/obj, N=500,000) ===~%")
  (let ((n 500000))
    (format t "~%  [Baseline]~%")
    (alloc-probe "cons (1-slot)" n (cons 0 nil))
    (format t "  [Struct]~%")
    (alloc-probe "struct 1-slot" n (make-st1 :s1 0))
    (alloc-probe "struct 2-slot" n (make-st2 :s1 0 :s2 0))
    (alloc-probe "struct 4-slot" n (make-st4 :s1 0 :s2 0 :s3 0 :s4 0))
    (alloc-probe "struct 8-slot" n (make-st8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (format t "  [CLOS standard-class]~%")
    (alloc-probe "CLOS 1-slot"  n (make-instance 'clos1  :s1 0))
    (alloc-probe "CLOS 2-slot"  n (make-instance 'clos2  :s1 0 :s2 0))
    (alloc-probe "CLOS 4-slot"  n (make-instance 'clos4  :s1 0 :s2 0 :s3 0 :s4 0))
    (alloc-probe "CLOS 8-slot"  n (make-instance 'clos8  :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (format t "  [FOL persistent-class — native path, <= 8 user slots]~%")
    (alloc-probe "FOL 1-slot"   n (make-instance 'fol1   :s1 0))
    (alloc-probe "FOL 2-slot"   n (make-instance 'fol2   :s1 0 :s2 0))
    (alloc-probe "FOL 4-slot"   n (make-instance 'fol4   :s1 0 :s2 0 :s3 0 :s4 0))
    (alloc-probe "FOL 8-slot"   n (make-instance 'fol8   :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (format t "  [FOL persistent-class — overflow path, > 8 user slots]~%")
    (alloc-probe "FOL 12-slot (overflow)" n
      (make-instance 'fol12 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                            :s9 0 :s10 0 :s11 0 :s12 0))
    (alloc-probe "FOL 16-slot (overflow)" n
      (make-instance 'fol16 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                            :s9 0 :s10 0 :s11 0 :s12 0 :s13 0 :s14 0 :s15 0 :s16 0))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Live-set GC pressure (1M objects retained simultaneously)
;;;; ─────────────────────────────────────────────────────────────────────────

(defun report-gc-pressure ()
  (format t "~%=== Live-set GC pressure (N=1,000,000 live objects) ===~%")
  (format t "    (Total allocation during construction; all objects retained)~%")
  (let ((n 1000000))
    (format t "~%  [Struct]~%")
    (gc-pressure "struct 2-slot"   n (make-st2 :s1 0 :s2 0))
    (gc-pressure "struct 8-slot"   n (make-st8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (format t "  [CLOS]~%")
    (gc-pressure "CLOS 2-slot"     n (make-instance 'clos2 :s1 0 :s2 0))
    (gc-pressure "CLOS 8-slot"     n (make-instance 'clos8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (format t "  [FOL native]~%")
    (gc-pressure "FOL 2-slot"      n (make-instance 'fol2 :s1 0 :s2 0))
    (gc-pressure "FOL 8-slot"      n (make-instance 'fol8 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0))
    (format t "  [FOL overflow]~%")
    (gc-pressure "FOL 12-slot"     n
      (make-instance 'fol12 :s1 0 :s2 0 :s3 0 :s4 0 :s5 0 :s6 0 :s7 0 :s8 0
                            :s9 0 :s10 0 :s11 0 :s12 0))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Main
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%CLOS Identity Memory Tax Benchmark~%")
(format t "~60,,,'-<~>~%")
(format t "Environment: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))

(report-exact-sizes)
(report-throughput)
(report-gc-pressure)

(format t "~%Done.~%")
(sb-ext:exit)
