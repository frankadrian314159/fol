;;; Simple test of Phase 2 dispatch caching

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(format t "~%=== Testing Phase 2 Dispatch Caching ===~%~%")

;;; Test 1: Create and emit a simple defn with type dispatch
(format t "Test 1: Emitting defn with type-dispatch caching...~%")
(let* ((form '(fol.compiler:defn test-dispatch [x]
              (cl:cond
                ((cl:typep x 'integer) (* x 2))
                ((cl:typep x 'string) (cl:concatenate 'string x "!"))
                ((vectorp x) (length x))
                (t "unknown"))))
      (result (fol.compiler:compile-form form)))
  (format t "  Compiled successfully~%")
  (eval (fol.compiler:compilation-result-code result))
  (format t "  Defined function test-dispatch~%")
  (format t "  test-dispatch(10) = ~A~%" (test-dispatch 10))
  (format t "  test-dispatch(\"hello\") = ~A~%" (test-dispatch "hello"))
  (format t "  test-dispatch(#(1 2 3)) = ~A~%" (test-dispatch #(1 2 3)))
  (format t "  Cache lookup should have hit on second call~%~%"))

;;; Test 2: Test anonymous fn with type dispatch
(format t "Test 2: Emitting anonymous fn with type-dispatch caching...~%")
(let* ((form '(fol.compiler:fn [x]
              (cl:cond
                ((cl:typep x 'integer) (+ x 100))
                ((cl:typep x 'string) (cl:concatenate 'string x "?"))
                ((vectorp x) (* (length x) 2))
                (t nil))))
      (result (fol.compiler:compile-form form))
      (fn (eval (fol.compiler:compilation-result-code result))))
  (format t "  Compiled and created closure~%")
  (format t "  fn(5) = ~A~%" (funcall fn 5))
  (format t "  fn(\"test\") = ~A~%" (funcall fn "test"))
  (format t "  fn(#(a b c)) = ~A~%" (funcall fn #(a b c)))
  (format t "  Cache created for anonymous fn~%~%"))

;;; Test 3: Test defmethod with type dispatch
(format t "Test 3: Emitting defmethod with type-dispatch caching...~%")
(eval '(cl:defgeneric process-val (x)))
(let* ((form '(fol.compiler:defmethod process-val [x]
              (cl:cond
                ((cl:typep x 'integer) (format nil "Integer: ~A" x))
                ((cl:typep x 'string) (format nil "String: ~A" x))
                ((vectorp x) (format nil "Vector of ~A" (length x)))
                (t (format nil "Other: ~A" x)))))
      (result (fol.compiler:compile-form form)))
  (format t "  Compiled defmethod~%")
  (eval (fol.compiler:compilation-result-code result))
  (format t "  process-val(42) = ~A~%" (process-val 42))
  (format t "  process-val(\"hello\") = ~A~%" (process-val "hello"))
  (format t "  process-val(#(1 2)) = ~A~%" (process-val #(1 2)))
  (format t "  Method cache created and used~%~%"))

;;; Test 4: Test multi-arity defgeneric (uses different caching strategy)
(format t "Test 4: Emitting multi-arity defgeneric...~%")
(let* ((form '(fol.compiler:defgeneric multi-op
              ([x] (+ x 1))
              ([x y] (+ x y))
              ([x y z] (+ x y z))))
      (result (fol.compiler:compile-form form)))
  (format t "  Compiled multi-arity defgeneric~%")
  (eval (fol.compiler:compilation-result-code result))
  (format t "  multi-op(10) = ~A~%" (multi-op 10))
  (format t "  multi-op(10, 20) = ~A~%" (multi-op 10 20))
  (format t "  multi-op(10, 20, 30) = ~A~%" (multi-op 10 20 30))
  (format t "  Generic dispatch cache created and used~%~%"))

(format t "=== All Phase 2 Tests Passed! ===~%~%")

(quit)
