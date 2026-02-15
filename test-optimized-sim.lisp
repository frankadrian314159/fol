;;; Minimal test of hand-optimized run-simulation-optimized
;;; Tests just the core simulation loop without module expansion complexity

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :fol-sim-test
  (:use :cl))

(in-package :fol-sim-test)

;; Load just what we need from lsim-cl-optimized
(load "fol-code/lsim-cl-optimized.lisp")

;; Create a simple test netlist manually
(defun make-simple-netlist ()
  "Create a minimal netlist with one NOT gate for testing."
  (let ((not-gate
         (make-instance 'fol-sim:<logic-component>
                       :name 'not1
                       :type 'not
                       :connections (sycamore:hash-map-insert
                                    (sycamore:hash-map-insert (sycamore:make-hash-map)
                                                             :in 'a)
                                    :out 'b)
                       :inputs (apply #'fol.compiler.collections:make
                                     'fol.compiler.collections:<vector>
                                     '(:in))
                       :outputs (apply #'fol.compiler.collections:make
                                      'fol.compiler.collections:<vector>
                                      '(:out))
                       :delays (sycamore:hash-map-insert (sycamore:make-hash-map)
                                                        :in
                                                        (sycamore:hash-map-insert (sycamore:make-hash-map)
                                                                                 :out 1))
                       :logic-fn (lambda (inputs)
                                   (sycamore:hash-map-insert (sycamore:make-hash-map)
                                                            :out
                                                            (not (sycamore:hash-map-find inputs :in)))))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (list not-gate))))

;; Create test events
(defun make-test-events ()
  (apply #'fol.compiler.collections:make
         'fol.compiler.collections:<vector>
         (list (sycamore:hash-map-insert
                (sycamore:hash-map-insert
                 (sycamore:hash-map-insert (sycamore:make-hash-map)
                                          :time 0)
                 :node 'a)
                :value t)
               (sycamore:hash-map-insert
                (sycamore:hash-map-insert
                 (sycamore:hash-map-insert (sycamore:make-hash-map)
                                          :time 5)
                 :node 'a)
                :value nil))))

(format t "~%Testing hand-optimized simulation loop...~%")
(let ((netlist (make-simple-netlist))
      (events (make-test-events))
      (monitored (sycamore:hash-set-insert (sycamore:make-hash-set) 'b)))

  (format t "Netlist: ~A~%" netlist)
  (format t "Events: ~A~%" events)
  (format t "Monitored: ~A~%" monitored)

  (handler-case
      (let ((result (fol-sim:run-simulation-optimized netlist events 10 monitored)))
        (format t "~%Success! Result: ~A~%" result))
    (error (e)
      (format t "~%Error: ~A~%" e))))

(sb-ext:quit)
