(in-package fol.string)

;;; ============================================================================
;;; String Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; Type predicates work on both raw CL strings and wrapped FOL <string> objects.

;;; String type predicates
(defgeneric <string>? (obj) (:documentation "Returns T if OBJ is a FOL <string> or raw string."))
(defmethod <string>? (obj) nil)
(defmethod <string>? ((obj <string>)) t)
(defmethod <string>? ((obj string)) t)

;;; Print Object
(defmethod print-object ((obj <string>) stream)
  (format stream "~S" (fol-value obj)))


;;; ============================================================================
;;; String Manipulation Operations
;;; ============================================================================

(defun substr (s start &optional end)
  "Returns the substring of S beginning at START (inclusive) to END (exclusive).
   If END is not provided, returns from START to the end of the string.
   START and END are 0-based indices.

   Equivalent to Clojure's subs function."
  (let ((str (typecase s
               (string s)
               (<string> (fol.wrappers:fol-value s))
               (t (error "SUBSTR requires a string, got ~A" (type-of s)))))
        (start-idx (typecase start
                     (integer start)
                     (fol.classes:<integer> (fol.wrappers:fol-value start))
                     (t (error "SUBSTR start index must be an integer, got ~A" (type-of start))))))
    (let ((end-idx (if end
                       (typecase end
                         (integer end)
                         (fol.classes:<integer> (fol.wrappers:fol-value end))
                         (t (error "SUBSTR end index must be an integer, got ~A" (type-of end))))
                       (length str))))
      ;; Validate indices
      (unless (cl:and (cl:>= start-idx 0) (cl:<= start-idx (length str)))
        (error "SUBSTR start index ~A out of bounds for string of length ~A" start-idx (length str)))
      (unless (cl:and (cl:>= end-idx start-idx) (cl:<= end-idx (length str)))
        (error "SUBSTR end index ~A out of bounds (start=~A, length=~A)" end-idx start-idx (length str)))
      (subseq str start-idx end-idx))))

(defun %get-string (s func-name)
  "Helper to extract raw string from S for FUNC-NAME."
  (typecase s
    (string s)
    (<string> (fol.wrappers:fol-value s))
    (t (error "~A requires a string, got ~A" func-name (type-of s)))))

