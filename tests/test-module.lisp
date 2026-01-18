(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test module-creation
  "Test creation of <module> objects"
  (let ((m (fol.module:make-module 'x 10 'y 20)))
    (is (typep m 'fol.module:<module>))
    (is (unwrap (fol.module:<module>? m)))
    
    ;; Inheritance checks
    (is (unwrap (fol.collection:<dict>? m)))
    (is (unwrap (fol.collection:<collection>? m)))))

(test module-generic-ops
  "Test that generic collection operations work on modules"
  (let ((m (fol.module:make-module :a 1)))
    ;; Size
    (is (= 1 (fol.collection:size m)))
    
    ;; Add (Functional update)
    (let ((m2 (fol.collection:add m :b 2)))
      (is (= 2 (fol.collection:size m2)))
      (is (= 1 (fol.collection:size m))) ; Original unchanged
      (is (unwrap (fol.collection:contains? m2 :b))))
    
    ;; Get
    (let ((items (fol.persistent:pslot-value m 'fol.collection::items)))
      (is (= 1 (fset:lookup items :a))))))

(test module-printing
  "Test module printer"
  (let ((m (fol.module:make-module 'k 'v)))
    (let ((str (format nil "~A" m)))
      (is (search "#<MODULE {" str))
      (is (search "'K 'V" str)))))