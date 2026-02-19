(require :asdf)
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(format t "~%--- START LOAD ---~%")
(load "transpiled-fol-code/compliance.lisp")
(format t "--- END LOAD ---~%")

(format t "~%--- RESULTS ---~%")
(let ((comp-fn (find-symbol "COMPLIANCE" "test-compliance")))
  (if comp-fn
      (funcall comp-fn)
      (format t "Error: test-compliance::compliance not found~%")))
(format t "~%--- DONE ---~%")
(sb-ext:quit)
