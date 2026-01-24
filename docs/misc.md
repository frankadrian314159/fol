# Miscellaneous Functions

## identity

```
(identity x)
```

Returns x unchanged. Useful as a placeholder function.

### Examples

```fol
(identity 42)         ; => 42
(identity "hello")    ; => "hello"
(identity [1 2 3])    ; => [1 2 3]
```

---

## print

```
(print x)
```

Prints x to standard output with a newline, then returns x.

### Examples

```fol
(print "hello")       ; prints: "hello" and returns "hello"
(print 42)            ; prints: 42 and returns 42
```

---

## type

```
(type x)
```

Returns the FOL type of x as a symbol.

### Examples

```fol
(type 42)             ; => <integer>
(type 3.14)           ; => <double-float>
(type "hello")        ; => <string>
(type [1 2 3])        ; => <vector>
(type {:a 1})         ; => <dict>
(type 'foo)           ; => <symbol>
(type :bar)           ; => <keyword>
(type true)           ; => <bool>
(type \a)             ; => <char>
```

---

## make

```
(make class & args)
```

Generic constructor for FOL types. Creates an instance of the specified class
with the given arguments.

### Examples

```fol
;; Create collections
(make '<vector> 1 2 3)        ; => [1 2 3]
(make '<list> 1 2 3)          ; => (1 2 3)
(make '<dict> :a 1 :b 2)      ; => {:a 1 :b 2}
(make '<set> 1 2 3)           ; => #{1 2 3}

;; Create wrapped values
(make '<string> "hello")      ; => "hello"
(make '<integer> 42)          ; => 42
```

---

## str

```
(str & args)
```

Concatenates the string representations of all arguments into a single string.

### Examples

```fol
(str "hello" " " "world")     ; => "hello world"
(str "count: " 42)            ; => "count: 42"
(str)                         ; => ""
(str "a" "b" "c")             ; => "abc"
```

---

## list

```
(list & args)
```

Creates a CL-style list containing the given arguments.

### Examples

```fol
(list 1 2 3)                  ; => (1 2 3)
(list)                        ; => nil
(list 'a 'b 'c)               ; => (a b c)
```

---

## append

```
(append & lists)
```

Concatenates CL-style lists together. Returns a new list containing all elements.

### Examples

```fol
(append '(1 2) '(3 4))        ; => (1 2 3 4)
(append '(a) '(b) '(c d))     ; => (a b c d)
(append '() '(1 2))           ; => (1 2)
```

---

## reverse

```
(reverse sequence)
```

Returns a new sequence with elements in reverse order.

### Examples

```fol
(reverse '(1 2 3))            ; => (3 2 1)
(reverse "hello")             ; => "olleh"
(reverse '())                 ; => nil
```
