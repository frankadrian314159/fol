;;; FOL Compiler - Merged Functions
;;;
;;; Contains polymorphic functions that dispatch to different implementations
;;; based on their argument types. Currently handles:
;;; - join: String join (separator coll) or relational natural join (xrel yrel)

(in-package :fol.compiler.merged-functions)

(defun %relational-join (xrel yrel &optional km)
  "Natural join of two relations (sets of dicts).
   Returns the set of all dicts formed by merging an element of XREL and
   an element of YREL that share the same values for their common keys.
   If KM is supplied, it maps keys in XREL to corresponding keys in YREL."
  (let ((xseq (fol.compiler.collections:collection-seq xrel))
        (yseq (fol.compiler.collections:collection-seq yrel)))
    (if km
        ;; Keyed join: KM maps xrel-key -> yrel-key
        (let ((km-seq (fol.compiler.collections:collection-seq
                       (fol.compiler.seq-functions:keys km)))
              (result (fol.compiler.collection-functions:set)))
          (dolist (x xseq result)
            (dolist (y yseq)
              (when (every (lambda (xk)
                             (let ((yk (fol.compiler.collection-functions:get km xk)))
                               (equal (fol.compiler.collection-functions:get x xk)
                                      (fol.compiler.collection-functions:get y yk))))
                        km-seq)
                    (setf result (fol.compiler.collection-functions:conj
                                  result
                                  (fol.compiler.collection-functions:merge x y)))))))
        ;; Natural join: find shared keys from first elements
        (if (or (null xseq) (null yseq))
            (fol.compiler.collection-functions:set)
            (let* ((x-keys (fol.compiler.collections:collection-seq
                            (fol.compiler.seq-functions:keys (cl:first xseq))))
                   (y-keys (fol.compiler.collections:collection-seq
                            (fol.compiler.seq-functions:keys (cl:first yseq))))
                   (shared (cl:intersection x-keys y-keys :test #'equal))
                   (result (fol.compiler.collection-functions:set)))
              (dolist (x xseq result)
                (dolist (y yseq)
                  (when (every (lambda (k)
                                 (equal (fol.compiler.collection-functions:get x k)
                                        (fol.compiler.collection-functions:get y k)))
                            shared)
                        (setf result (fol.compiler.collection-functions:conj
                                      result
                                      (fol.compiler.collection-functions:merge x y)))))))))))

(defun join (&rest args)
  "Polymorphic join function.
   - If args are (separator collection), performs string join.
   - If args are (xrel yrel &optional km), performs relational natural join."
  (let ((arg1 (first args))
        (arg2 (second args))
        (arg3 (third args))
        (nargs (length args)))
    (declare (ignore arg3))
    (cond
     ;; Case 1: String join (separator coll)
     ((and (= nargs 2)
           (or (stringp arg1) (characterp arg1)))
       (let ((separator (if (characterp arg1) (string arg1) arg1))
             (seq (if (listp arg2)
                      arg2
                      (fol.compiler.collections:collection-seq arg2))))
         (if (null seq)
             ""
             (apply #'fol.compiler.string-functions:str
               (cons (cl:first seq)
                     (mapcan (lambda (x) (cl:list separator x))
                         (cl:rest seq)))))))

     ;; Case 2: Relational join (xrel yrel &optional km)
     ((and (>= nargs 2)
           (<= nargs 3)
           (or (typep arg1 'fol.compiler.collections:<collection>) (listp arg1))
           (or (typep arg2 'fol.compiler.collections:<collection>) (listp arg2)))
       (apply #'%relational-join (cl:subseq args 0 nargs)))

     (t
       (error "Invalid arguments to join: ~S. Expected (str/char coll) or (coll coll [dict])." args)))))

(defun replace (&rest args)
  "Polymorphic replace function.
   - If args are (smap coll), where smap is a dict and coll is an ordered-collection,
     returns a new collection of the same type with keys in smap replaced by values.
   - If args are (s match replacement &key use-regex), performs string replacement.
     match can be a character or string. generic regex logic is applied if specified."
  (let ((nargs (length args)))
    (cond
     ;; Case 1: Collection replacement (smap coll)
     ((and (= nargs 2)
           (typep (first args) 'fol.compiler.collections:<dict>)
           (typep (second args) 'fol.compiler.collections:<ordered-collection>))
       (let* ((smap (first args))
              (coll (second args))
              (seq (fol.compiler.collections:collection-seq coll))
              (smap-items (fol.compiler.collections:storage-items smap))
              (new-seq (mapcar (lambda (elem)
                                 (multiple-value-bind (replacement found)
                                     (sycamore:hash-map-find smap-items elem)
                                   (if found replacement elem)))
                           seq)))
         (apply #'fol.compiler.collections:make
           (class-name (class-of coll))
           new-seq)))

     ;; Case 2: String replacement (s match replacement &key use-regex)
     ((and (>= nargs 3)
           (stringp (first args))
           (or (stringp (second args)) (characterp (second args)))
           (stringp (third args)))
       (let ((s (first args))
             (match (second args))
             (replacement (third args))
             (use-regex (let ((k (member :use-regex (cdddr args))))
                          (and k (cadr k)))))
         (cond
          ((characterp match)
            ;; Character match
            (if use-regex
                (cl-ppcre:regex-replace-all (string match) s replacement)
                (with-output-to-string (out)
                  (loop for c across s
                        do (if (char= c match)
                               (write-string replacement out)
                               (write-char c out))))))
          ((stringp match)
            ;; String match
            (if use-regex
                ;; Regex replacement using CL-PPCRE
                (cl-ppcre:regex-replace-all match s replacement)
                ;; Literal string replacement
                (let ((result s)
                      (match-len (length match)))
                  (loop
                   (let ((pos (search match result)))
                     (if pos
                         (setf result (concatenate 'string
                                        (subseq result 0 pos)
                                        replacement
                                        (subseq result (+ pos match-len))))
                         (return result))))))))))

     (t
       (error "Invalid arguments to replace: ~S. Expected (dict ordered-coll) or (string match replacement &key use-regex)." args)))))
