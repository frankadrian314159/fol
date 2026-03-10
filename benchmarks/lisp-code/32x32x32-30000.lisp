(in-package :lsim-cl)

;; 32x32x32 pipeline: 32 parallel copies of 32 cascaded 32-bit registers
;; Total: 32 * 32 * 32 = 32,768 registers (~131,072 NAND gates)
;; Running for 30000 time steps.

;; Module definitions
(register-module 'sr-latch
                 (make-instance 'module-def
                   :name 'sr-latch
                   :ports '(r s q qbar)
                   :body '((nand nand1 :in1 s :in2 qbar :out q)
                           (nand nand2 :in1 r :in2 q :out qbar))))

(register-module 'd-latch
                 (make-instance 'module-def
                   :name 'd-latch
                   :ports '(clk d q qbar)
                   :body '((nand nand1 :in1 d :in2 clk :out s)
                           (nand nand2 :in1 s :in2 clk :out r)
                           (sr-latch latch :r r :s s :q q :qbar qbar))))

(register-module 'register-32bit
                 (make-instance 'module-def
                   :name 'register-32bit
                   :ports '(clk
                            d0 d1 d2 d3 d4 d5 d6 d7
                            d8 d9 d10 d11 d12 d13 d14 d15
                            d16 d17 d18 d19 d20 d21 d22 d23
                            d24 d25 d26 d27 d28 d29 d30 d31
                            q0 q1 q2 q3 q4 q5 q6 q7
                            q8 q9 q10 q11 q12 q13 q14 q15
                            q16 q17 q18 q19 q20 q21 q22 q23
                            q24 q25 q26 q27 q28 q29 q30 q31)
                   :body '((d-latch bit0 :clk clk :d d0 :q q0 :qbar qbar0)
                           (d-latch bit1 :clk clk :d d1 :q q1 :qbar qbar1)
                           (d-latch bit2 :clk clk :d d2 :q q2 :qbar qbar2)
                           (d-latch bit3 :clk clk :d d3 :q q3 :qbar qbar3)
                           (d-latch bit4 :clk clk :d d4 :q q4 :qbar qbar4)
                           (d-latch bit5 :clk clk :d d5 :q q5 :qbar qbar5)
                           (d-latch bit6 :clk clk :d d6 :q q6 :qbar qbar6)
                           (d-latch bit7 :clk clk :d d7 :q q7 :qbar qbar7)
                           (d-latch bit8 :clk clk :d d8 :q q8 :qbar qbar8)
                           (d-latch bit9 :clk clk :d d9 :q q9 :qbar qbar9)
                           (d-latch bit10 :clk clk :d d10 :q q10 :qbar qbar10)
                           (d-latch bit11 :clk clk :d d11 :q q11 :qbar qbar11)
                           (d-latch bit12 :clk clk :d d12 :q q12 :qbar qbar12)
                           (d-latch bit13 :clk clk :d d13 :q q13 :qbar qbar13)
                           (d-latch bit14 :clk clk :d d14 :q q14 :qbar qbar14)
                           (d-latch bit15 :clk clk :d d15 :q q15 :qbar qbar15)
                           (d-latch bit16 :clk clk :d d16 :q q16 :qbar qbar16)
                           (d-latch bit17 :clk clk :d d17 :q q17 :qbar qbar17)
                           (d-latch bit18 :clk clk :d d18 :q q18 :qbar qbar18)
                           (d-latch bit19 :clk clk :d d19 :q q19 :qbar qbar19)
                           (d-latch bit20 :clk clk :d d20 :q q20 :qbar qbar20)
                           (d-latch bit21 :clk clk :d d21 :q q21 :qbar qbar21)
                           (d-latch bit22 :clk clk :d d22 :q q22 :qbar qbar22)
                           (d-latch bit23 :clk clk :d d23 :q q23 :qbar qbar23)
                           (d-latch bit24 :clk clk :d d24 :q q24 :qbar qbar24)
                           (d-latch bit25 :clk clk :d d25 :q q25 :qbar qbar25)
                           (d-latch bit26 :clk clk :d d26 :q q26 :qbar qbar26)
                           (d-latch bit27 :clk clk :d d27 :q q27 :qbar qbar27)
                           (d-latch bit28 :clk clk :d d28 :q q28 :qbar qbar28)
                           (d-latch bit29 :clk clk :d d29 :q q29 :qbar qbar29)
                           (d-latch bit30 :clk clk :d d30 :q q30 :qbar qbar30)
                           (d-latch bit31 :clk clk :d d31 :q q31 :qbar qbar31))))

