with open('macro.lisp') as f:
    text = f.read()

lines = text.split('\n')

insert_symbols = [
    '         (trans-name (%pvec-mk-sym "TRANSIENT-~A" name))',
    '         (make-trans (%pvec-mk-sym "MAKE-TRANSIENT-~A" name))',
    '         (trans-name-p (%pvec-mk-sym "TRANSIENT-~A-P" name))',
    '         (trans-conc (%pvec-mk-sym "TRANS-~A-" name))',
    '         (trans-count (%pvec-mk-sym "TRANS-~A-COUNT" name))',
    '         (trans-shift (%pvec-mk-sym "TRANS-~A-SHIFT" name))',
    '         (trans-root (%pvec-mk-sym "TRANS-~A-ROOT" name))',
    '         (trans-tail (%pvec-mk-sym "TRANS-~A-TAIL" name))',
    '         (trans-token (%pvec-mk-sym "TRANS-~A-TOKEN" name))',
    '         ',
    '         (api-transient (%pvec-mk-sym "TRANSIENT-~A" name))',
    '         (api-transient-conj (%pvec-mk-sym "TRANSIENT-~A-CONJ!" name))',
    '         (api-transient-persistent (%pvec-mk-sym "TRANSIENT-~A-PERSISTENT!" name))'
]

lines = lines[:20] + insert_symbols + lines[20:]
out_text = '\n'.join(lines)

insert_struct = '''
       (defstruct (,trans-name (:constructor ,make-trans)
                               (:predicate ,trans-name-p)
                               (:conc-name ,trans-conc))
         (count 0 :type fixnum)
         (shift 0 :type fixnum)
         (root #() :type ,root-type)
         (tail ,make-tail-empty :type ,tail-type)
         (token nil))

       (defun ,api-transient (v)
         (let* ((token (cons nil nil))
                (cnt (,count-acc v))
                (persistent-tail (,tail-acc v))
                (tail (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)))))
           (replace tail persistent-tail)
           (,make-trans :count cnt
                        :shift (,shift-acc v)
                        :root (,root-acc v)
                        :tail tail
                        :token token)))

       (defun ,api-transient-conj (tv val)
         (unless (,trans-token tv) (error "Transient used after persistent! call"))
         (declare ,@(when (not (eq element-type 't)) `((type ,element-type val))) (optimize (speed 3) (safety 0)))
         (let* ((cnt (,trans-count tv)))
           (when (and (> cnt 0) (zerop (logand cnt 31)))
             (let ((root (,trans-root tv))
                   (shift (,trans-shift tv))
                   (node-to-push (,trans-tail tv)))
               (let ((new-tail (make-array 32 ,@(when (not (eq element-type 't)) `(:element-type ',element-type)))))
                 (setf (,trans-tail tv) new-tail))
               (cond
                ((zerop (length root))
                  (let ((new-root (make-array +branch-factor+)))
                    (setf (svref new-root 0) node-to-push)
                    (setf (,trans-root tv) new-root)
                    (setf (,trans-shift tv) +bit-shift+)))
                ((> (ash cnt (- +bit-shift+)) (ash 1 shift))
                  (let ((new-root (make-array +branch-factor+ :initial-element nil)))
                    (setf (svref new-root 0) root)
                    (setf (svref new-root 1) (,new-path shift node-to-push))
                    (setf (,trans-root tv) new-root)
                    (setf (,trans-shift tv) (+ shift +bit-shift+))))
                (t
                  (setf (,trans-root tv) (,push-tail shift root (1- cnt) node-to-push))))))
           (let ((tail-idx (logand cnt 31)))
             (setf (,accessor (,trans-tail tv) tail-idx) val)
             (incf (,trans-count tv))
             tv)))

       (defun ,api-transient-persistent (tv)
         (unless (,trans-token tv) (error "Transient used after persistent! call"))
         (setf (,trans-token tv) nil)
         (let* ((cnt (,trans-count tv))
                (tail (,trans-tail tv))
                (real-tail-len (if (zerop cnt) 0 (1+ (logand (1- cnt) 31))))
                (frozen-tail (make-array real-tail-len ,@(when (not (eq element-type 't)) `(:element-type ',element-type)))))
           (replace frozen-tail tail :end1 real-tail-len :end2 real-tail-len)
           (,make-name :count cnt
                       :shift (,trans-shift tv)
                       :root (,trans-root tv)
                       :tail frozen-tail)))
'''

out_text = out_text.replace('(defparameter ,empty-vec (,make-name))', insert_struct + '\n       (defparameter ,empty-vec (,make-name))')

with open('macro2.lisp', 'w') as out:
    out.write(out_text)