(defun blank? (s)
  "Returns true if S is nil, empty, or contains only whitespace.
   Equivalent to Clojure's clojure.string/blank?."
  (or (null s)
      (let ((str (%get-string s "BLANK?")))
        (or (zerop (length str))
            (every (lambda (c) (or (char= c #\Space)
                                   (char= c #\Tab)
                                   (char= c #\Newline)
                                   (char= c #\Return)
                                   (char= c #\Page)))
                   str)))))

(defun trim (s)
  "Removes whitespace from both ends of string S.
   Equivalent to Clojure's clojure.string/trim."
  (string-trim '(#\Space #\Tab #\Newline #\Return #\Page)
               (%get-string s "TRIM")))

(defun triml (s)
  "Removes whitespace from the left side of string S.
   Equivalent to Clojure's clojure.string/triml."
  (string-left-trim '(#\Space #\Tab #\Newline #\Return #\Page)
                    (%get-string s "TRIML")))

(defun trimr (s)
  "Removes whitespace from the right side of string S.
   Equivalent to Clojure's clojure.string/trimr."
  (string-right-trim '(#\Space #\Tab #\Newline #\Return #\Page)
                     (%get-string s "TRIMR")))

(defun trim-newline (s)
  "Removes all trailing newline characters (\\n and \\r) from string S.
   Equivalent to Clojure's clojure.string/trim-newline."
  (string-right-trim '(#\Newline #\Return)
                     (%get-string s "TRIM-NEWLINE")))

(defun capitalize (s)
  "Converts first character of S to uppercase and the rest to lowercase.
   Equivalent to Clojure's clojure.string/capitalize."
  (let ((str (%get-string s "CAPITALIZE")))
    (if (zerop (length str))
        str
        (concatenate 'string
                     (string (char-upcase (char str 0)))
                     (string-downcase (subseq str 1))))))

(defun starts-with? (s substr)
  "Returns true if string S starts with SUBSTR.
   Equivalent to Clojure's clojure.string/starts-with?."
  (let ((str (%get-string s "STARTS-WITH?"))
        (sub (%get-string substr "STARTS-WITH?")))
    (let ((sub-len (length sub))
          (str-len (length str)))
      (and (cl:>= str-len sub-len)
           (string= str sub :end1 sub-len)))))

(defun ends-with? (s substr)
  "Returns true if string S ends with SUBSTR.
   Equivalent to Clojure's clojure.string/ends-with?."
  (let ((str (%get-string s "ENDS-WITH?"))
        (sub (%get-string substr "ENDS-WITH?")))
    (let ((sub-len (length sub))
          (str-len (length str)))
      (and (cl:>= str-len sub-len)
           (string= str sub :start1 (cl:- str-len sub-len))))))

(defun includes? (s substr)
  "Returns true if string S contains SUBSTR.
   Equivalent to Clojure's clojure.string/includes?."
  (let ((str (%get-string s "INCLUDES?"))
        (sub (%get-string substr "INCLUDES?")))
    (if (search sub str) t nil)))


;;; ============================================================================
;;; Regular Expression Pattern Operations
;;; ============================================================================

;;; RE-Pattern type predicate
(defgeneric <re-pattern>? (obj) (:documentation "Returns T if OBJ is a FOL <re-pattern>."))
(defmethod <re-pattern>? (obj) nil)
(defmethod <re-pattern>? ((obj <re-pattern>)) t)

;;; Wrapping function
(defun wrap-re-pattern (pattern-string)
  "Wraps a native Lisp string into a FOL <re-pattern> instance."
  (if (stringp pattern-string)
      (make-instance '<re-pattern> :val pattern-string)
      (error "Expected a string for regex pattern, got ~A" pattern-string)))

;;; Print Object for RE-Pattern
(defmethod print-object ((obj <re-pattern>) stream)
  (format stream "#\"~A\"" (fol-value obj)))


;;; ============================================================================
;;; Regular Expression Scanner Operations
;;; ============================================================================

;;; RE-Scanner type predicate
(defgeneric <re-scanner>? (obj) (:documentation "Returns T if OBJ is a FOL <re-scanner>."))
(defmethod <re-scanner>? (obj) nil)
(defmethod <re-scanner>? ((obj <re-scanner>)) t)

;;; fol-value for RE-Scanner (returns the <re-pattern>)
(defmethod fol-value ((obj <re-scanner>)) (-fol-value obj))

;;; Print Object for RE-Scanner
(defmethod print-object ((obj <re-scanner>) stream)
  (format stream "#<RE-SCANNER ~S>" (fol-value (-fol-value obj))))

(defun normalize-register-names (register-names-list)
  "Convert register names list from CL-PPCRE to a vector.
   NIL entries are replaced with \"$N\" where N is the 1-based index."
  (apply #'fol.collection:make-vector
         (loop for name in register-names-list
               for idx from 1
               collect (if name
                           name
                           (format nil "$~D" idx)))))

(defun make-re-scanner (pattern &rest options)
  "Create a <re-scanner> from a <re-pattern> with optional keyword arguments.

   Options:
     :case-insensitive - If truthy, match case-insensitively
     :multi-line       - If truthy, ^ and $ match at line boundaries
     :extended         - If truthy, allow extended regex syntax with whitespace

   CL-PPCRE keyword mapping:
     :case-insensitive-mode = t if :case-insensitive is truthy
     :multi-line-mode = t if :multi-line is truthy
     :single-line-mode = nil if :multi-line is truthy, t otherwise
     :extended-mode = t if :extended is truthy
     :destructive = always nil"
  (unless (<re-pattern>? pattern)
    (error "make-re-scanner requires a <re-pattern>, got ~A" (type-of pattern)))
  (let* ((pattern-string (fol.wrappers:fol-value pattern))
         (case-insensitive (getf options :case-insensitive))
         (multi-line (getf options :multi-line))
         (extended (getf options :extended))
         (cl-ppcre:*allow-named-registers* t))
    (multiple-value-bind (scanner register-names)
        (cl-ppcre:create-scanner pattern-string
                                 :case-insensitive-mode (if case-insensitive t nil)
                                 :multi-line-mode (if multi-line t nil)
                                 :single-line-mode (if multi-line nil t)
                                 :extended-mode (if extended t nil)
                                 :destructive nil)
      (make-instance '<re-scanner>
                     :val pattern
                     :scanner scanner
                     :register-names (normalize-register-names register-names)))))


;;; ============================================================================
;;; Regular Expression Matching Operations
;;; ============================================================================

(defun get-scanner-and-names (regex)
  "Return (values scanner-or-pattern register-names) for the given regex.
   For <re-scanner>, returns its compiled scanner and register names.
   For strings/patterns, creates a scanner to get both."
  (let ((cl-ppcre:*allow-named-registers* t))
    (typecase regex
      (<re-scanner>
       (values (scanner-function regex) (scanner-register-names regex)))
      (<re-pattern>
       (multiple-value-bind (scanner names)
           (cl-ppcre:create-scanner (fol.wrappers:fol-value regex))
         (values scanner (normalize-register-names names))))
      (<string>
       (multiple-value-bind (scanner names)
           (cl-ppcre:create-scanner (fol.wrappers:fol-value regex))
         (values scanner (normalize-register-names names))))
      (string
       (multiple-value-bind (scanner names)
           (cl-ppcre:create-scanner regex)
         (values scanner (normalize-register-names names))))
      (t (error "Expected a regex (<string>, <re-pattern>, or <re-scanner>), got ~A" (type-of regex))))))

(defun get-group-name (register-names idx)
  "Get the name for group at IDX, using \"$N\" (1-based) if not found in register-names."
  (let ((name (when (cl:< idx (fol.collection:size register-names))
                (fol.collection:nth-element register-names idx))))
    (or name (format nil "$~D" (cl:1+ idx)))))

(defun extract-match-and-groups (target-string match-start match-end
                                  reg-starts reg-ends register-names)
  "Extract the match string and build a dict of named groups."
  (let ((match-string (subseq target-string match-start match-end))
        (groups-dict (fol.collection:make-dict)))
    ;; Add the full match as $0
    (setf groups-dict (fol.collection:add groups-dict "$0" match-string))
    ;; Add each named group
    (when reg-starts
      (loop for i from 0 below (length reg-starts)
            for name = (get-group-name register-names i)
            for start = (aref reg-starts i)
            for end = (aref reg-ends i)
            when (and start end)
            do (setf groups-dict
                     (fol.collection:add groups-dict name (subseq target-string start end)))))
    (values match-string groups-dict)))

(defun re-find (regex target)
  "Find the first match of REGEX in TARGET string.
   REGEX can be a <string>, <re-pattern>, or <re-scanner>.
   TARGET should be a string.

   Returns two values:
   1. The matched substring (or NIL if no match)
   2. A <dict> mapping register names to matched substrings,
      including \"$0\" for the complete match"
  (multiple-value-bind (scanner register-names) (get-scanner-and-names regex)
    (let ((target-string (typecase target
                           (string target)
                           (<string> (fol.wrappers:fol-value target))
                           (t (error "TARGET must be a string, got ~A" (type-of target))))))
      (multiple-value-bind (match-start match-end reg-starts reg-ends)
          (cl-ppcre:scan scanner target-string)
        (if match-start
            (extract-match-and-groups target-string match-start match-end
                                      reg-starts reg-ends register-names)
            (values nil nil))))))

(defun re-seq (regex target)
  "Return a lazy sequence of all matches of REGEX in TARGET string.
   REGEX can be a <string>, <re-pattern>, or <re-scanner>.
   TARGET should be a string.

   Each element of the sequence is a <vector> containing:
   1. The matched substring
   2. A <dict> mapping register names to matched substrings"
  (multiple-value-bind (scanner register-names) (get-scanner-and-names regex)
    (let ((target-string (typecase target
                           (string target)
                           (<string> (fol.wrappers:fol-value target))
                           (t (error "TARGET must be a string, got ~A" (type-of target))))))
      (labels ((make-seq-from (start)
                 (fol.collection:make-lazy-seq
                  (lambda ()
                    (when (cl:< start (length target-string))
                      (multiple-value-bind (match-start match-end reg-starts reg-ends)
                          (cl-ppcre:scan scanner target-string :start start)
                        (when match-start
                          (multiple-value-bind (match-str groups-dict)
                              (extract-match-and-groups target-string match-start match-end
                                                        reg-starts reg-ends register-names)
                            (let ((result (fol.collection:make-vector match-str groups-dict))
                                  ;; Handle empty matches by advancing by 1
                                  (next-start (if (cl:= match-start match-end)
                                                  (cl:1+ match-end)
                                                  match-end)))
                              (cl:cons result (make-seq-from next-start)))))))))))
        (make-seq-from 0)))))
