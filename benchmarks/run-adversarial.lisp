(require :asdf)
(asdf:load-system :fol)

(defun cl-qsort (arr low high)
  (when (< low high)
        (let ((pivot (aref arr high))
              (i (1- low)))
          (loop for j from low below high do
                  (when (<= (aref arr j) pivot)
                        (incf i)
                        (rotatef (aref arr i) (aref arr j))))
          (incf i)
          (rotatef (aref arr i) (aref arr high))
          (cl-qsort arr low (1- i))
          (cl-qsort arr (1+ i) high)))
  arr)

(defun run-cl-qsort (n)
  (let ((arr (make-array n)))
    (loop for i from 0 below n do (setf (aref arr i) (random 100000)))
    (time (cl-qsort arr 0 (1- n)))))

(fol.compiler:compile-and-load-string "
(defn partition [v low high]
  (bind [pivot (get v high)]
    (loop [j low, i (- low 1), curr-v v]
      (if (< j high)
        (if (<= (get curr-v j) pivot)
          (bind [next-i (+ i 1)
                 temp (get curr-v next-i)
                 v1 (assoc curr-v next-i (get curr-v j))
                 v2 (assoc v1 j temp)]
            (recur (+ j 1) next-i v2))
          (recur (+ j 1) i curr-v))
        (bind [next-i (+ i 1)
               temp (get curr-v next-i)
               v1 (assoc curr-v next-i (get curr-v high))
               v2 (assoc v1 high temp)]
          [v2 next-i])))))

(defn qsort [v low high]
  (if (< low high)
    (bind [[v-part p] (partition v low high)
           v-left (qsort v-part low (- p 1))]
      (qsort v-left (+ p 1) high))
    v))
" :package :fol-user)

(defun run-fol-qsort (n)
  (let ((arr (fol-user::vec)))
    (loop for i from 0 below n do (setf arr (fol-user::conj arr (random 100000))))
    (time (fol-user::qsort arr 0 (1- n)))))

(format t \"~%--- QSort 10k ---\~%\")
(format t \"CL:~%\")
(run-cl-qsort 10000)
(format t \"FOL:~%\")
(run-fol-qsort 10000)

(format t \"~%--- QSort 20k ---\~%\")
(format t \"CL:~%\")
(run-cl-qsort 20000)
(format t \"FOL:~%\")
(run-fol-qsort 20000)
