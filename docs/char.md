# Character Functions

Functions for working with characters.

## char-name-string                                                     *[function]*

```
(char-name-string c)
```

Returns the name of the character as a capitalized string, or NIL if the character has no name.

Special characters (space, tab, newline, etc.) have names; regular printable characters (letters, digits, punctuation) return NIL.

### Arguments

- `c` - A character

### Examples

```fol
(char-name-string #\Space)    ; => "Space"
(char-name-string #\Newline)  ; => "Newline"
(char-name-string #\Tab)      ; => "Tab"
(char-name-string #\Return)   ; => "Return"
(char-name-string #\a)        ; => NIL
(char-name-string #\Z)        ; => NIL
```

**Note**: Some character names are implementation-dependent. For example, SBCL returns "Nul" for the null character and "Esc" for escape.

---

## char-upcase                                                          *[function]*

```
(char-upcase c)
```

Returns the uppercase version of the character.

### Arguments

- `c` - A character

### Examples

```fol
(char-upcase #\a)        ; => #\A
(char-upcase #\z)        ; => #\Z
(char-upcase #\A)        ; => #\A
(char-upcase #\5)        ; => #\5
```

---

## char-downcase                                                        *[function]*

```
(char-downcase c)
```

Returns the lowercase version of the character.

### Arguments

- `c` - A character

### Examples

```fol
(char-downcase #\A)      ; => #\a
(char-downcase #\Z)      ; => #\z
(char-downcase #\a)      ; => #\a
(char-downcase #\5)      ; => #\5
```

---

## alpha-char?                                                          *[function]*

```
(alpha-char? c)
```

Returns T if the character is an alphabetic character.

### Arguments

- `c` - A character

### Examples

```fol
(alpha-char? #\a)        ; => T
(alpha-char? #\Z)        ; => T
(alpha-char? #\5)        ; => NIL
(alpha-char? #\Space)    ; => NIL
```

---

## digit-char?                                                          *[function]*

```
(digit-char? c)
```

Returns T if the character is a digit (0-9).

### Arguments

- `c` - A character

### Examples

```fol
(digit-char? #\5)        ; => T
(digit-char? #\0)        ; => T
(digit-char? #\a)        ; => NIL
```

---

## alphanumeric?                                                        *[function]*

```
(alphanumeric? c)
```

Returns T if the character is alphanumeric (letter or digit).

### Arguments

- `c` - A character

### Examples

```fol
(alphanumeric? #\a)      ; => T
(alphanumeric? #\5)      ; => T
(alphanumeric? #\Space)  ; => NIL
(alphanumeric? #\-)      ; => NIL
```

---

## upper-case?                                                          *[function]*

```
(upper-case? c)
```

Returns T if the character is uppercase.

### Arguments

- `c` - A character

### Examples

```fol
(upper-case? #\A)        ; => T
(upper-case? #\a)        ; => NIL
(upper-case? #\5)        ; => NIL
```

---

## lower-case?                                                          *[function]*

```
(lower-case? c)
```

Returns T if the character is lowercase.

### Arguments

- `c` - A character

### Examples

```fol
(lower-case? #\a)        ; => T
(lower-case? #\A)        ; => NIL
(lower-case? #\5)        ; => NIL
```

---

## whitespace?                                                          *[function]*

```
(whitespace? c)
```

Returns T if the character is a whitespace character (space, tab, newline, return, linefeed, or page).

### Arguments

- `c` - A character

### Examples

```fol
(whitespace? #\Space)    ; => T
(whitespace? #\Tab)      ; => T
(whitespace? #\Newline)  ; => T
(whitespace? #\a)        ; => NIL
```
