(in-package :fol.tests)

(def-suite stream-suite :in fol-suite)
(def-suite* :fol.stream-tests :in stream-suite)

;;; ============================================================================
;;; Type Predicates
;;; ============================================================================

(test stream-type-predicates
  "Test stream type predicates."
  (let ((str-in (make-string-input-stream "test"))
        (str-out (make-string-output-stream)))
    ;; String input stream
    (is-true (<stream>? str-in))
    (is-true (<input-stream>? str-in))
    (is-true (<string-input-stream>? str-in))
    (is-false (<output-stream>? str-in))
    (is-false (<file-input-stream>? str-in))
    ;; String output stream
    (is-true (<stream>? str-out))
    (is-true (<output-stream>? str-out))
    (is-true (<string-output-stream>? str-out))
    (is-false (<input-stream>? str-out))
    (is-false (<file-output-stream>? str-out))))

;;; ============================================================================
;;; Stream State
;;; ============================================================================

(test stream-initial-state
  "Test that streams are created in closed state."
  (let ((str-in (make-string-input-stream "test"))
        (str-out (make-string-output-stream)))
    (is-true (stream-closed? str-in))
    (is-false (stream-open? str-in))
    (is-true (stream-closed? str-out))
    (is-false (stream-open? str-out))))

(test stream-open-close
  "Test opening and closing streams."
  (let ((str-in (make-string-input-stream "test")))
    ;; Initially closed
    (is-true (stream-closed? str-in))
    ;; Open it
    (open str-in)
    (is-true (stream-open? str-in))
    (is-false (stream-closed? str-in))
    ;; Close it
    (close str-in)
    (is-true (stream-closed? str-in))
    (is-false (stream-open? str-in))))

(test stream-double-open-error
  "Test that opening an already open stream signals an error."
  (let ((str-in (make-string-input-stream "test")))
    (open str-in)
    (signals error (open str-in))
    (close str-in)))

(test stream-close-idempotent
  "Test that closing an already closed stream is safe."
  (let ((str-in (make-string-input-stream "test")))
    ;; Close without opening - should be safe
    (close str-in)
    (is-true (stream-closed? str-in))
    ;; Open, close, close again
    (open str-in)
    (close str-in)
    (close str-in)
    (is-true (stream-closed? str-in))))

;;; ============================================================================
;;; String Input Stream
;;; ============================================================================

(test string-input-stream-read-char
  "Test reading characters from string input stream."
  (let ((stream (make-string-input-stream "abc")))
    (open stream)
    (is (char= #\a (read-char* stream)))
    (is (char= #\b (read-char* stream)))
    (is (char= #\c (read-char* stream)))
    (close stream)))

(test string-input-stream-read-line
  "Test reading lines from string input stream."
  (let ((stream (make-string-input-stream (format nil "line1~%line2~%line3"))))
    (open stream)
    (is (string= "line1" (read-line* stream)))
    (is (string= "line2" (read-line* stream)))
    (is (string= "line3" (read-line* stream nil :eof)))
    (close stream)))

(test string-input-stream-eof
  "Test EOF handling in string input stream."
  (let ((stream (make-string-input-stream "x")))
    (open stream)
    (read-char* stream)  ; consume the 'x'
    ;; EOF with default error
    (signals error (read-char* stream))
    (close stream))
  ;; Test with eof-value
  (let ((stream (make-string-input-stream "x")))
    (open stream)
    (read-char* stream)  ; consume the 'x'
    (is (eq :eof (read-char* stream nil :eof)))
    (close stream)))

;;; ============================================================================
;;; String Output Stream
;;; ============================================================================

(test string-output-stream-write-char
  "Test writing characters to string output stream."
  (let ((stream (make-string-output-stream)))
    (open stream)
    (write-char* #\H stream)
    (write-char* #\i stream)
    (is (string= "Hi" (get-output-stream-string stream)))
    (close stream)))

(test string-output-stream-write-string
  "Test writing strings to string output stream."
  (let ((stream (make-string-output-stream)))
    (open stream)
    (write-string* "Hello" stream)
    (write-string* " " stream)
    (write-string* "World" stream)
    (is (string= "Hello World" (get-output-stream-string stream)))
    (close stream)))

(test string-output-stream-get-string-clears
  "Test that get-output-stream-string clears the buffer."
  (let ((stream (make-string-output-stream)))
    (open stream)
    (write-string* "First" stream)
    (is (string= "First" (get-output-stream-string stream)))
    ;; Buffer should be cleared
    (write-string* "Second" stream)
    (is (string= "Second" (get-output-stream-string stream)))
    (close stream)))

;;; ============================================================================
;;; with-open-stream Macro
;;; ============================================================================

(test with-open-stream-basic
  "Test basic with-open-stream usage."
  (let ((result nil))
    (with-open-stream (s (make-string-input-stream "hello"))
      (setf result (read-line* s nil nil)))
    (is (string= "hello" result))))

(test with-open-stream-closes-on-normal-exit
  "Test that with-open-stream closes stream on normal exit."
  (let ((stream (make-string-input-stream "test")))
    (with-open-stream (s stream)
      (is-true (stream-open? s)))
    ;; After the form, stream should be closed
    (is-true (stream-closed? stream))))

(test with-open-stream-closes-on-error
  "Test that with-open-stream closes stream even on error."
  (let ((stream (make-string-input-stream "test")))
    (ignore-errors
      (with-open-stream (s stream)
        (is-true (stream-open? s))
        (error "Intentional error")))
    ;; After the error, stream should still be closed
    (is-true (stream-closed? stream))))

(test with-open-stream-output
  "Test with-open-stream with output stream."
  (let ((stream (make-string-output-stream))
        (result nil))
    (with-open-stream (s stream)
      (write-string* "hello world" s)
      (setf result (get-output-stream-string s)))
    (is (string= "hello world" result))
    (is-true (stream-closed? stream))))

;;; ============================================================================
;;; Error Conditions
;;; ============================================================================

(test stream-read-when-closed-error
  "Test that reading from closed stream signals error."
  (let ((stream (make-string-input-stream "test")))
    (signals error (read-char* stream))))

(test stream-write-when-closed-error
  "Test that writing to closed stream signals error."
  (let ((stream (make-string-output-stream)))
    (signals error (write-char* #\x stream))))

(test stream-get-string-when-closed-error
  "Test that get-output-stream-string on closed stream signals error."
  (let ((stream (make-string-output-stream)))
    (signals error (get-output-stream-string stream))))

(test stream-read-from-output-error
  "Test that reading from output stream signals error."
  (let ((stream (make-string-output-stream)))
    (open stream)
    (signals error (read-char* stream))
    (close stream)))

(test stream-write-to-input-error
  "Test that writing to input stream signals error."
  (let ((stream (make-string-input-stream "test")))
    (open stream)
    (signals error (write-char* #\x stream))
    (close stream)))
