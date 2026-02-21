# Regular Expression Operations

Functions for pattern matching using regular expressions. FOL provides a layered regex system with patterns, compiled scanners, and matching functions.

## Types

FOL has three regex-related types:

- `<re-pattern>` - A regex pattern string (inherits from `<string>`)
- `<re-scanner>` - A compiled regex scanner with options and named group tracking
- Plain strings can also be used directly for simple patterns

---

## wrap-re-pattern                                                      *[function]*

```
(wrap-re-pattern pattern-string)
```

Creates a `<re-pattern>` from a string. The `#"..."` reader syntax is the idiomatic way to create patterns.

### Examples

```fol
;; Using reader syntax (preferred)
#"\d+"                            ; => <re-pattern> for digits

;; Using function
(wrap-re-pattern "\\d+")          ; => <re-pattern> for digits

;; Patterns are also strings
(<string>? #"\d+")                ; => true
(<re-pattern>? #"\d+")            ; => true
```

---

## make-re-scanner                                                      *[function]*

```
(make-re-scanner pattern)
(make-re-scanner pattern :case-insensitive t)
(make-re-scanner pattern :multi-line t)
(make-re-scanner pattern :extended t)
```

Creates a compiled `<re-scanner>` from a `<re-pattern>` with optional flags. Compiling a scanner is useful when you need to reuse the same pattern multiple times or need special matching options.

### Options

- `:case-insensitive` - Match case-insensitively
- `:multi-line` - `^` and `$` match at line boundaries within the string
- `:extended` - Allow extended regex syntax with whitespace and comments

### Examples

```fol
;; Create a case-insensitive scanner
(def scanner (make-re-scanner #"[a-z]+" :case-insensitive t))
(re-find scanner "ABC123")        ; => "ABC"

;; Multi-line matching
(def ml-scanner (make-re-scanner #"^line" :multi-line t))
(re-find ml-scanner "first\nline two")  ; => "line"

;; Extended mode (whitespace ignored)
(def ext-scanner (make-re-scanner #"\\d+ # match digits" :extended t))
```

---

## re-find                                                              *[function]*

```
(re-find regex target)
```

Finds the first match of `regex` in the `target` string.

### Arguments

- `regex` - Can be a string, `<re-pattern>`, or `<re-scanner>`
- `target` - The string to search (can be raw or wrapped `<string>`)

### Return Values

Returns two values:
1. The matched substring, or `nil` if no match
2. A `<dict>` mapping group names to matched substrings, or `nil` if no match

The dict always includes `"$0"` for the complete match. Unnamed groups are named `"$1"`, `"$2"`, etc. Named groups use their defined names.

### Examples

```fol
;; Simple match
(re-find "\\d+" "abc123def")
; => "123"
; => {"$0" "123"}

;; No match
(re-find "\\d+" "abcdef")
; => nil
; => nil

;; With capturing groups
(re-find "(\\w+)@(\\w+)" "email: test@example.com")
; => "test@example"
; => {"$0" "test@example", "$1" "test", "$2" "example"}

;; With named groups
(re-find "(?<user>\\w+)@(?<domain>\\w+)" "test@example.com")
; => "test@example"
; => {"$0" "test@example", "user" "test", "domain" "example"}

;; Using a pattern
(re-find #"[a-z]+" "123abc456")
; => "abc"
; => {"$0" "abc"}

;; Using a scanner with options
(def scanner (make-re-scanner #"[A-Z]+" :case-insensitive t))
(re-find scanner "123abc456")
; => "abc"
; => {"$0" "abc"}

;; Anchored patterns
(re-find "^\\d+" "123abc")        ; => "123" (matches at start)
(re-find "\\d+$" "abc123")        ; => "123" (matches at end)
```

---

## re-seq                                                               *[function]*

```
(re-seq regex target)
```

Returns a lazy sequence of all matches of `regex` in the `target` string. Non-overlapping matches are returned from left to right.

### Arguments

- `regex` - Can be a string, `<re-pattern>`, or `<re-scanner>`
- `target` - The string to search (can be raw or wrapped `<string>`)

### Return Value

Returns a `<lazy-seq>` where each element is a `<vector>` containing:
1. The matched substring
2. A `<dict>` mapping group names to matched substrings

### Examples

