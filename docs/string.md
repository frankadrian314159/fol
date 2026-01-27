# String Operations

Functions for manipulating strings in FOL.

## substr

```
(substr s start)
(substr s start end)
```

Returns the substring of `s` beginning at `start` (inclusive) to `end` (exclusive). If `end` is not provided, returns from `start` to the end of the string.

This is equivalent to Clojure's `subs` function.

### Arguments

- `s` - The source string (can be raw or wrapped `<string>`)
- `start` - The starting index (0-based, inclusive)
- `end` - The ending index (0-based, exclusive). Defaults to the length of the string.

### Examples

```fol
(substr "hello world" 6)          ; => "world"
(substr "hello" 1 4)              ; => "ell"
(substr "hello world" 0 5)        ; => "hello"
(substr "hello" 5)                ; => "" (start at end)
```

---

## blank?

```
(blank? s)
```

Returns true if `s` is nil, empty, or contains only whitespace.

This is equivalent to Clojure's `clojure.string/blank?`.

### Examples

```fol
(blank? nil)                      ; => true
(blank? "")                       ; => true
(blank? "   ")                    ; => true
(blank? "\t\n")                   ; => true
(blank? "hello")                  ; => false
(blank? " hello ")                ; => false
```

---

## trim

```
(trim s)
```

Removes whitespace from both ends of string `s`.

This is equivalent to Clojure's `clojure.string/trim`.

### Examples

```fol
(trim "  hello  ")                ; => "hello"
(trim "\n  hello  \t")            ; => "hello"
(trim "hello")                    ; => "hello"
(trim "")                         ; => ""
```

---

## triml

```
(triml s)
```

Removes whitespace from the left (beginning) of string `s`.

This is equivalent to Clojure's `clojure.string/triml`.

### Examples

```fol
(triml "  hello  ")               ; => "hello  "
(triml "hello")                   ; => "hello"
(triml "   ")                     ; => ""
```

---

## trimr

```
(trimr s)
```

Removes whitespace from the right (end) of string `s`.

This is equivalent to Clojure's `clojure.string/trimr`.

### Examples

```fol
(trimr "  hello  ")               ; => "  hello"
(trimr "hello")                   ; => "hello"
(trimr "   ")                     ; => ""
```

---

## trim-newline

```
(trim-newline s)
```

Removes all trailing newline characters (`\n` and `\r`) from string `s`. Does not remove other whitespace.

This is equivalent to Clojure's `clojure.string/trim-newline`.

### Examples

```fol
(trim-newline "hello\n")          ; => "hello"
(trim-newline "hello\r\n")        ; => "hello"
(trim-newline "hello\n\n\n")      ; => "hello"
(trim-newline "\nhello\n")        ; => "\nhello" (preserves leading)
(trim-newline "hello  ")          ; => "hello  " (preserves spaces)
```

---

## capitalize

```
(capitalize s)
```

Converts the first character of `s` to uppercase and the rest to lowercase.

This is equivalent to Clojure's `clojure.string/capitalize`.

### Examples

```fol
(capitalize "hello")              ; => "Hello"
(capitalize "HELLO")              ; => "Hello"
(capitalize "hELLO wORLD")        ; => "Hello world"
(capitalize "a")                  ; => "A"
(capitalize "")                   ; => ""
```

---

## starts-with?

```
(starts-with? s substr)
```

Returns true if string `s` starts with `substr`.

This is equivalent to Clojure's `clojure.string/starts-with?`.

### Examples

```fol
(starts-with? "hello world" "hello")  ; => true
(starts-with? "hello" "hello")        ; => true
(starts-with? "hello" "h")            ; => true
(starts-with? "hello" "")             ; => true
(starts-with? "hello world" "world")  ; => false
(starts-with? "hello" "Hello")        ; => false (case-sensitive)
(starts-with? "" "a")                 ; => false
```

---

## ends-with?

```
(ends-with? s substr)
```

Returns true if string `s` ends with `substr`.

This is equivalent to Clojure's `clojure.string/ends-with?`.

### Examples

