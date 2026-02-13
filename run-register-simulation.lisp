;;; Run the 8-bit register simulation
;;; This script loads the simulator, the register design, and runs the test

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create a simple package for the simulator
(defpackage :fol-sim
  (:use :cl)
  (:import-from :fol.compiler.mutable
                deref reset! swap! compare-and-set!
                <atom> <atom>? ref <ref> <ref>?)
  (:import-from :fol.compiler.collection-functions
                dict size empty?)
  (:import-from :fol.compiler.collections
                <vector> <dict> <set> <bag>)
  (:import-from :fol.compiler.primitives
                truthy? falsy?)
  (:shadowing-import-from :fol.compiler.mutable atom)
  (:shadowing-import-from :fol.compiler.collection-functions
                vector set bag first rest get assoc dissoc conj))

(in-package :fol-sim)

;; Unlock CL package to allow loading transpiled code with special variables
(sb-ext:unlock-package :cl)

(format t "~%Loading FOL simulator (lsim.lisp)...~%")
(load "fol-code/lsim.lisp")

(format t "Loading 8-bit register design (register-8bit.lisp)...~%")
(load "fol-code/register-8bit.lisp")

(format t "~%Setting up simulation...~%")

;; Helper to create dict
(defun make-event (time node value)
  (fol.compiler.collection-functions:dict :time time :node node :value value))

;; Monitor all output bits
(funcall monitor 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)

;; Set up test events as described in register-8bit.fol:
;; T=0: Set data inputs to binary 10101010 (0xAA)
(funcall events
  (make-event 0 'in0 nil)      ; bit 0 = 0
  (make-event 0 'in1 t)        ; bit 1 = 1
  (make-event 0 'in2 nil)      ; bit 2 = 0
  (make-event 0 'in3 t)        ; bit 3 = 1
  (make-event 0 'in4 nil)      ; bit 4 = 0
  (make-event 0 'in5 t)        ; bit 5 = 1
  (make-event 0 'in6 nil)      ; bit 6 = 0
  (make-event 0 'in7 t)        ; bit 7 = 1

  ;; T=5: Pulse clock high (latches should capture 0xAA)
  (make-event 5 'clk t)

  ;; T=10: Clock low (latches hold value)
  (make-event 10 'clk nil)

  ;; T=15: Change data to binary 01010101 (0x55)
  (make-event 15 'in0 t)       ; bit 0 = 1
  (make-event 15 'in1 nil)     ; bit 1 = 0
  (make-event 15 'in2 t)       ; bit 2 = 1
  (make-event 15 'in3 nil)     ; bit 3 = 0
  (make-event 15 'in4 t)       ; bit 4 = 1
  (make-event 15 'in5 nil)     ; bit 5 = 0
  (make-event 15 'in6 t)       ; bit 6 = 1
  (make-event 15 'in7 nil)     ; bit 7 = 0

  ;; T=20: Pulse clock high again (should latch new value 0x55)
  (make-event 20 'clk t)

  ;; T=25: Clock low
  (make-event 25 'clk nil))

(format t "~%Running simulation for 30 time units...~%")

;; Run simulation
(funcall run 'test-register-8bit 30)

(format t "~%Simulation complete!~%")
(format t "~%=== Simulation Results ===~%")

;; Display results for all output bits
(funcall display 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)

(format t "~%~%=== Interpretation ===~%")
(format t "Expected behavior:~%")
(format t "  T=0-4:   Inputs set but no clock edge yet~%")
(format t "  T=8-14:  After CLK→Q delay (~~4 units), outputs show 0xAA (10101010)~%")
(format t "  T=15-19: Inputs change to 0x55 but outputs hold 0xAA (clock is low)~%")
(format t "  T=23+:   After second clock pulse + delay, outputs show 0x55 (01010101)~%")

(quit)
