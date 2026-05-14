;;; Debug script to see what compile-fn actually produces
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defun fol-form (form)
  "Recursively convert CL vectors in FORM to FOL <vector> instances."
  (cond
   ((and (cl:vectorp form) (not (stringp form)))
     (apply #'fol.compiler.collection-functions:vector
       (map 'list #'fol-form form)))
   ((consp form)
     (cons (fol-form (car form)) (fol-form (cdr form))))
   (t form)))

(format t "~%=== Testing compile-fn Output ===~%~%")

;; Test 1: Simple type dispatch
(let ((clauses (fol-form '(
  (#(x)
   (cond
     ((integer? x) (* x 2))
     ((string? x) (str x "!"))
     ((vector? x) (count x))
     ((float? x) (* x 3.0))
     (t "unknown")))))))

  (format t "Input clauses:~%~S~%~%" clauses)

  (let ((lambda-form (fol.compiler::compile-fn clauses)))
    (format t "After compile-fn:~%~S~%~%" lambda-form)
    (format t "~%Analyzing structure:~%")
    (format t "  Lambda? ~A~%" (eq (first lambda-form) 'cl:lambda))
    (format t "  Params: ~A~%" (second lambda-form))
    (format t "  Body length: ~A~%" (length (cddr lambda-form)))
    (let* ((raw-body (cddr lambda-form))
           (first-body (first raw-body)))
      (format t "  First body element: ~A~%" first-body)
      (format t "  Is declare: ~A~%" (and (consp first-body) (eq (first first-body) 'cl:declare)))
      (let ((cond-form (if (and (consp first-body) (eq (first first-body) 'cl:declare))
                          (second raw-body)
                          first-body)))
        (format t "  Cond form: ~A~%" cond-form)
        (format t "  Is cond: ~A~%" (and (consp cond-form) (eq (first cond-form) 'cl:cond)))
        (when (and (consp cond-form) (eq (first cond-form) 'cl:cond))
          (format t "  Number of clauses: ~A~%" (length (rest cond-form)))
          (format t "  First 3 clauses:~%")
          (loop for i from 0 to 2
                when (< i (length (rest cond-form)))
                do (format t "    [~A] ~A~%" i (nth i (rest cond-form)))))))))

(quit)