```fol
(ends-with? "hello world" "world")    ; => true
(ends-with? "hello" "hello")          ; => true
(ends-with? "hello" "o")              ; => true
(ends-with? "hello" "")               ; => true
(ends-with? "hello world" "hello")    ; => false
(ends-with? "hello" "Hello")          ; => false (case-sensitive)
(ends-with? "" "a")                   ; => false
```

---

## includes?

```
(includes? s substr)
```

Returns true if string `s` contains `substr`.

This is equivalent to Clojure's `clojure.string/includes?`.

### Examples

```fol
(includes? "hello world" "lo wo")     ; => true
(includes? "hello world" "hello")     ; => true
(includes? "hello world" "world")     ; => true
(includes? "hello" "")                ; => true
(includes? "hello" "foo")             ; => false
(includes? "hello" "Hello")           ; => false (case-sensitive)
(includes? "" "a")                    ; => false
```

---

## replace

```
(replace s match replacement)
```

Replaces all instances of `match` in `s` with `replacement`.

`match` can be:
- A string literal (for exact matching)
- A `<re-pattern>` (for regex matching)
- A `<re-scanner>` (for regex matching with options)

`replacement` can be:
- A string (with `\1`, `\2`, etc. for regex backreferences)
- A function that receives the match and groups dict, returning the replacement string

This is equivalent to Clojure's `clojure.string/replace`.

### Examples

```fol
(replace "hello world" "world" "planet")      ; => "hello planet"
(replace "ababab" "a" "X")                    ; => "XbXbXb"
(replace "a1b2c3" #"\d+" "N")                 ; => "aNbNcN"
(replace "a=1 b=2" #"(\w+)=(\d+)" "\1:[\2]")  ; => "a:[1] b:[2]"
```

---

## replace-first

```
(replace-first s match replacement)
```

Replaces the first instance of `match` in `s` with `replacement`.

Arguments work the same as `replace`.

This is equivalent to Clojure's `clojure.string/replace-first`.

### Examples

```fol
(replace-first "hello world" "world" "planet")  ; => "hello planet"
(replace-first "ababab" "a" "X")                ; => "Xbabab"
(replace-first "abc123def" #"\d+" "###")        ; => "abc###def"
```

---

## join

```
(join separator coll)
```

Returns a string of all elements in `coll` separated by `separator`.

`coll` can be a CL list, FOL `<list>`, `<vector>`, or `<lazy-seq>`.

Non-string elements are converted to strings using `princ-to-string`.

This is equivalent to Clojure's `clojure.string/join`.

### Examples

```fol
(join "," ["a" "b" "c"])         ; => "a,b,c"
(join " " ["hello" "world"])     ; => "hello world"
(join "-" [1 2 3])               ; => "1-2-3"
(join "" ["a" "b" "c"])          ; => "abc"
(join "," [])                    ; => ""
```

---

## escape

```
(escape s cmap)
```

Returns a new string where characters in `s` are replaced according to `cmap`.

`cmap` is a `<dict>` mapping characters to their replacement strings.

This is equivalent to Clojure's `clojure.string/escape`.

### Examples

```fol
(escape "<div>hello</div>"
        {#\< "&lt;" #\> "&gt;"})
; => "&lt;div&gt;hello&lt;/div&gt;"

(escape "a&b" {#\& "&amp;"})     ; => "a&amp;b"
(escape "hello" {#\x "X"})       ; => "hello" (no x to replace)
```

---

## split

```
(split s re)
(split s re limit)
```

Splits string `s` on a regular expression `re`. Returns a `<vector>` of strings.

Optional `limit` argument limits the number of splits.

`re` can be a string, `<re-pattern>`, or `<re-scanner>`.

This is equivalent to Clojure's `clojure.string/split`.

### Examples

```fol
(split "a,b,c" ",")              ; => ["a" "b" "c"]
(split "a1b2c3d" #"\d")          ; => ["a" "b" "c" "d"]
(split "a,b,c,d" "," 2)          ; => ["a" "b,c,d"]
(split "hello   world" #"\s+")   ; => ["hello" "world"]
```

---

## split-lines

```
(split-lines s)
```

Splits `s` on newlines. Returns a `<vector>` of strings.

Handles both Unix (`\n`) and Windows (`\r\n`) line endings.

This is equivalent to Clojure's `clojure.string/split-lines`.

### Examples

