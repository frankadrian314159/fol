;;; Benchmark: Storage options for ordered-set
;;;
;;; An ordered set needs:
;;;   - O(1) or O(log n) membership check (for deduplication on conj)
;;;   - Insertion preserving order
;;;   - Iteration in insertion order
;;;
;;; Candidates:
;;;   1. FSet seq only         — membership via linear scan
;;;   2. FSet seq + Syc hash-set — compound: O(1) membership + ordered seq
;;;   3. FSet seq + FSet wb-set  — compound: O(log n) membership + ordered seq
;;;
;;; Operations benchmarked:
;;;   - CREATE: build ordered set from N elements
;;;   - CONJ:   add one element (not already present)
;;;   - MEMBER: check membership of an existing element
;;;   - SEQ:    convert to list (iterate in order)

(require :fset)
(require :sycamore)

(defun bench-create-seq-only (n)
  "Build an ordered set of N elements using FSet seq only."
  (loop with seq = (fset:empty-seq)
        for i below n
        do (setf seq (fset:with-last seq i))
        finally (return seq)))

(defun bench-create-seq+hashset (n)
  "Build an ordered set of N elements using FSet seq + Sycamore hash-set."
  (loop with seq = (fset:empty-seq)
        with hset = (sycamore:make-hash-set)
        for i below n
        do (setf seq (fset:with-last seq i))
           (setf hset (sycamore:hash-set-insert hset i))
        finally (return (cons hset seq))))

(defun bench-create-seq+wbset (n)
  "Build an ordered set of N elements using FSet seq + FSet wb-set."
  (loop with seq = (fset:empty-seq)
        with wbset = (fset:empty-set)
        for i below n
        do (setf seq (fset:with-last seq i))
           (setf wbset (fset:with wbset i))
        finally (return (cons wbset seq))))

(defun bench-member-seq-only (seq elem)
  "Membership check on FSet seq via linear scan."
  (fset:do-seq (x seq)
    (when (eql x elem)
      (return-from bench-member-seq-only t)))
  nil)

(defun bench-member-seq+hashset (pair elem)
  "Membership check on compound (hash-set . seq)."
  (sycamore:hash-set-find (car pair) elem))

(defun bench-member-seq+wbset (pair elem)
  "Membership check on compound (wb-set . seq)."
  (fset:contains? (car pair) elem))

(defun bench-conj-seq-only (seq elem)
  "Add elem to FSet seq (no dedup check)."
  (fset:with-last seq elem))

(defun bench-conj-seq+hashset (pair elem)
  "Add elem to compound (hash-set . seq)."
  (cons (sycamore:hash-set-insert (car pair) elem)
        (fset:with-last (cdr pair) elem)))

(defun bench-conj-seq+wbset (pair elem)
  "Add elem to compound (wb-set . seq)."
  (cons (fset:with (car pair) elem)
        (fset:with-last (cdr pair) elem)))

(defun bench-seq-seq-only (seq)
  "Convert FSet seq to list."
  (fset:convert 'list seq))

(defun bench-seq-seq+hashset (pair)
  "Convert compound (hash-set . seq) to list."
  (fset:convert 'list (cdr pair)))

(defun bench-seq-seq+wbset (pair)
  "Convert compound (wb-set . seq) to list."
  (fset:convert 'list (cdr pair)))

;;; ---------------------------------------------------------------------------
;;; Timing harness
;;; ---------------------------------------------------------------------------

(defun time-it (thunk iterations)
  "Run THUNK ITERATIONS times, return elapsed real-time in seconds."
  (let ((start (get-internal-real-time)))
    (dotimes (i iterations)
      (funcall thunk))
    (/ (- (get-internal-real-time) start)
       (float internal-time-units-per-second))))

(defun run-benchmarks ()
  (let ((iterations 100000)
        (sizes '(5 50 500)))
    (format t "~%=== Ordered-Set Storage Benchmarks ===~%")
    (format t "Iterations per operation: ~:D~%~%" iterations)
    (dolist (n sizes)
      (format t "--- Size: ~D elements ---~%~%" n)
      ;; Pre-build structures
      (let* ((seq-only (bench-create-seq-only n))
             (seq+hset (bench-create-seq+hashset n))
             (seq+wbset (bench-create-seq+wbset n))
             (mid (floor n 2))
             (new-elem (+ n 1)))

        ;; CREATE
        (format t "CREATE (~D elements):~%" n)
        (let ((t1 (time-it (lambda () (bench-create-seq-only n)) (floor iterations 10)))
              (t2 (time-it (lambda () (bench-create-seq+hashset n)) (floor iterations 10)))
              (t3 (time-it (lambda () (bench-create-seq+wbset n)) (floor iterations 10))))
          (format t "  seq-only:      ~8,4F s~%" t1)
          (format t "  seq+hash-set:  ~8,4F s~%" t2)
          (format t "  seq+wb-set:    ~8,4F s~%" t3)
          (format t "  ratio (seq-only / seq+hash-set): ~,2F~%" (/ t1 t2))
          (format t "  ratio (seq+wb-set / seq+hash-set): ~,2F~%~%" (/ t3 t2)))

        ;; MEMBER (look up middle element)
        (format t "MEMBER (element ~D):~%" mid)
        (let ((t1 (time-it (lambda () (bench-member-seq-only seq-only mid)) iterations))
              (t2 (time-it (lambda () (bench-member-seq+hashset seq+hset mid)) iterations))
              (t3 (time-it (lambda () (bench-member-seq+wbset seq+wbset mid)) iterations)))
          (format t "  seq-only:      ~8,4F s~%" t1)
          (format t "  seq+hash-set:  ~8,4F s~%" t2)
          (format t "  seq+wb-set:    ~8,4F s~%" t3)
          (format t "  ratio (seq-only / seq+hash-set): ~,2F~%" (/ t1 t2))
          (format t "  ratio (seq+wb-set / seq+hash-set): ~,2F~%~%" (/ t3 t2)))

        ;; CONJ (add a new element)
        (format t "CONJ (add element ~D):~%" new-elem)
        (let ((t1 (time-it (lambda () (bench-conj-seq-only seq-only new-elem)) iterations))
              (t2 (time-it (lambda () (bench-conj-seq+hashset seq+hset new-elem)) iterations))
              (t3 (time-it (lambda () (bench-conj-seq+wbset seq+wbset new-elem)) iterations)))
          (format t "  seq-only:      ~8,4F s~%" t1)
          (format t "  seq+hash-set:  ~8,4F s~%" t2)
          (format t "  seq+wb-set:    ~8,4F s~%" t3)
          (format t "  ratio (seq-only / seq+hash-set): ~,2F~%" (/ t1 t2))
          (format t "  ratio (seq+wb-set / seq+hash-set): ~,2F~%~%" (/ t3 t2)))

        ;; SEQ (convert to list)
        (format t "SEQ (to list):~%")
        (let ((t1 (time-it (lambda () (bench-seq-seq-only seq-only)) iterations))
              (t2 (time-it (lambda () (bench-seq-seq+hashset seq+hset)) iterations))
              (t3 (time-it (lambda () (bench-seq-seq+wbset seq+wbset)) iterations)))
          (format t "  seq-only:      ~8,4F s~%" t1)
          (format t "  seq+hash-set:  ~8,4F s~%" t2)
          (format t "  seq+wb-set:    ~8,4F s~%" t3)
          (format t "  ratio (seq-only / seq+hash-set): ~,2F~%" (/ t1 t2))
          (format t "  ratio (seq+wb-set / seq+hash-set): ~,2F~%~%" (/ t3 t2)))
        (format t "~%")))))

(run-benchmarks)
