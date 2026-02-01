(in-package :fol.integration-tests)

(def-suite strings-suite :in integration-suite)
(def-suite* :strings-tests :in strings-suite)

;;; ---------------------------------------------------------------------------
;;; String Creation
;;; ---------------------------------------------------------------------------

(test str-function
  "Test str function."
  (fol-is "hello" "(str \"hello\")")
  (fol-is "helloworld" "(str \"hello\" \"world\")")
  (fol-is "abc123" "(str \"abc\" 123)")
  (fol-is "" "(str)")
  (fol-is "nil" "(str nil)"))

;;; ---------------------------------------------------------------------------
;;; String Predicates
;;; ---------------------------------------------------------------------------

(test blank-predicate
  "Test blank? predicate."
  (fol-is-true "(blank? \"\")")
  (fol-is-true "(blank? \"   \")")
  (fol-is-true "(blank? nil)")
  (fol-is-false "(blank? \"hello\")")
  (fol-is-false "(blank? \"  x  \")"))

(test starts-with-predicate
  "Test starts-with? predicate."
  (fol-is-true "(starts-with? \"hello\" \"he\")")
  (fol-is-true "(starts-with? \"hello\" \"hello\")")
  (fol-is-false "(starts-with? \"hello\" \"lo\")")
  (fol-is-true "(starts-with? \"hello\" \"\")"))

(test ends-with-predicate
  "Test ends-with? predicate."
  (fol-is-true "(ends-with? \"hello\" \"lo\")")
  (fol-is-true "(ends-with? \"hello\" \"hello\")")
  (fol-is-false "(ends-with? \"hello\" \"he\")")
  (fol-is-true "(ends-with? \"hello\" \"\")"))

(test includes-predicate
  "Test includes? predicate."
  (fol-is-true "(includes? \"hello world\" \"wor\")")
  (fol-is-true "(includes? \"hello\" \"hello\")")
  (fol-is-false "(includes? \"hello\" \"xyz\")"))

;;; ---------------------------------------------------------------------------
;;; String Trimming
;;; ---------------------------------------------------------------------------

(test trim-function
  "Test trim function."
  (fol-is "hello" "(trim \"  hello  \")")
  (fol-is "hello" "(trim \"hello\")")
  (fol-is "" "(trim \"   \")"))

(test triml-function
  "Test triml function."
  (fol-is "hello  " "(triml \"  hello  \")")
  (fol-is "hello" "(triml \"hello\")"))

(test trimr-function
  "Test trimr function."
  (fol-is "  hello" "(trimr \"  hello  \")")
  (fol-is "hello" "(trimr \"hello\")"))

;;; ---------------------------------------------------------------------------
;;; String Case
;;; ---------------------------------------------------------------------------

(test upper-case-function
  "Test upper-case function."
  (fol-is "HELLO" "(upper-case \"hello\")")
  (fol-is "HELLO WORLD" "(upper-case \"Hello World\")"))

(test lower-case-function
  "Test lower-case function."
  (fol-is "hello" "(lower-case \"HELLO\")")
  (fol-is "hello world" "(lower-case \"Hello World\")"))

(test capitalize-function
  "Test capitalize function."
  (fol-is "Hello" "(capitalize \"hello\")")
  (fol-is "Hello" "(capitalize \"HELLO\")"))

;;; ---------------------------------------------------------------------------
;;; String Split and Join
;;; ---------------------------------------------------------------------------

(test split-function
  "Test split function."
  (fol-is '("a" "b" "c") "(split \"a,b,c\" \",\")")
  (fol-is '("hello" "world") "(split \"hello world\" \" \")"))

(test split-lines-function
  "Test split-lines function."
  ;; Use format to insert actual newline character
  (fol-is 2 (format nil "(size (split-lines \"line1~%line2\"))")))

(test join-function
  "Test join function."
  (fol-is "a,b,c" "(join \",\" [\"a\" \"b\" \"c\"])")
  (fol-is "abc" "(join \"\" [\"a\" \"b\" \"c\"])")
  (fol-is "a-b-c" "(join \"-\" [\"a\" \"b\" \"c\"])"))

;;; ---------------------------------------------------------------------------
;;; String Replace
;;; ---------------------------------------------------------------------------

(test replace-function
  "Test replace function."
  (fol-is "hello universe" "(replace \"hello world\" \"world\" \"universe\")")
  (fol-is "hellX wXrld" "(replace \"hello world\" \"o\" \"X\")"))

(test replace-first-function
  "Test replace-first function."
  (fol-is "hellX world" "(replace-first \"hello world\" \"o\" \"X\")"))

;;; ---------------------------------------------------------------------------
;;; String Substring
;;; ---------------------------------------------------------------------------

(test subs-function
  "Test subs function."
  (fol-is "llo" "(subs \"hello\" 2)")
  (fol-is "ll" "(subs \"hello\" 2 4)")
  (fol-is "he" "(subs \"hello\" 0 2)"))
