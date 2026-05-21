;;; Test value-predicate reference-type handling

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.compiler)

(format t "~%Testing value-predicate reference-type handling:~%")

;; Test 1: Type dispatch - should be cacheable
(let ((type-dispatch-form
       '(lambda (x)
          (cl:cond
            ((cl:typep x 'cl:fixnum) 1)
            ((cl:typep x 'cl:string) 2)
            ((cl:typep x 'cl:vector) 3)
            ((cl:typep x 'cl:list) 4)
            (t 5)))))
  (format t "Type dispatch form: ~A~%" (cacheable-defn-p type-dispatch-form)))

;; Test 2: Value dispatch on eql-comparable (fixnums) - should be cacheable
(let ((eql-dispatch-form
       '(lambda (x)
          (cl:cond
            ((cl:= x 1) "one")
            ((cl:= x 2) "two")
            ((cl:= x 3) "three")
            ((cl:= x 4) "four")
            (t "other")))))
  (format t "Value dispatch on fixnums: ~A~%" (cacheable-defn-p eql-dispatch-form)))

;; Test 3: Value dispatch on reference types - should NOT be cacheable
(let ((ref-dispatch-form
       '(lambda (x obj1 obj2 obj3 obj4)
          (cl:cond
            ((cl:eq x obj1) "A")
            ((cl:eq x obj2) "B")
            ((cl:eq x obj3) "C")
            ((cl:eq x obj4) "D")
            (t "other")))))
  (let ((result (cacheable-defn-p ref-dispatch-form)))
    (format t "Value dispatch on reference types (eq x obj): ~A~%" result)
    (if result
        (format t "  ERROR: Should NOT be cacheable (reference-type conflict)~%")
        (format t "  OK: Not cacheable (avoids reference-type cache conflicts)~%"))))

;; Test 4: Mixed type checks - should be cacheable if pure type
(let ((mixed-form
       '(lambda (x y)
          (cl:cond
            ((and (cl:typep x 'cl:fixnum) (cl:typep y 'cl:string)) "F+S")
            ((and (cl:typep x 'cl:string) (cl:typep y 'cl:fixnum)) "S+F")
            ((and (cl:typep x 'cl:fixnum) (cl:typep y 'cl:fixnum)) "F+F")
            ((and (cl:typep x 'cl:string) (cl:typep y 'cl:string)) "S+S")
            (t "other")))))
  (format t "Mixed type checks: ~A~%" (cacheable-defn-p mixed-form)))

;; Test 5: Verify the detection function directly
(format t "~%Testing has-reference-type-value-predicates-p directly:~%")
(let ((ref-cond '(cl:cond
                   ((cl:eq x obj1) "A")
                   ((cl:eq x obj2) "B")
                   ((cl:eq x obj3) "C")
                   ((cl:eq x obj4) "D")
                   (t "other"))))
  (format t "  Reference-type predicates detected: ~A~%"
          (has-reference-type-value-predicates-p ref-cond '(x))))

(format t "~%Value-predicate reference-type handling test completed!~%")
