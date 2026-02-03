# Exception Classes

FOL provides a hierarchy of exception classes for error handling, following Clojure's `try`/`catch` pattern while integrating with CLOS's object system.

## Exception Hierarchy

```
<exception>
  ├─ <panic>
  ├─ <error>
  └─ <warning>
```

All exception classes inherit from `<exception>` and are persistent objects with a `msg` slot containing the error message.

## Exception Classes

### `<exception>`

The base exception class from which all other exception types derive.

**Slots:**
- `msg` (type: `<string>`) - The exception message

**Type Predicate:** `<exception>?`

**Example:**
```clojure
(def exc (make <exception> :msg "Something went wrong"))
(:msg exc)  ; => "Something went wrong"
(<exception>? exc)   ; => T
```

### `<panic>`

Represents unrecoverable errors that indicate serious system failures.

**Inherits from:** `<exception>`

**Type Predicate:** `<panic>?`

**Example:**
```clojure
(def panic-exc (make <panic> :msg "System corruption detected"))
(<panic>? panic-exc)     ; => T
(<exception>? panic-exc) ; => T
```

### `<error>`

Represents recoverable errors that can be handled by application code.

**Inherits from:** `<exception>`

**Type Predicate:** `<error>?`

**Example:**
```clojure
(def err (make <error> :msg "Invalid input"))
(<error>? err)       ; => T
(<exception>? err)   ; => T
```

### `<warning>`

Represents non-critical issues that don't prevent operation but should be noted.

**Inherits from:** `<exception>`

**Type Predicate:** `<warning>?`

**Example:**
```clojure
(def warn (make <warning> :msg "Deprecated function used"))
(<warning>? warn)     ; => T
(<exception>? warn)   ; => T
```

## Using Exceptions

### Throwing Exceptions

Use `throw` to raise an exception. You can throw:
- An exception instance directly
- A string (automatically wrapped in `<error>`)
- Any value (converted to string and wrapped in `<error>`)

**Examples:**
```clojure
;; Throw an error instance
(throw (make <error> :msg "File not found"))

;; Throw a string (creates <error> automatically)
(throw "File not found")

;; Throw a panic
(throw (make <panic> :msg "Critical system failure"))
```

### Catching Exceptions

Use `try`/`catch` to handle exceptions by type. The `catch` clause specifies the exception type and binds the exception object to a variable.

**Syntax:**
```clojure
(try
  body*
  (catch exception-type variable
    handler-body*))
```

**Examples:**

```clojure
;; Catch specific error type
(defn safe-divide [a b]
  (try
    (/ a b)
    (catch <error> e
      (println "Error:" (:msg e))
      nil)))

;; Catch all exceptions
(defn robust-operation []
  (try
    (risky-operation)
    (catch <exception> e
      (println "Caught exception:" (:msg e))
      :failed)))

;; Multiple catch clauses (first matching type wins)
(defn handle-operation []
  (try
    (perform-operation)
    (catch <panic> e
      (println "PANIC:" (:msg e))
      (shutdown-system))
    (catch <error> e
      (println "Error:" (:msg e))
      (retry-operation))
    (catch <warning> e
      (println "Warning:" (:msg e))
      (continue-operation))))
```

### Type-Based Catching

Exception catching uses type hierarchy - catching `<exception>` will catch all exception types:

```clojure
(try
  (throw (make <error> :msg "Something failed"))
  (catch <exception> e  ; Catches <error>, <panic>, <warning>
    (println "Caught:" (:msg e))))
```

## Accessing Exception Data

### Slot Access via `:msg`

The exception message can be accessed using the Clojure-style keyword-as-function syntax.

**Syntax:** `(:msg exception) → <string>`

**Example:**
```clojure
(def exc (make <error> :msg "Invalid argument"))
(:msg exc)  ; => "Invalid argument"
```

## Type Predicates

### `<exception>?`

Returns `T` if the argument is an instance of `<exception>` or any subclass.

**Signature:** `(<exception>? obj) → boolean`

### `<panic>?`

Returns `T` if the argument is an instance of `<panic>`.

**Signature:** `(<panic>? obj) → boolean`

### `<error>?`

Returns `T` if the argument is an instance of `<error>`.

**Signature:** `(<error>? obj) → boolean`

### `<warning>?`

Returns `T` if the argument is an instance of `<warning>`.

**Signature:** `(<warning>? obj) → boolean`

**Example:**
```clojure
(def err (make <error> :msg "Failed"))

(<error>? err)       ; => T
(<panic>? err)       ; => NIL
(<exception>? err)   ; => T (inheritance)
```

## Custom Exception Classes

You can define custom exception classes by inheriting from the standard exception types:

```clojure
(defclass* <validation-error> (<error>)
  ((field :type <string>)))

(def validation-exc
  (make <validation-error>
        :msg "Invalid email format"
        :field "email"))

(<error>? validation-exc)      ; => T
(<exception>? validation-exc)  ; => T
```

## Best Practices

1. **Use specific exception types** - Catch the most specific type appropriate for your error handling
2. **Provide descriptive messages** - Exception messages should clearly describe what went wrong
3. **Use `<panic>` sparingly** - Reserve for truly unrecoverable situations
4. **Use `<warning>` for non-critical issues** - Don't use exceptions for flow control
5. **Create custom exception classes** - For domain-specific error handling

## Integration with CLOS

Exception classes are full CLOS objects with the MOP available:

```clojure
;; Define exception with additional slots
(defclass* <network-error> (<error>)
  ((url :type <string>)
   (status-code :type <number>)))

;; Use in error handling
(defn fetch-url [url]
  (try
    (http-get url)
    (catch <network-error> e
      (println "Failed to fetch" (pslot-value e 'url)
               "with status" (pslot-value e 'status-code)))))
```

## See Also

- [Control Flow](control-flow.md) - For `try`, `catch`, and other control flow constructs
- [Special Forms](special-forms.md) - For `throw` special form
- [MOP](mop.md) - For creating custom exception classes
