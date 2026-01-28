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
;;; String Replace Operations (Generic Functions)
;;; ============================================================================

(defun %get-replacement (replacement func-name)
  "Helper to extract replacement string or validate function."
  (typecase replacement
    (string replacement)
    (<string> (fol.wrappers:fol-value replacement))
    (function replacement)
    (t (error "~A replacement must be a string or function, got ~A" func-name (type-of replacement)))))

(defun %replace-with-function (str scanner repl)
  "Helper to replace all regex matches using a function."
  (with-output-to-string (out)
    (let ((pos 0)
          (seq (re-seq scanner str)))
      ;; Iterate over lazy-seq properly
      (do ((current seq (fol.collection:rest current)))
          ((fol.collection:empty? current)
           ;; Write remaining string
           (write-string (subseq str pos) out))
        (let* ((item (fol.collection:first current))
               (match-str (fol.collection:nth-element item 0))
               (groups (fol.collection:nth-element item 1))
               (found (search match-str str :start2 pos)))
          (when found
            (write-string (subseq str pos found) out)
            (write-string (funcall repl match-str groups) out)
            (setf pos (cl:+ found (cl:max 1 (length match-str))))))))))


;;; ============================================================================
;;; REPLACE Generic Function
;;; ============================================================================

(defgeneric replace (source target replacement)
  (:documentation "Replace occurrences of TARGET with REPLACEMENT in SOURCE.
   For strings: replaces all matching substrings/characters/regex matches.
   For collections: replaces all elements equal to TARGET with REPLACEMENT.
   For dicts: TARGET is a key, REPLACEMENT is the new value.
   For sets/bags: removes TARGET and adds REPLACEMENT."))

;;; --- replace for <string> with <char> target and <char> replacement ---
(defmethod replace ((source string) (target character) (replacement character))
  "Replace all occurrences of TARGET character with REPLACEMENT character in SOURCE string."
  (substitute replacement target source))

(defmethod replace ((source <string>) (target character) (replacement character))
  (replace (fol.wrappers:fol-value source) target replacement))

(defmethod replace ((source string) (target <char>) replacement)
  (replace source (fol.wrappers:fol-value target) replacement))

(defmethod replace ((source <string>) (target <char>) replacement)
  (replace (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) replacement))

;;; --- replace for <string> with <char> target and <string> replacement ---
(defmethod replace ((source string) (target character) (replacement string))
  "Replace all occurrences of TARGET character with REPLACEMENT string in SOURCE."
  (with-output-to-string (out)
    (loop for char across source
          do (if (char= char target)
                 (write-string replacement out)
                 (write-char char out)))))

(defmethod replace ((source <string>) (target character) (replacement string))
  (replace (fol.wrappers:fol-value source) target replacement))

(defmethod replace ((source string) (target character) (replacement <string>))
  (replace source target (fol.wrappers:fol-value replacement)))

(defmethod replace ((source <string>) (target character) (replacement <string>))
  (replace (fol.wrappers:fol-value source) target (fol.wrappers:fol-value replacement)))

(defmethod replace ((source string) (target <char>) (replacement string))
  (replace source (fol.wrappers:fol-value target) replacement))

(defmethod replace ((source <string>) (target <char>) (replacement string))
  (replace (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) replacement))

(defmethod replace ((source string) (target <char>) (replacement <string>))
  (replace source (fol.wrappers:fol-value target) (fol.wrappers:fol-value replacement)))

(defmethod replace ((source <string>) (target <char>) (replacement <string>))
  (replace (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) (fol.wrappers:fol-value replacement)))

;;; --- replace for <string> with <string> target and <string> replacement ---
(defmethod replace ((source string) (target string) replacement)
  "Replace all occurrences of TARGET string with REPLACEMENT in SOURCE string."
  (let ((repl (%get-replacement replacement "REPLACE")))
    (if (zerop (length target))
        source  ; Can't replace empty string
        (with-output-to-string (out)
          (loop with pos = 0
                with match-len = (length target)
                for found = (search target source :start2 pos)
                while found
                do (write-string (subseq source pos found) out)
                   (write-string (if (functionp repl) (funcall repl target) repl) out)
                   (setf pos (cl:+ found match-len))
                finally (write-string (subseq source pos) out))))))

(defmethod replace ((source <string>) (target string) replacement)
  (replace (fol.wrappers:fol-value source) target replacement))

(defmethod replace ((source string) (target <string>) replacement)
  ;; Check if it's actually a <re-pattern> (subclass of <string>)
  (if (typep target '<re-pattern>)
      ;; Delegate to regex method
      (replace source (the <re-pattern> target) replacement)
      (replace source (fol.wrappers:fol-value target) replacement)))

(defmethod replace ((source <string>) (target <string>) replacement)
  (if (typep target '<re-pattern>)
      (replace (fol.wrappers:fol-value source) (the <re-pattern> target) replacement)
      (replace (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) replacement)))

;;; --- replace for <string> with <re-pattern> target ---
(defmethod replace ((source string) (target <re-pattern>) replacement)
  "Replace all regex matches of TARGET in SOURCE with REPLACEMENT."
  (let ((repl (%get-replacement replacement "REPLACE")))
    (if (functionp repl)
        (%replace-with-function source target repl)
        (cl-ppcre:regex-replace-all (fol.wrappers:fol-value target) source repl))))

(defmethod replace ((source <string>) (target <re-pattern>) replacement)
  (replace (fol.wrappers:fol-value source) target replacement))

;;; --- replace for <string> with <re-scanner> target ---
(defmethod replace ((source string) (target <re-scanner>) replacement)
  "Replace all regex matches of TARGET scanner in SOURCE with REPLACEMENT."
  (let ((repl (%get-replacement replacement "REPLACE")))
    (if (functionp repl)
        (%replace-with-function source target repl)
        (cl-ppcre:regex-replace-all (scanner-function target) source repl))))

(defmethod replace ((source <string>) (target <re-scanner>) replacement)
  (replace (fol.wrappers:fol-value source) target replacement))

;;; --- replace for <list> ---
(defmethod replace ((source fol.collection:<list>) target replacement)
  "Replace all occurrences of TARGET with REPLACEMENT in the list."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement)))
    (labels ((replace-in-list (lst)
               (if (fol.collection:empty? lst)
                   nil
                   (let ((item (fol.collection:first lst))
                         (rest-result (replace-in-list (fol.collection:rest lst))))
                     (if (equalp item raw-target)
                         (cl:cons raw-replacement rest-result)
                         (cl:cons item rest-result))))))
      (let ((result (replace-in-list source)))
        (if result
            (apply #'fol.collection:make-list result)
            (fol.collection:make-list))))))

;;; --- replace for <vector> ---
(defmethod replace ((source fol.collection:<vector>) target replacement)
  "Replace all occurrences of TARGET with REPLACEMENT in the vector."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (seq (fol.persistent:pslot-value source 'fol.collection::items)))
    (make-instance 'fol.collection:<vector>
                   :items (fset:image (lambda (item)
                                        (if (equalp item raw-target)
                                            raw-replacement
                                            item))
                                      seq))))

;;; --- replace for <array> ---
(defmethod replace ((source fol.collection:<array>) target replacement)
  "Replace all occurrences of TARGET with REPLACEMENT in the array."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (seq (fol.persistent:pslot-value source 'fol.collection::items))
        (dims (fol.persistent:pslot-value source 'fol.collection::dimensions)))
    (make-instance 'fol.collection:<array>
                   :dimensions dims
                   :items (fset:image (lambda (item)
                                        (if (equalp item raw-target)
                                            raw-replacement
                                            item))
                                      seq))))

;;; --- replace for <dict> ---
(defmethod replace ((source fol.collection:<dict>) key replacement)
  "Replace the value at KEY with REPLACEMENT in the dict.
   If KEY doesn't exist, returns the dict unchanged."
  (let ((raw-key (fol.wrappers:fol-value key))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (map (fol.persistent:pslot-value source 'fol.collection::items)))
    (multiple-value-bind (val found) (fset:lookup map raw-key)
      (declare (ignore val))
      (if found
          (make-instance (class-of source)
                         :items (fset:with map raw-key raw-replacement))
          source))))

;;; --- replace for <set> ---
(defmethod replace ((source fol.collection:<set>) target replacement)
  "Remove TARGET from set and add REPLACEMENT."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (map (fol.persistent:pslot-value source 'fol.collection::items)))
    (multiple-value-bind (val found) (fset:lookup map raw-target)
      (declare (ignore val))
      (if found
          (let ((new-map (fset:less map raw-target)))
            (make-instance (class-of source)
                           :items (fset:with new-map raw-replacement t)))
          source))))

;;; --- replace for <bag> ---
(defmethod replace ((source fol.collection:<bag>) target replacement)
  "Remove all occurrences of TARGET from bag and add same count of REPLACEMENT."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (map (fol.persistent:pslot-value source 'fol.collection::items)))
    (let ((count (fset:lookup map raw-target)))
      (if (and count (cl:> count 0))
          (let* ((new-map (fset:less map raw-target))
                 (existing-count (or (fset:lookup new-map raw-replacement) 0)))
            (make-instance (class-of source)
                           :items (fset:with new-map raw-replacement (cl:+ existing-count count))))
          source))))


;;; ============================================================================
;;; REPLACE-FIRST Generic Function
;;; ============================================================================

(defgeneric replace-first (source target replacement)
  (:documentation "Replace the first occurrence of TARGET with REPLACEMENT in SOURCE.
   For strings: replaces first matching substring/character/regex match.
   For collections: replaces first element equal to TARGET with REPLACEMENT.
   For dicts: same as replace (replace value at key).
   For sets/bags: removes TARGET and adds REPLACEMENT (once)."))

;;; --- replace-first for <string> with <char> target and <char> replacement ---
(defmethod replace-first ((source string) (target character) (replacement character))
  "Replace first occurrence of TARGET character with REPLACEMENT character."
  (let ((pos (position target source)))
    (if pos
        (let ((result (copy-seq source)))
          (setf (char result pos) replacement)
          result)
        source)))

(defmethod replace-first ((source <string>) (target character) (replacement character))
  (replace-first (fol.wrappers:fol-value source) target replacement))

(defmethod replace-first ((source string) (target <char>) replacement)
  (replace-first source (fol.wrappers:fol-value target) replacement))

(defmethod replace-first ((source <string>) (target <char>) replacement)
  (replace-first (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) replacement))

;;; --- replace-first for <string> with <char> target and <string> replacement ---
(defmethod replace-first ((source string) (target character) (replacement string))
  "Replace first occurrence of TARGET character with REPLACEMENT string."
  (let ((pos (position target source)))
    (if pos
        (concatenate 'string
                     (subseq source 0 pos)
                     replacement
                     (subseq source (1+ pos)))
        source)))

(defmethod replace-first ((source <string>) (target character) (replacement string))
  (replace-first (fol.wrappers:fol-value source) target replacement))

(defmethod replace-first ((source string) (target character) (replacement <string>))
  (replace-first source target (fol.wrappers:fol-value replacement)))

(defmethod replace-first ((source <string>) (target character) (replacement <string>))
  (replace-first (fol.wrappers:fol-value source) target (fol.wrappers:fol-value replacement)))

(defmethod replace-first ((source string) (target <char>) (replacement string))
  (replace-first source (fol.wrappers:fol-value target) replacement))

(defmethod replace-first ((source <string>) (target <char>) (replacement string))
  (replace-first (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) replacement))

(defmethod replace-first ((source string) (target <char>) (replacement <string>))
  (replace-first source (fol.wrappers:fol-value target) (fol.wrappers:fol-value replacement)))

(defmethod replace-first ((source <string>) (target <char>) (replacement <string>))
  (replace-first (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) (fol.wrappers:fol-value replacement)))

;;; --- replace-first for <string> with <string> target ---
(defmethod replace-first ((source string) (target string) replacement)
  "Replace first occurrence of TARGET string with REPLACEMENT."
  (let ((repl (%get-replacement replacement "REPLACE-FIRST"))
        (pos (search target source)))
    (if pos
        (concatenate 'string
                     (subseq source 0 pos)
                     (if (functionp repl) (funcall repl target) repl)
                     (subseq source (cl:+ pos (length target))))
        source)))

(defmethod replace-first ((source <string>) (target string) replacement)
  (replace-first (fol.wrappers:fol-value source) target replacement))

(defmethod replace-first ((source string) (target <string>) replacement)
  (if (typep target '<re-pattern>)
      (replace-first source (the <re-pattern> target) replacement)
      (replace-first source (fol.wrappers:fol-value target) replacement)))

(defmethod replace-first ((source <string>) (target <string>) replacement)
  (if (typep target '<re-pattern>)
      (replace-first (fol.wrappers:fol-value source) (the <re-pattern> target) replacement)
      (replace-first (fol.wrappers:fol-value source) (fol.wrappers:fol-value target) replacement)))

;;; --- replace-first for <string> with <re-pattern> target ---
(defmethod replace-first ((source string) (target <re-pattern>) replacement)
  "Replace first regex match of TARGET in SOURCE with REPLACEMENT."
  (let ((repl (%get-replacement replacement "REPLACE-FIRST")))
    (if (functionp repl)
        (multiple-value-bind (match-str groups) (re-find target source)
          (if match-str
              (let* ((replacement-str (funcall repl match-str groups))
                     (pos (search match-str source)))
                (concatenate 'string
                             (subseq source 0 pos)
                             replacement-str
                             (subseq source (cl:+ pos (length match-str)))))
              source))
        (cl-ppcre:regex-replace (fol.wrappers:fol-value target) source repl))))

(defmethod replace-first ((source <string>) (target <re-pattern>) replacement)
  (replace-first (fol.wrappers:fol-value source) target replacement))

;;; --- replace-first for <string> with <re-scanner> target ---
(defmethod replace-first ((source string) (target <re-scanner>) replacement)
  "Replace first regex match of TARGET scanner in SOURCE with REPLACEMENT."
  (let ((repl (%get-replacement replacement "REPLACE-FIRST")))
    (if (functionp repl)
        (multiple-value-bind (match-str groups) (re-find target source)
          (if match-str
              (let* ((replacement-str (funcall repl match-str groups))
                     (pos (search match-str source)))
                (concatenate 'string
                             (subseq source 0 pos)
                             replacement-str
                             (subseq source (cl:+ pos (length match-str)))))
              source))
        (cl-ppcre:regex-replace (scanner-function target) source repl))))

(defmethod replace-first ((source <string>) (target <re-scanner>) replacement)
  (replace-first (fol.wrappers:fol-value source) target replacement))

;;; --- replace-first for <list> ---
(defmethod replace-first ((source fol.collection:<list>) target replacement)
  "Replace first occurrence of TARGET with REPLACEMENT in the list."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (found nil))
    (labels ((replace-in-list (lst)
               (if (or found (fol.collection:empty? lst))
                   (if (fol.collection:empty? lst)
                       nil
                       ;; Copy rest unchanged
                       (let ((item (fol.collection:first lst))
                             (rest-result (replace-in-list (fol.collection:rest lst))))
                         (cl:cons item rest-result)))
                   (let ((item (fol.collection:first lst)))
                     (if (equalp item raw-target)
                         (progn
                           (setf found t)
                           (cl:cons raw-replacement (replace-in-list (fol.collection:rest lst))))
                         (cl:cons item (replace-in-list (fol.collection:rest lst))))))))
      (let ((result (replace-in-list source)))
        (if result
            (apply #'fol.collection:make-list result)
            (fol.collection:make-list))))))

;;; --- replace-first for <vector> ---
(defmethod replace-first ((source fol.collection:<vector>) target replacement)
  "Replace first occurrence of TARGET with REPLACEMENT in the vector."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (seq (fol.persistent:pslot-value source 'fol.collection::items))
        (idx nil))
    ;; Find the first matching index
    (fset:do-seq (item seq :index i)
      (when (and (null idx) (equalp item raw-target))
        (setf idx i)))
    (if idx
        (make-instance 'fol.collection:<vector>
                       :items (fset:with seq idx raw-replacement))
        source)))

;;; --- replace-first for <array> ---
(defmethod replace-first ((source fol.collection:<array>) target replacement)
  "Replace first occurrence of TARGET with REPLACEMENT in the array."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (seq (fol.persistent:pslot-value source 'fol.collection::items))
        (dims (fol.persistent:pslot-value source 'fol.collection::dimensions))
        (idx nil))
    ;; Find the first matching index
    (fset:do-seq (item seq :index i)
      (when (and (null idx) (equalp item raw-target))
        (setf idx i)))
    (if idx
        (make-instance 'fol.collection:<array>
                       :dimensions dims
                       :items (fset:with seq idx raw-replacement))
        source)))

;;; --- replace-first for <dict> ---
(defmethod replace-first ((source fol.collection:<dict>) key replacement)
  "Replace the value at KEY with REPLACEMENT in the dict (same as replace)."
  (replace source key replacement))

;;; --- replace-first for <set> ---
(defmethod replace-first ((source fol.collection:<set>) target replacement)
  "Remove TARGET from set and add REPLACEMENT (same as replace for sets)."
  (replace source target replacement))

;;; --- replace-first for <bag> ---
(defmethod replace-first ((source fol.collection:<bag>) target replacement)
  "Remove one occurrence of TARGET from bag and add one REPLACEMENT."
  (let ((raw-target (fol.wrappers:fol-value target))
        (raw-replacement (fol.wrappers:fol-value replacement))
        (map (fol.persistent:pslot-value source 'fol.collection::items)))
    (let ((count (fset:lookup map raw-target)))
      (if (and count (cl:> count 0))
          (let* ((new-map (if (cl:<= count 1)
                              (fset:less map raw-target)
                              (fset:with map raw-target (cl:1- count))))
                 (existing-count (or (fset:lookup new-map raw-replacement) 0)))
            (make-instance (class-of source)
                           :items (fset:with new-map raw-replacement (cl:1+ existing-count))))
          source))))


;;; ============================================================================
;;; String Join, Split, and Misc Operations
;;; ============================================================================

(defun join (separator coll)
  "Returns a string of all elements in COLL separated by SEPARATOR.
   Equivalent to Clojure's clojure.string/join."
  (let ((sep (%get-string separator "JOIN")))
    (with-output-to-string (out)
      (let ((first-item t))
        (flet ((process-item (item)
                 (if first-item
                     (setf first-item nil)
                     (write-string sep out))
                 (write-string (typecase item
                                 (string item)
                                 (<string> (fol.wrappers:fol-value item))
                                 (character (string item))
                                 (<char> (string (fol.wrappers:fol-value item)))
                                 (t (princ-to-string item)))
                               out)))
          (typecase coll
            (list (dolist (item coll) (process-item item)))
            (fol.collection:<lazy-seq>
             (dolist (item (fol.collection:seq coll)) (process-item item)))
            (fol.collection:<vector>
             (dotimes (i (fol.collection:size coll))
               (process-item (fol.collection:nth-element coll i))))
            (fol.collection:<list>
             (do ((lst coll (fol.collection:rest lst)))
                 ((fol.collection:empty? lst))
               (process-item (fol.collection:first lst))))
            (t (error "JOIN requires a collection, got ~A" (type-of coll)))))))))

(defun escape (s cmap)
  "Return a new string where characters in S are replaced according to CMAP.
   CMAP is a <dict> mapping characters to their replacement strings.
   Equivalent to Clojure's clojure.string/escape."
  (let ((str (%get-string s "ESCAPE")))
    (unless (typep cmap 'fol.collection:<dict>)
      (error "ESCAPE requires a <dict> for character map, got ~A" (type-of cmap)))
    (with-output-to-string (out)
      (loop for char across str
            for replacement = (fol.collection:get cmap char)
            do (if replacement
                   (write-string (typecase replacement
                                   (string replacement)
                                   (<string> (fol.wrappers:fol-value replacement))
                                   (character (string replacement))
                                   (<char> (string (fol.wrappers:fol-value replacement)))
                                   (t (princ-to-string replacement)))
                                 out)
                   (write-char char out))))))

(defun split (s re &optional limit)
  "Splits string S on a regular expression RE.
   Returns a <vector> of strings.
   Optional LIMIT argument limits the number of splits.
   Equivalent to Clojure's clojure.string/split."
  (let ((str (%get-string s "SPLIT"))
        (limit-val (if limit
                       (typecase limit
                         (integer limit)
                         (fol.classes:<integer> (fol.wrappers:fol-value limit))
                         (t (error "SPLIT limit must be an integer, got ~A" (type-of limit))))
                       0)))
    (let ((pattern (typecase re
                     (<re-scanner> (scanner-function re))
                     (<re-pattern> (fol.wrappers:fol-value re))
                     (<string> (fol.wrappers:fol-value re))
                     (string re)
                     (t (error "SPLIT pattern must be a string or regex, got ~A" (type-of re))))))
      (apply #'fol.collection:make-vector
             (cl-ppcre:split pattern str :limit (if (cl:zerop limit-val) nil limit-val))))))

(defun split-lines (s)
  "Splits S on newlines. Returns a <vector> of strings.
   Equivalent to Clojure's clojure.string/split-lines."
  (let ((str (%get-string s "SPLIT-LINES")))
    (apply #'fol.collection:make-vector
           (cl-ppcre:split "\\r?\\n" str))))


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


;;; ============================================================================
;;; UUID Operations
;;; ============================================================================

;;; UUID type predicate
(defgeneric <uuid>? (obj)
  (:documentation "Returns T if OBJ is a FOL <uuid>."))

(defmethod <uuid>? (obj) nil)
(defmethod <uuid>? ((obj <uuid>)) t)

;;; Print Object for UUID
(defmethod print-object ((obj <uuid>) stream)
  (format stream "#uuid \"~A\"" (fol-value obj)))

(defun parse-uuid (uuid-string)
  "Parses a UUID string and returns a FOL <uuid> instance.
   UUID-STRING should be in the standard UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   Example: (parse-uuid \"6ba7b810-9dad-11d1-80b4-00c04fd430c8\")"
  (let ((str (typecase uuid-string
               (string uuid-string)
               (<string> (fol-value uuid-string))
               (t (error "Expected a string for UUID, got ~A" (type-of uuid-string))))))
    (make-instance '<uuid> :val (uuid:make-uuid-from-string str))))