```fol
(split-lines "line1\nline2\nline3")    ; => ["line1" "line2" "line3"]
(split-lines "line1\r\nline2")         ; => ["line1" "line2"]
(split-lines "single line")            ; => ["single line"]
```

---

## reverse

```
(reverse coll)
```

Returns a new collection with elements in reverse order. This is a generic function that works on:

- **Strings**: Returns a string with characters reversed
- **Vectors (`<vector>`)**: Returns a new vector with elements reversed
- **Lists (`<list>`)**: Returns a new FOL list with elements reversed
- **CL lists**: Returns a reversed CL list

This is equivalent to Clojure's `clojure.string/reverse` for strings, and `clojure.core/reverse` for sequences.

### Examples

```fol
;; Strings
(reverse "hello")         ; => "olleh"
(reverse "racecar")       ; => "racecar" (palindrome)
(reverse "")              ; => ""

;; Vectors
(reverse [1 2 3 4 5])     ; => [5 4 3 2 1]
(reverse [])              ; => []

;; Lists
(reverse '(1 2 3 4 5))    ; => (5 4 3 2 1)
(reverse '(a b c))        ; => (c b a)
```

---

## index-of

```
(index-of coll value)
(index-of coll value start)
```

Returns the index of the first occurrence of `value` in collection `coll`, or `nil` if not found. This is a generic function that works on:

- **Strings**: Searches for a substring, character, or regex pattern
- **Vectors (`<vector>`)**: Searches for an element using EQL
- **Lists (`<list>`)**: Searches for an element using EQL
- **CL lists**: Searches for an element using EQL

For strings, `value` can be:
- A string (substring search)
- A character (single character search)
- A `<re-pattern>` (regex pattern search)

Optional `start` specifies where to start searching (default 0).

This is equivalent to Clojure's `clojure.string/index-of` for strings.

### Examples

```fol
;; Strings
(index-of "hello world" "world")   ; => 6
(index-of "hello world" "o")       ; => 4
(index-of "hello world" "o" 5)     ; => 7
(index-of "hello" #\l)             ; => 2
(index-of "hello" "xyz")           ; => nil
(index-of "abc123def" #"\d+")      ; => 3

;; Vectors
(index-of [1 2 3 4] 3)             ; => 2
(index-of [1 2 3 2 1] 2 2)         ; => 3 (start from index 2)
(index-of ['a 'b 'c] 'b)           ; => 1

;; Lists
(index-of '(a b c) 'b)             ; => 1
(index-of '(1 2 3) 4)              ; => nil
```

---

## last-index-of

```
(last-index-of coll value)
(last-index-of coll value end)
```

Returns the index of the last occurrence of `value` in collection `coll`, or `nil` if not found. This is a generic function that works on:

- **Strings**: Searches for a substring or character
- **Vectors (`<vector>`)**: Searches for an element using EQL
- **Lists (`<list>`)**: Searches for an element using EQL
- **CL lists**: Searches for an element using EQL

For strings, `value` can be:
- A string (substring search)
- A character (single character search)

Optional `end` specifies the maximum index to search up to (inclusive).

This is equivalent to Clojure's `clojure.string/last-index-of` for strings.

### Examples

```fol
;; Strings
(last-index-of "hello world" "o")       ; => 7
(last-index-of "abracadabra" "a")       ; => 10
(last-index-of "hello world" "o" 6)     ; => 4 (search up to index 6)
(last-index-of "hello" #\l)             ; => 3
(last-index-of "hello" "xyz")           ; => nil

;; Vectors
(last-index-of [1 2 3 2 1] 2)           ; => 3
(last-index-of [1 2 3 2 1] 1)           ; => 4
(last-index-of [1 2 3 2 1] 2 2)         ; => 1 (search up to index 2)

;; Lists
(last-index-of '(a b a c) 'a)           ; => 2
(last-index-of '(1 2 1) 1)              ; => 2
```

---

## Notes

All string functions accept both raw CL strings and wrapped FOL `<string>` objects. They return raw CL strings.

String comparisons are case-sensitive. For case-insensitive operations, consider using regular expressions with the `:case-insensitive` option.

---

## See Also

- [Regular Expression Operations](regex.md) - Pattern matching with `re-find` and `re-seq`
- `str` - String concatenation function
