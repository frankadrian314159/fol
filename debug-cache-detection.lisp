;;; Debug script to understand what lambda-form looks like after compile-fn

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

(format t "~%=== Debugging Lambda-Form Structure ===~%~%")

;; Create a defn-node and compile it
(let ((clauses (fol-form '(
  (#(x)
   (cond
     ((integer? x) (* x 2))
     ((string? x) (str x "!"))
     ((vector? x) (count x))
     ((float? x) (* x 3.0))
     (t "unknown")))))))

  (format t "Input clauses:~%")
  (format t "~A~%~%" clauses)

  ;; Call compile-fn to get the lambda-form
  (let ((lambda-form (fol.compiler:compile-fn clauses)))
    (format t "After compile-fn:~%")
    (format t "Lambda form: ~A~%~%" lambda-form)
    (format t "Params: ~A~%" (second lambda-form))
    (format t "Body: ~A~%~%" (cddr lambda-form))

    ;; Check if first body element is a declare
    (let ((first-body (first (cddr lambda-form))))
      (format t "First body element: ~A~%" first-body)
      (format t "Is declare: ~A~%" (and (consp first-body) (eq (first first-body) 'cl:declare)))
      (format t "~%"))))

(quit)
