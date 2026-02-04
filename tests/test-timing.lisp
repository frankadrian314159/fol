(in-package :fol.integration-tests)

(def-suite timing-suite :in integration-suite)
(def-suite* :timing-tests :in timing-suite)

;;; ---------------------------------------------------------------------------
;;; %time% Macro Tests
;;; ---------------------------------------------------------------------------

(test %time%-test
  "Test %time% macro returns correct values and prints timing."
  ;; Basic return value test
  (fol-is 42 "(%time% 42)")
  ;; Expression evaluation
  (fol-is 10 "(%time% (+ 3 7))")
  ;; Multiple expressions - returns last value
  (fol-is 3 "(%time% 1 2 3)")
  ;; Works with function calls
  (fol-is 15 "(%time% (reduce + [1 2 3 4 5]))")
  ;; Works with bind
  (fol-is 100 "(%time% (bind [x 10] (* x x)))"))

;;; ---------------------------------------------------------------------------
;;; Multi-Pattern Dispatch Timing Tests
;;; ---------------------------------------------------------------------------

(test multi-pattern-dispatch-timing
  "Test %time% with multi-pattern generic function dispatch."
  ;; Define and test multi-pattern dispatch with predicates
  ;; Use a fresh env for each test to avoid conflicts
  (let* ((env (make-standard-module)))
    ;; Define the generic function
    (fol-eval (fol.reader:fol-read-from-string
               "(defgeneric process ([a]
                                     [a & (b (< 10))]
                                     [a & (b <number>) (c <string>)]
                                     [a & b c]))")
              env)
    ;; Define multi-clause method
    (fol-eval (fol.reader:fol-read-from-string
               "(defmethod process
                  ([a] 50)
                  ([a (b (< 10))] (* 2 b))
                  ([a (b <number>) (c <string>)] c)
                  ([a b c] :error))")
              env)
    ;; Run timing tests - output goes to stdout
    (format t "~&~%--- FOL Multi-Pattern Dispatch Timing ---~%")
    (format t "10000 iterations with 1-arg pattern:~%")
    (fol-eval (fol.reader:fol-read-from-string "(%time% (dotimes [_ 1000000] (process 0)))") env)
    (format t "10000 iterations with predicate pattern (< 10):~%")
    (fol-eval (fol.reader:fol-read-from-string "(%time% (dotimes [_ 1000000] (process 0 5)))") env)
    (format t "10000 iterations with type pattern (number string):~%")
    (fol-eval (fol.reader:fol-read-from-string "(%time% (dotimes [_ 1000000] (process 0 0 \"abc\")))") env)
    (format t "10000 iterations with fallback pattern:~%")
    (fol-eval (fol.reader:fol-read-from-string "(%time% (dotimes [_ 1000000] (process 0 0 0)))") env)
    (pass)))
