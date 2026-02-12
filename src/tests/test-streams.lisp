;;; FOL Compiler Tests - Stream Tests

(in-package :fol.compiler.tests)

(in-suite streams-tests)

;;; =========================================================================
;;; Base class existence
;;; =========================================================================

(test input-stream-class-exists
  "The <input-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<input-stream> nil))))))

(test output-stream-class-exists
  "The <output-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<output-stream> nil))))))

;;; =========================================================================
;;; Mixin class existence
;;; =========================================================================

(test string-base-class-exists
  "The <string-base> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<string-base> nil))))))

(test file-base-class-exists
  "The <file-base> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<file-base> nil))))))

(test socket-base-class-exists
  "The <socket-base> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<socket-base> nil))))))

;;; =========================================================================
;;; Concrete class existence
;;; =========================================================================

(test string-input-stream-class-exists
  "The <string-input-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<string-input-stream> nil))))))

(test string-output-stream-class-exists
  "The <string-output-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<string-output-stream> nil))))))

(test file-input-stream-class-exists
  "The <file-input-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<file-input-stream> nil))))))

(test file-output-stream-class-exists
  "The <file-output-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<file-output-stream> nil))))))

(test socket-input-stream-class-exists
  "The <socket-input-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<socket-input-stream> nil))))))

(test socket-output-stream-class-exists
  "The <socket-output-stream> class exists."
  (is (eq t (not (null (find-class 'fol.compiler.streams:<socket-output-stream> nil))))))

;;; =========================================================================
;;; String input stream
;;; =========================================================================

(test string-input-stream-construction
  "string-input-stream creates a <string-input-stream>."
  (let ((s (fol.compiler.streams:string-input-stream "hello")))
    (is (eq t (fol.compiler.streams:<string-input-stream>? s)))
    (is (eq t (fol.compiler.streams:<input-stream>? s)))))

(test string-input-stream-read-char
  "stream-read-char reads characters from a string input stream."
  (let ((s (fol.compiler.streams:string-input-stream "abc")))
    (is (eql #\a (fol.compiler.streams:stream-read-char s)))
    (is (eql #\b (fol.compiler.streams:stream-read-char s)))
    (is (eql #\c (fol.compiler.streams:stream-read-char s)))
    (is (null (fol.compiler.streams:stream-read-char s)))))

(test string-input-stream-read-line
  "stream-read-line reads lines from a string input stream."
  (let ((s (fol.compiler.streams:string-input-stream (format nil "hello~%world"))))
    (is (equal "hello" (fol.compiler.streams:stream-read-line s)))
    (is (equal "world" (fol.compiler.streams:stream-read-line s)))))

(test string-input-stream-close
  "stream-close closes a string input stream."
  (let ((s (fol.compiler.streams:string-input-stream "test")))
    (is (eq t (fol.compiler.streams:stream-close s)))))

;;; =========================================================================
;;; String output stream
;;; =========================================================================

(test string-output-stream-construction
  "string-output-stream creates a <string-output-stream>."
  (let ((s (fol.compiler.streams:string-output-stream)))
    (is (eq t (fol.compiler.streams:<string-output-stream>? s)))
    (is (eq t (fol.compiler.streams:<output-stream>? s)))))

(test string-output-stream-write-string
  "stream-write-string writes to a string output stream."
  (let ((s (fol.compiler.streams:string-output-stream)))
    (fol.compiler.streams:stream-write-string s "hello")
    (is (equal "hello" (fol.compiler.streams:get-output-string s)))))

(test string-output-stream-write-char
  "stream-write-char writes characters to a string output stream."
  (let ((s (fol.compiler.streams:string-output-stream)))
    (fol.compiler.streams:stream-write-char s #\h)
    (fol.compiler.streams:stream-write-char s #\i)
    (is (equal "hi" (fol.compiler.streams:get-output-string s)))))

(test string-output-stream-write-line
  "stream-write-line writes a string plus newline."
  (let ((s (fol.compiler.streams:string-output-stream)))
    (fol.compiler.streams:stream-write-line s "hello")
    (let ((result (fol.compiler.streams:get-output-string s)))
      (is (search "hello" result))
      (is (> (length result) 5)))))

(test string-output-stream-get-output-string
  "get-output-string retrieves accumulated content."
  (let ((s (fol.compiler.streams:string-output-stream)))
    (fol.compiler.streams:stream-write-string s "abc")
    (fol.compiler.streams:stream-write-string s "def")
    (is (equal "abcdef" (fol.compiler.streams:get-output-string s)))))

;;; =========================================================================
;;; File streams
;;; =========================================================================

(test file-output-stream-write-and-read-back
  "Write to a file output stream, then read back with file input stream."
  (let* ((tmpfile (merge-pathnames "fol-test-stream.tmp" (uiop:temporary-directory)))
         (out (fol.compiler.streams:file-output-stream tmpfile)))
    (unwind-protect
        (progn
          (fol.compiler.streams:stream-write-string out "test data")
          (fol.compiler.streams:stream-close out)
          (let ((in (fol.compiler.streams:file-input-stream tmpfile)))
            (unwind-protect
                (is (equal "test data" (fol.compiler.streams:stream-read-line in)))
              (fol.compiler.streams:stream-close in))))
      (ignore-errors (delete-file tmpfile)))))

(test file-input-stream-predicate
  "File input stream satisfies both <file-input-stream>? and <input-stream>?."
  (let* ((tmpfile (merge-pathnames "fol-test-pred.tmp" (uiop:temporary-directory)))
         (out (fol.compiler.streams:file-output-stream tmpfile)))
    (unwind-protect
        (progn
          (fol.compiler.streams:stream-write-string out "x")
          (fol.compiler.streams:stream-close out)
          (let ((in (fol.compiler.streams:file-input-stream tmpfile)))
            (unwind-protect
                (progn
                  (is (eq t (fol.compiler.streams:<file-input-stream>? in)))
                  (is (eq t (fol.compiler.streams:<input-stream>? in))))
              (fol.compiler.streams:stream-close in))))
      (ignore-errors (delete-file tmpfile)))))

(test file-output-stream-predicate
  "File output stream satisfies both <file-output-stream>? and <output-stream>?."
  (let* ((tmpfile (merge-pathnames "fol-test-opred.tmp" (uiop:temporary-directory)))
         (out (fol.compiler.streams:file-output-stream tmpfile)))
    (unwind-protect
        (progn
          (is (eq t (fol.compiler.streams:<file-output-stream>? out)))
          (is (eq t (fol.compiler.streams:<output-stream>? out)))
          (fol.compiler.streams:stream-close out))
      (ignore-errors (delete-file tmpfile)))))

;;; =========================================================================
;;; Global dynamic vars
;;; =========================================================================

(test global-in-exists
  "*in* is bound and is a <file-input-stream>."
  (is (eq t (fol.compiler.streams:<file-input-stream>? fol.compiler.streams:*in*))))

(test global-out-exists
  "*out* is bound and is a <file-output-stream>."
  (is (eq t (fol.compiler.streams:<file-output-stream>? fol.compiler.streams:*out*))))

(test global-in-is-input-stream
  "*in* is also an <input-stream>."
  (is (eq t (fol.compiler.streams:<input-stream>? fol.compiler.streams:*in*))))

(test global-out-is-output-stream
  "*out* is also an <output-stream>."
  (is (eq t (fol.compiler.streams:<output-stream>? fol.compiler.streams:*out*))))

;;; =========================================================================
;;; Print object
;;; =========================================================================

(test string-input-stream-print
  "String input stream prints readably."
  (let* ((s (fol.compiler.streams:string-input-stream "test"))
         (printed (format nil "~A" s)))
    (is (search "STRING-INPUT-STREAM" printed))))

(test string-output-stream-print
  "String output stream prints readably."
  (let* ((s (fol.compiler.streams:string-output-stream))
         (printed (format nil "~A" s)))
    (is (search "STRING-OUTPUT-STREAM" printed))))

;;; =========================================================================
;;; Stream flush
;;; =========================================================================

(test string-output-stream-flush
  "stream-flush returns T on string output stream."
  (let ((s (fol.compiler.streams:string-output-stream)))
    (fol.compiler.streams:stream-write-string s "data")
    (is (eq t (fol.compiler.streams:stream-flush s)))))

;;; =========================================================================
;;; Type predicate negative cases
;;; =========================================================================

(test input-stream-predicate-negative
  "<input-stream>? returns NIL for non-streams."
  (is (null (fol.compiler.streams:<input-stream>? 42)))
  (is (null (fol.compiler.streams:<input-stream>? "string")))
  (is (null (fol.compiler.streams:<input-stream>? nil))))

(test output-stream-predicate-negative
  "<output-stream>? returns NIL for non-streams."
  (is (null (fol.compiler.streams:<output-stream>? 42)))
  (is (null (fol.compiler.streams:<output-stream>? "string")))
  (is (null (fol.compiler.streams:<output-stream>? nil))))
