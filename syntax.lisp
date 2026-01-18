(in-package fol.syntax)


(defun read-fol-dict (stream char)
  "Reader macro for FOL dictionaries. 
   Reads syntax like {key1 val1 key2 val2} (whitespace separated) and transforms 
   it into a call to (fol.collection:make-dict key1 val1 key2 val2)."
  (declare (ignore char))
  (let ((items '()))
    (loop
      ;; Peek for next char, skipping whitespace (standard Lisp behavior)
      (let ((c (peek-char t stream t nil t))) 
        (cond
          ;; Closing brace: finish and return the constructor form
          ((char= c #\})
           (read-char stream)
           (return))
          
          ;; Read a key-value pair
          (t
           (let ((key (read stream t nil t))
                 (val (read stream t nil t)))
             (push key items)
             (push val items))))))
    
    ;; Construct the form: (fol.collection:make-dict key1 val1 ...)
    (cons 'fol.collection:make-dict (nreverse items))))

(defun read-fol-bag (stream subchar arg)
  "Reader macro for FOL bags: #M{ item1 item2 ... }
   Reads a list of elements and expands into (make-bag item1 item2 ...)"
  (declare (ignore subchar arg))
  ;; Verify we are at a '{'
  (let ((c (read-char stream t nil t)))
    (unless (char= c #\{)
      (error "Expected '{' following #M")))
  
  (let ((items '()))
    (loop
      (let ((c (peek-char t stream t nil t)))
        (cond
          ;; Closing brace
          ((char= c #\})
           (read-char stream)
           (return))
          
          ;; Read an item (Standard READ handles #\c, "str", #t, 123, etc.)
          (t
           (push (read stream t nil t) items)))))
    
    ;; Construct form: (fol.collection:make-bag item1 item2 ...)
    (cons 'fol.collection:make-bag (nreverse items))))

(defun read-fol-set (stream subchar arg)
  "Reader macro for FOL sets: #{ ... }"
  (declare (ignore subchar arg))
  ;; Use read-delimited-list to read until the closing '}'
  ;; This returns the list of elements directly.
  (let ((items (read-delimited-list #\} stream t)))
    (cons 'fol.collection:make-set items)))

(defun read-fol-vector (stream char)
  "Reader macro for FOL vectors: [ item1 item2 ... ]"
  (declare (ignore char))
  ;; Read elements until closing ']'
  (let ((items (read-delimited-list #\] stream t)))
    (cons 'fol.collection:make-vector items)))

(defreadtable fol-syntax
  (:merge :standard)
  ;; Boolean Literals
  (:dispatch-macro-char #\# #\t (lambda (s c a) (declare (ignore s c a)) 'fol.singleton::*true-instance*))
  (:dispatch-macro-char #\# #\f (lambda (s c a) (declare (ignore s c a)) 'fol.singleton::*false-instance*))
  
  ;; Dictionary Literals { ... }
  (:macro-char #\{ #'read-fol-dict)
  (:macro-char #\} (get-macro-character #\}))
  
  ;; Bag Literals #M{ ... }
  (:dispatch-macro-char #\# #\M #'read-fol-bag)

  ;; Set Literals #{ ... }
  (:dispatch-macro-char #\# #\{ #'read-fol-set)
  
  ;; Vector Literals [ ... ]
  (:macro-char #\[ #'read-fol-vector)
  (:macro-char #\] (get-macro-character #\))))