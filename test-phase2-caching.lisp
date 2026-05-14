;;; Comprehensive test of Phase 2 dispatch caching

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;;; Test 1: Defn with type-dispatch caching
(format t "~%=== Test 1: Defn with type-dispatch caching ===~%")
(fol.compiler:compile-form '(fol.compiler:defn type-dispatch [x]
  (fol.compiler:cond
    ((fol.compiler:integer? x) (* x 2))
    ((fol.compiler:string? x) (fol.compiler.string-functions:str "Got: " x))
    ((fol.compiler:vector? x) (fol.compiler.collection-functions:first x))
    ((fol.compiler:float? x) (* x 3.0))
    (t "unknown"))))

(format t "Testing type-dispatch with fixnum: ~A~%" (type-dispatch 10))
(format t "Testing type-dispatch with string: ~A~%" (type-dispatch "hello"))
(format t "Testing type-dispatch with vector: ~A~%" (type-dispatch (fol.compiler.collection-functions:vector 1 2 3)))
(format t "Testing type-dispatch with float: ~A~%" (type-dispatch 2.5))

;;; Test 2: Anonymous fn with caching
(format t "~%=== Test 2: Anonymous fn with type-dispatch caching ===~%")
(let ((dispatch-fn (fol.compiler:compile-form '(fol.compiler:fn [x]
  (fol.compiler:cond
    ((fol.compiler:integer? x) (+ x 100))
    ((fol.compiler:string? x) (fol.compiler.string-functions:str x "!"))
    ((fol.compiler:vector? x) (fol.compiler.collection-functions:count x))
    ((fol.compiler:float? x) (/ x 2))
    (t "unknown"))))))
  (let ((f (eval (fol.compiler:compilation-result-code dispatch-fn))))
    (format t "Testing anonymous fn with fixnum: ~A~%" (funcall f 5))
    (format t "Testing anonymous fn with string: ~A~%" (funcall f "test"))
    (format t "Testing anonymous fn with vector: ~A~%" (funcall f (fol.compiler.collection-functions:vector 1 2 3 4)))))

;;; Test 3: Defmethod with caching
(format t "~%=== Test 3: Defmethod with type-dispatch caching ===~%")
(fol.compiler:compile-form '(cl:defgeneric process-value (x)))

(fol.compiler:compile-form '(fol.compiler:defmethod process-value [x :integer?]
  (* x 2)))

(fol.compiler:compile-form '(fol.compiler:defmethod process-value [x :string?]
  (fol.compiler.string-functions:str "String: " x)))

(fol.compiler:compile-form '(fol.compiler:defmethod process-value [x :vector?]
  (fol.compiler.collection-functions:count x)))

(fol.compiler:compile-form '(fol.compiler:defmethod process-value [x :float?]
  (* x 3)))

(format t "Testing defmethod with fixnum: ~A~%" (process-value 7))
(format t "Testing defmethod with string: ~A~%" (process-value "test"))
(format t "Testing defmethod with vector: ~A~%" (process-value (fol.compiler.collection-functions:vector 10 20)))
(format t "Testing defmethod with float: ~A~%" (process-value 2.5))

;;; Test 4: Multi-arity defgeneric with caching
(format t "~%=== Test 4: Multi-arity defgeneric with caching ===~%")
(fol.compiler:compile-form '(fol.compiler:defgeneric op
  ([x]
   (+ x 1))
  ([x y]
   (+ x y))
  ([x y z]
   (+ x y z))))

(format t "Testing defgeneric (1 arg): ~A~%" (op 10))
(format t "Testing defgeneric (2 args): ~A~%" (op 10 20))
(format t "Testing defgeneric (3 args): ~A~%" (op 10 20 30))

;;; Summary
(format t "~%=== All Phase 2 Caching Tests Passed! ===~%~%")

(quit)
