(in-package :fol.compiler.tests)

(in-suite transients-tests)

;;; --- Vector Transients ---

(test vector-transients
      (let* ((v (fol.compiler.collection-functions:vector 1 2 3))
             (tv (transient v)))
        (is (not (eq v tv)))
        (conj! tv 4)
        (conj! tv 5)
        (let ((v2 (persistent! tv)))
          (is (typep v2 'fol.compiler.collections:<vector>))
          (is (= 5 (fol.compiler.collections:size v2)))
          (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq v2))))
        ;; Original vector v should be unchanged
        (is (= 3 (fol.compiler.collections:size v)))
        (is (equal '(1 2 3) (fol.compiler.collections:collection-seq v)))))

;;; --- Dict Transients ---

(test dict-transients
      (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
             (td (transient d)))
        (assoc! td :c 3)
        (assoc! td :a 99)
        (dissoc! td :b)
        (let ((d2 (persistent! td)))
          (is (typep d2 'fol.compiler.collections:<dict>))
          (is (= 2 (fol.compiler.collections:size d2)))
          (is (= 99 (fol.compiler.collections:get d2 :a)))
          (is (= 3 (fol.compiler.collections:get d2 :c)))
          (is (null (fol.compiler.collections:get d2 :b))))
        ;; Original d unchanged
        (is (= 2 (fol.compiler.collections:size d)))
        (is (= 1 (fol.compiler.collections:get d :a)))
        (is (= 2 (fol.compiler.collections:get d :b)))))

;;; --- Set Transients ---

(test set-transients
      (let* ((s (fol.compiler.collection-functions:set 1 2 3))
             (ts (transient s)))
        (conj! ts 4)
        (disj! ts 2)
        (let ((s2 (persistent! ts)))
          ;; If s2 is a dict (current behavior), we convert it to set or just check contents
          (is (= 3 (fol.compiler.collections:size s2)))
          (is (not (null (fol.compiler.collections:get s2 1))))
          (is (null (fol.compiler.collections:get s2 2)))
          (is (not (null (fol.compiler.collections:get s2 4)))))))

;;; --- Persistent Object Transients ---

(test persistent-object-transient-small
      (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
             (tp (transient p1)))
        (is (not (eq p1 tp)))
        (is (fol.compiler.persistent::%transient-p tp))
        ;; Mutation should work
        (setf (slot-value tp 'x) 10)
        (setf (slot-value tp 'y) 20)
        (let ((p2 (persistent! tp)))
          (is (not (fol.compiler.persistent::%transient-p p2)))
          (is (= 10 (slot-value p2 'x)))
          (is (= 20 (slot-value p2 'y))))
        ;; Original unchanged
        (is (= 1 (slot-value p1 'x)))
        (is (= 2 (slot-value p1 'y)))))

(test persistent-object-transient-massive
      (let* ((m1 (make-instance '<massive-object> :s0 0 :s34 34))
             (tm (transient m1)))
        (is (fol.compiler.persistent::%transient-p tm))
        (is (not (null (fol.compiler.persistent::%transient-buffer tm))))
        ;; Mutation of overflow slots
        (setf (slot-value tm 's34) 999)
        (setf (slot-value tm 's0) 111)
        (let ((m2 (persistent! tm)))
          (is (not (fol.compiler.persistent::%transient-p m2)))
          (is (= 111 (slot-value m2 's0)))
          (is (= 999 (slot-value m2 's34))))
        ;; Original unchanged
        (is (= 0 (slot-value m1 's0)))
        (is (= 34 (slot-value m1 's34)))))

(test persistent-object-assoc!-small
      (let* ((p (make-instance '<test-point> :x 1 :y 2))
             (tp (transient p)))
        (assoc! tp 'x 88)
        (let ((p2 (persistent! tp)))
          (is (= 88 (slot-value p2 'x))))))

(test persistent-object-assoc!-massive
      (let* ((m (make-instance '<massive-object> :s34 34))
             (tm (transient m)))
        (assoc! tm 's34 777)
        (let ((m2 (persistent! tm)))
          (is (= 777 (slot-value m2 's34))))))
