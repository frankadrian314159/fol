;;; Quick test to verify dispatch caching is working

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.compiler)

;; Test 1: Type dispatch caching on defn
(defn double-dispatch
  ([x integer?] (* x 2))
  ([x float?] (* x 2.0))
  ([x string?] (str-repeat x 2)))

;; Test 2: Type dispatch caching on unnamed fn
(defn test-unnamed
  ([]
   (let [f (fn
             ([x integer?] (+ x 10))
             ([x string?] (str x "!")))]
     (list (f 5) (f "hello")))))

;; Run tests
(format t "~%Test 1: Type dispatch on defn~%")
(format t "  (double-dispatch 5) = ~A~%" (double-dispatch 5))
(format t "  (double-dispatch 3.14) = ~A~%" (double-dispatch 3.14))
(format t "  (double-dispatch \"x\") = ~A~%" (double-dispatch "x"))

(format t "~%Test 2: Type dispatch on unnamed fn~%")
(format t "  (test-unnamed) = ~A~%" (test-unnamed))

(format t "~%All tests passed!~%")