```fol
;; Find all digit sequences
(re-seq "\\d+" "a1b2c3d4")
; => lazy-seq of:
;    ["1" {"$0" "1"}]
;    ["2" {"$0" "2"}]
;    ["3" {"$0" "3"}]
;    ["4" {"$0" "4"}]

;; Get the size of matches
(size (re-seq "\\d+" "a1b2c3d4"))  ; => 4

;; Access first match
(first (re-seq "\\d+" "a1b2c3"))
; => ["1" {"$0" "1"}]

;; With capturing groups
(re-seq "(\\w+)=(\\d+)" "a=1 b=2 c=3")
; => lazy-seq of:
;    ["a=1" {"$0" "a=1", "$1" "a", "$2" "1"}]
;    ["b=2" {"$0" "b=2", "$1" "b", "$2" "2"}]
;    ["c=3" {"$0" "c=3", "$1" "c", "$2" "3"}]

;; Process matches lazily
(map (fn [match] (nth-element match 0))
     (re-seq "[a-z]+" "1abc2def3ghi"))
; => lazy-seq: "abc", "def", "ghi"

;; No matches returns empty sequence
(empty? (re-seq "\\d+" "abcdef"))  ; => true

;; Non-overlapping matches
(re-seq "aa" "aaaa")
; => lazy-seq of: ["aa" ...] ["aa" ...]
; (matches at positions 0 and 2, not overlapping)

;; Extract all matches as a list
(map first (re-seq "\\w+" "one two three"))
; => lazy-seq: "one", "two", "three"
```

---

## Type Predicates

```
(<re-pattern>? obj)
(<re-scanner>? obj)
```

Test whether an object is a regex pattern or scanner.

### Examples

```fol
(<re-pattern>? #"\d+")            ; => true
(<re-pattern>? "hello")           ; => false (raw string)
(<re-pattern>? (wrap-string "x")) ; => false (wrapped string)

(def scanner (make-re-scanner #"\d+"))
(<re-scanner>? scanner)           ; => true
(<re-scanner>? #"\d+")            ; => false (pattern, not scanner)
```

---

## Regex Syntax

FOL uses CL-PPCRE for regex matching, which supports Perl-compatible regular expressions:

### Common Patterns

| Pattern | Matches |
|---------|---------|
| `.` | Any character (except newline by default) |
| `\d` | Digit [0-9] |
| `\D` | Non-digit |
| `\w` | Word character [a-zA-Z0-9_] |
| `\W` | Non-word character |
| `\s` | Whitespace |
| `\S` | Non-whitespace |
| `^` | Start of string (or line in multi-line mode) |
| `$` | End of string (or line in multi-line mode) |

### Quantifiers

| Pattern | Meaning |
|---------|---------|
| `*` | 0 or more |
| `+` | 1 or more |
| `?` | 0 or 1 |
| `{n}` | Exactly n |
| `{n,}` | n or more |
| `{n,m}` | Between n and m |

### Groups

| Pattern | Meaning |
|---------|---------|
| `(...)` | Capturing group (numbered $1, $2, etc.) |
| `(?<name>...)` | Named capturing group |
| `(?:...)` | Non-capturing group |

### Character Classes

| Pattern | Meaning |
|---------|---------|
| `[abc]` | Any of a, b, or c |
| `[^abc]` | Not a, b, or c |
| `[a-z]` | Range a through z |
| `[a-zA-Z]` | Letters |

---

## Usage Patterns

### Extract Data with Named Groups

```fol
;; Parse a log line
(def log-pattern #"(?<timestamp>[\d:]+) (?<level>\w+) (?<message>.*)")

(multiple-value-bind (match groups)
    (re-find log-pattern "10:30:45 ERROR Connection failed")
  (when match
    (println "Time:" (get groups "timestamp"))
    (println "Level:" (get groups "level"))
    (println "Message:" (get groups "message"))))
```

### Find and Process All Matches

```fol
;; Extract all URLs from text
(def url-pattern #"https?://[^\s]+")

(map (fn [match] (nth-element match 0))
     (re-seq url-pattern "Visit https://example.com or http://test.org"))
; => lazy-seq: "https://example.com", "http://test.org"
```

### Reuse Compiled Scanner

```fol
;; Compile once, use many times
(def email-scanner (make-re-scanner #"[\w.]+@[\w.]+" :case-insensitive t))

(defn extract-emails [text]
  (map first (re-seq email-scanner text)))

(extract-emails "Contact alice@example.com or BOB@TEST.ORG")
; => lazy-seq: "alice@example.com", "BOB@TEST.ORG"
```

---

## Implementation Notes

- Patterns are compiled on first use; use `<re-scanner>` for repeated matching
- Named groups require the `(?<name>...)` syntax
- `re-seq` returns a lazy sequence - matches are computed on demand
- Empty matches (from patterns like `\d*`) advance position by 1 to prevent infinite loops
- The `$0` key always contains the complete match
- Group numbering starts at `$1` for the first capturing group
