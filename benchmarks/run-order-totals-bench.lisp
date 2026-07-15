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

(load "benchmarks/lisp-code/order-totals.lisp")
(load "benchmarks/transpiled-fol-code/order-totals.lisp")
(load "benchmarks/transpiled-fol-code/order-totals-unprovable.lisp")

(in-package :cl-user)

;; NOTE: the order-totals-cl package is created by the load forms above; both
;; FOL benchmarks live directly in fol.core (no custom package -- see
;; order-totals.fol's own header comment for why). IDE "package does not
;; exist" warnings below are false positives identical to those in
;; run-derived-value-invalidation-bench.lisp.

(defun bench-one (label fn n)
  (funcall fn) ; warm up
  (sb-ext:gc :full t)
  (let ((s (get-internal-real-time))
        (b (sb-ext:get-bytes-consed)))
    (let ((result (funcall fn)))
      (let ((tm (/ (- (get-internal-real-time) s)
                   (float internal-time-units-per-second)))
            (mem (- (sb-ext:get-bytes-consed) b)))
        (format t "~A~%" label)
        (format t "  Result:       ~D~%" result)
        (format t "  Real Time:    ~,4F s~%" tm)
        (format t "  Bytes Consed: ~,2F MB~%" (/ mem 1048576.0))
        (format t "  Time/order:   ~,1F ns~%~%" (* (/ tm n) 1e9))
        (values tm mem result)))))

(defun run-benchmarks ()
  (let ((n 1000000))
    (format t "~%================================================================~%")
    (format t "  Order Totals Benchmark~%")
    (format t "  Pattern: build one fresh <order> per iteration, sum 3 fields~%")
    (format t "  Unlike DVI's cart, the record is never loop-carried -- born~%")
    (format t "  and read within one iteration, so BUILD-ORDER's constructor~%")
    (format t "  call proves ORDER-TOTAL's parameter type interprocedurally~%")
    (format t "  (interprocedural-types.lisp), compiling its three keyword-~%")
    (format t "  accessor reads to direct, world-guarded SLOT-VALUE. The~%")
    (format t "  UNPROVABLE variant is an identical control (same loop shape,~%")
    (format t "  same work) where BUILD-ORDER2 is deliberately multi-clause,~%")
    (format t "  putting it out of the analysis's scope, so ORDER2-TOTAL's~%")
    (format t "  reads stay on the generic dispatch GET path -- isolating the~%")
    (format t "  GET-bypass's own contribution from everything else.~%")
    (format t "  N = ~:D orders~%" n)
    (format t "================================================================~%~%")

    (multiple-value-bind (t-cl m-cl)
        (bench-one "--- Common Lisp (native struct, direct slot access) ---"
                   (lambda () (order-totals-cl:sum-orders n)) n)
      (multiple-value-bind (t-prov m-prov r-prov)
          (bench-one "--- FOL, provable (SLOT-VALUE bypass fires) ---"
                     (lambda () (fol.core::sum-orders n)) n)
        (multiple-value-bind (t-unprov m-unprov r-unprov)
            (bench-one "--- FOL, unprovable control (generic GET) ---"
                       (lambda () (fol.core::sum-orders2 n)) n)
          (format t "--- Comparison ---~%")
          (format t "  provable/CL       Time: ~,2Fx  Memory: ~,2Fx~%"
                  (/ t-prov t-cl) (/ (float m-prov) (float m-cl)))
          (format t "  unprovable/CL     Time: ~,2Fx  Memory: ~,2Fx~%"
                  (/ t-unprov t-cl) (/ (float m-unprov) (float m-cl)))
          (format t "  unprovable/provable  Time: ~,2Fx  Memory: ~,2Fx  (the GET-bypass's own contribution)~%"
                  (/ t-unprov t-prov) (/ (float m-unprov) (float m-prov)))
          (if (= r-prov r-unprov)
              (format t "  Correctness:  PASS (both FOL variants return ~D)~%" r-prov)
              (format t "  Correctness:  FAIL (provable=~D, unprovable=~D)~%" r-prov r-unprov))))))
  (format t "~%Done.~%"))

(handler-case
    (run-benchmarks)
  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
