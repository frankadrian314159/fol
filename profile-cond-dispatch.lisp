;;; Analyze COND dispatch compilation in different Lisps
;;; Disassembles code to show instruction sequences and call overhead

(defun dispatch-6clause-cond (x)
  "6-clause COND dispatch for profiling"
  (cond
    ((typep x 'fixnum) :fixnum)
    ((stringp x) :string)
    ((listp x) :list)
    ((vectorp x) :vector)
    ((symbolp x) :symbol)
    (t :other)))

(defun dispatch-6clause-ifnested (x)
  "Nested IF dispatch (alternative)"
  (if (typep x 'fixnum)
    :fixnum
    (if (stringp x)
      :string
      (if (listp x)
        :list
        (if (vectorp x)
          :vector
          (if (symbolp x)
            :symbol
            :other))))))

(defun call-dispatch-cached (x cache-fn-map)
  "Simulates cached dispatch with funcall"
  (let* ((key (class-of x))
         (fn (gethash key cache-fn-map)))
    (if fn
      (funcall fn x)
      :miss)))

(defun measure-dispatch-overhead (x n-iterations)
  "Measure raw dispatch overhead"
  (let ((start (get-internal-run-time)))
    (dotimes (i n-iterations)
      (dispatch-6clause-cond x))
    (let ((elapsed (- (get-internal-run-time) start)))
      (float (/ elapsed internal-time-units-per-second)))))

(defun profile-dispatch ()
  "Profile and analyze dispatch implementation"
  (let ((lisp-name (lisp-implementation-type))
        (lisp-version (lisp-implementation-version)))

    (format t "~&=== COND Dispatch Compilation Profile ===~%")
    (format t "Implementation: ~A ~A~%" lisp-name lisp-version)
    (format t "~%")

    ;; Section 1: Disassembly (if supported)
    (format t "--- Assembly Analysis ---~%")
    #+sbcl
    (progn
      (format t "SBCL disassembly available~%")
      (format t "~&Function: DISPATCH-6CLAUSE-COND~%")
      (disassemble 'dispatch-6clause-cond)
      (format t "~&Function: DISPATCH-6CLAUSE-IFNESTED~%")
      (disassemble 'dispatch-6clause-ifnested))

    #+ccl
    (progn
      (format t "CCL disassembly available (limited)~%")
      (format t "~&Note: CCL's disassembler shows Lisp-level info, not x86 assembly~%")
      (format t "~&Function: DISPATCH-6CLAUSE-COND~%")
      (disassemble 'dispatch-6clause-cond))

    #-(or sbcl ccl)
    (format t "Disassembly not supported on this implementation~%")

    ;; Section 2: Performance measurement
    (format t "~&~%--- Performance Analysis ---~%")
    (let ((test-value 42)
          (n-iterations 1000000))
      (format t "Measuring dispatch overhead (~D iterations on fixnum)~%" n-iterations)
      (let ((cond-time (measure-dispatch-overhead test-value n-iterations)))
        (format t "  COND dispatch: ~,3F seconds~%" cond-time)
        (format t "  Per-call: ~,1F microseconds~%"
                (* cond-time 1000000 (/ 1 n-iterations)))))

    ;; Section 3: Compilation flags and optimizations
    (format t "~&~%--- Compilation Environment ---~%")
    #+sbcl
    (progn
      (format t "SBCL optimization settings:~%")
      (format t "  (Available via declare/declaim)~%")
      (format t "  Backend: x86-64 native code compiler~%")
      (format t "  Features: ~A~%" (subseq (format nil "~A" *features*) 0 100)))

    #+ccl
    (progn
      (format t "CCL compilation settings:~%")
      (format t "  (CCL settings available via declaim/declare)~%")
      (format t "  Backend: Both 32-bit and 64-bit native code~%"))

    #-(or sbcl ccl)
    (format t "Compilation environment info not available~%")

    ;; Section 4: Dispatch chain analysis
    (format t "~&~%--- Dispatch Chain Characteristics ---~%")
    (let ((test-values (list 42 "string" '(a b) #(1 2 3) 'symbol :keyword)))
      (format t "Testing ~D different types:~%" (length test-values))
      (dolist (val test-values)
        (let ((result (dispatch-6clause-cond val))
              (type-name (type-of val)))
          (format t "  ~12A → ~A~%" type-name result))))

    ;; Section 5: Summary
    (format t "~&~%=== Analysis Complete ===~%")))

(defun compare-lisp-implementations ()
  "Print info to compare across Lisps"
  (format t "~&=== Lisp Implementation Comparison ===~%")
  (format t "Name:    ~A~%" (lisp-implementation-type))
  (format t "Version: ~A~%" (lisp-implementation-version))
  (format t "Derived: ~A~%" (lisp-implementation-type))

  #+sbcl
  (format t "~%SBCL-specific features:~%  - Near-optimal COND compilation~%  - x86-64 backend~%  - Disassemble support~%")

  #+ccl
  (format t "~%CCL-specific features:~%  - Lisp-based compiler~%  - Both 32 and 64-bit support~%  - JIT compilation available~%")

  #-(or sbcl ccl)
  (format t "~%This Lisp implementation not specifically profiled~%"))

;; Run profiling
(profile-dispatch)
(compare-lisp-implementations)
(quit)