;; pipeline-32x32: 32 cascaded 32-bit registers
(register-module 'pipeline-32x32
                 (make-instance 'module-def
                   :name 'pipeline-32x32
                   :ports (let ((ports '(clk)))
                            (dotimes (i 32) (push (intern (format nil "D~D" i)) ports))
                            (dotimes (i 32) (push (intern (format nil "Q~D" i)) ports))
                            (nreverse ports))
                   :body
                   (let ((body '()))
                     (dotimes (stage 32 (nreverse body))
                       (let ((spec (list 'register-32bit
                                         (intern (format nil "REG~D" stage))
                                         :clk 'clk)))
                         (dotimes (bit 32)
                           (let* ((dk (intern (format nil "D~D" bit) :keyword))
                                  (qk (intern (format nil "Q~D" bit) :keyword))
                                  (d-wire (if (= stage 0)
                                              (intern (format nil "D~D" bit))
                                              (intern (format nil "S~DQ~D" (1- stage) bit))))
                                  (q-wire (if (= stage 31)
                                              (intern (format nil "Q~D" bit))
                                              (intern (format nil "S~DQ~D" stage bit)))))
                             (setf spec (append spec (list dk d-wire qk q-wire)))))
                         (push spec body))))))

;; Top module: 32 parallel pipelines
(register-module 'top32x32x32
                 (make-instance 'module-def
                   :name 'top32x32x32
                   :ports '()
                   :body
                   (let ((body '()))
                     (dotimes (p-idx 32 (nreverse body))
                       (let ((spec (list 'pipeline-32x32
                                         (intern (format nil "PIPE~D" p-idx))
                                         :clk 'clk)))
                         (dotimes (bit 32)
                           (let* ((dk (intern (format nil "D~D" bit) :keyword))
                                  (qk (intern (format nil "Q~D" bit) :keyword))
                                  (d-wire (intern (format nil "D~D" bit)))
                                  (q-wire (intern (format nil "P~DQ~D" p-idx bit))))
                             (setf spec (append spec (list dk d-wire qk q-wire)))))
                         (push spec body))))))

;; Monitor final outputs (all 32 pipelines)
(let ((nodes '()))
  (dotimes (p-idx 32)
    (dotimes (bit-idx 32)
      (push (intern (format nil "P~DQ~D" p-idx bit-idx)) nodes)))
  (apply #'monitor-nodes (nreverse nodes)))

;; Pattern helpers
(defun add-p1 (time-val)
  (apply #'add-events
    (loop for i from 0 below 32
          collect (make-sim-event :time time-val
                                  :node (intern (format nil "D~D" i))
                                  :value (if (evenp i) 1 0)))))

(defun add-p2 (time-val)
  (apply #'add-events
    (loop for i from 0 below 32
          collect (make-sim-event :time time-val
                                  :node (intern (format nil "D~D" i))
                                  :value (if (evenp i) 0 1)))))

;; Data events: 30000 steps, alternate patterns every 10 steps (3000 changes)
(dotimes (k 3000)
  (if (evenp k)
      (add-p1 (* k 10))
      (add-p2 (* k 10))))

;; Clock events: high at 3+10k, low at 8+10k, for k=0..2999
(dotimes (k 3000)
  (add-events
   (make-sim-event :time (+ 3 (* k 10)) :node 'clk :value 1)
   (make-sim-event :time (+ 8 (* k 10)) :node 'clk :value 0)))

;; Run simulation
(defun run-bench ()
  (run-lsim 'top32x32x32 30000))
