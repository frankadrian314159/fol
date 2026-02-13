;;; Test that the funcall fix works correctly

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defun test-funcall-emission ()
  "Test that calling a lexically bound function emits funcall."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (fol-code '(bind [f (fn [x] (* x 2))]
                          (f 5)))
         (result (fol.compiler:compile-form fol-code))
         (code (fol.compiler:compilation-result-code result)))
    (format t "~%FOL code:  ~S~%" fol-code)
    (format t "Compiled:  ~S~%~%" code)
    ;; Check that code contains FUNCALL
    (let ((code-string (format nil "~S" code)))
      (if (search "FUNCALL" code-string)
          (format t "✓ SUCCESS: funcall was emitted correctly!~%")
          (format t "✗ FAILURE: funcall was NOT emitted!~%")))))

(test-funcall-emission)
(sb-ext:quit)
