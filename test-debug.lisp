(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :test (:use :cl))
(in-package :test)

(format t "Line 1~%") (force-output)
(format t "Line 2~%") (force-output)
(format t "About to sleep...~%") (force-output)
(sleep 1)
(format t "Done sleeping~%") (force-output)

(sb-ext:quit)
