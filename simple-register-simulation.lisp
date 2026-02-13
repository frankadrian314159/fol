;;; Simple 8-bit Register Simulation - Direct CL Implementation
;;; This demonstrates the D-latch based register without relying on the transpiler.

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :simple-sim
  (:use :cl))

(in-package :simple-sim)

;;; D-Latch Model
;;; When CLK=1 (high), output Q follows input D
;;; When CLK=0 (low), output Q holds previous value

(defstruct latch
  (q nil)           ; Current output
  (d nil)           ; Data input
  (clk nil))        ; Clock input

(defun latch-update (latch new-d new-clk)
  "Update latch with new inputs. Returns new output value."
  (setf (latch-d latch) new-d)
  (setf (latch-clk latch) new-clk)
  ;; If clock is high, Q follows D; otherwise Q holds
  (when new-clk
    (setf (latch-q latch) new-d))
  (latch-q latch))

;;; 8-bit Register (8 D-latches sharing a clock)

(defstruct register-8bit
  (latches (make-array 8 :initial-element nil)))

(defun make-8bit-register ()
  (let ((reg (make-register-8bit)))
    (dotimes (i 8)
      (setf (aref (register-8bit-latches reg) i) (make-latch)))
    reg))

(defun register-update (reg data-bits clk)
  "Update all 8 latches with DATA-BITS (list of 8 booleans) and CLK.
   Returns list of 8 output bits."
  (loop for i from 0 to 7
        for d in data-bits
        for latch = (aref (register-8bit-latches reg) i)
        collect (latch-update latch d clk)))

;;; Simulation

(format t "~%=== 8-bit Register Simulation ===~%~%")

(let ((reg (make-8bit-register)))

  ;; T=0: Set inputs to 10101010 (0xAA)
  ;; Bit order: (bit0 bit1 bit2 bit3 bit4 bit5 bit6 bit7) = LSB to MSB
  ;; 0xAA = 10101010 binary = bit7=1, bit6=0, bit5=1, bit4=0, bit3=1, bit2=0, bit1=1, bit0=0
  (format t "T=0: Setting inputs to 10101010 (0xAA), CLK=0~%")
  (let ((outputs (register-update reg '(nil t nil t nil t nil t) nil)))
    (format t "     Outputs: ~{~A~}~%" (mapcar (lambda (x) (if x 1 0)) (reverse outputs))))

  ;; T=5: Clock high (latches capture 0xAA)
  (format t "~%T=5: Clock goes HIGH (latches capture data)~%")
  (let ((outputs (register-update reg '(nil t nil t nil t nil t) t)))
    (format t "     Outputs: ~{~A~} (should be 10101010 = 0xAA)~%"
            (mapcar (lambda (x) (if x 1 0)) (reverse outputs))))

  ;; T=10: Clock low (latches hold value)
  (format t "~%T=10: Clock goes LOW (latches hold value)~%")
  (let ((outputs (register-update reg '(nil t nil t nil t nil t) nil)))
    (format t "      Outputs: ~{~A~} (still 10101010 = 0xAA)~%"
            (mapcar (lambda (x) (if x 1 0)) (reverse outputs))))

  ;; T=15: Change data to 01010101 (0x55), clock still low
  ;; 0x55 = 01010101 binary = bit7=0, bit6=1, bit5=0, bit4=1, bit3=0, bit2=1, bit1=0, bit0=1
  (format t "~%T=15: Changing inputs to 01010101 (0x55), CLK=0~%")
  (let ((outputs (register-update reg '(t nil t nil t nil t nil) nil)))
    (format t "      Outputs: ~{~A~} (still 10101010, latches holding)~%"
            (mapcar (lambda (x) (if x 1 0)) (reverse outputs))))

  ;; T=20: Clock high again (latches capture new value 0x55)
  (format t "~%T=20: Clock goes HIGH (latches capture new data)~%")
  (let ((outputs (register-update reg '(t nil t nil t nil t nil) t)))
    (format t "      Outputs: ~{~A~} (should be 01010101 = 0x55)~%"
            (mapcar (lambda (x) (if x 1 0)) (reverse outputs))))

  ;; T=25: Clock low
  (format t "~%T=25: Clock goes LOW (latches hold value)~%")
  (let ((outputs (register-update reg '(t nil t nil t nil t nil) nil)))
    (format t "      Outputs: ~{~A~} (still 01010101 = 0x55)~%~%"
            (mapcar (lambda (x) (if x 1 0)) (reverse outputs)))))

(format t "~%=== Simulation Complete ===~%~%")
(format t "Interpretation:~%")
(format t "  - D-latches are level-sensitive storage elements~%")
(format t "  - When CLK=1 (high), output Q follows input D~%")
(format t "  - When CLK=0 (low), output Q holds its previous value~%")
(format t "  - The 8-bit register captured 0xAA at T=5 and 0x55 at T=20~%~%")

(sb-ext:quit)
