# core.async

FOL's `core.async` library (`fol.lib.core-async`) provides CSP-style (Communicating Sequential Processes) concurrency through channels and lightweight blocks. The API mirrors Clojure's `core.async`.

---

## Implementation Notes

| Clojure | FOL |
|---------|-----|
| Go blocks run as JVM green threads (coroutines) | Go blocks are real OS threads (`bordeaux-threads`) |
| `>!` / `<!` are park-able (only valid in `go`) | `>!` / `<!` are identical to `>!!` / `<!!` (all threads) |
| `alts!` uses a wait-graph | `alts!!` uses polling with exponential backoff |
| Transducers via `clojure.core/transduce` | Transducers via `(xf rf) → step-fn` CL protocol |

---

## Buffer Types

Channels can be unbuffered or carry one of three buffer types.

### `buffer`                                                         *[function]*

```
(buffer n) → fixed-buf
```

Create a fixed buffer of size `n`. Puts **block** when the buffer is at capacity.

### `dropping-buffer`                                                *[function]*

```
(dropping-buffer n) → dropping-buf
```

Create a dropping buffer of size `n`. Puts **never block**; excess items are silently discarded.

### `sliding-buffer`                                                 *[function]*

```
(sliding-buffer n) → sliding-buf
```

Create a sliding buffer of size `n`. Puts **never block**; the oldest item is evicted to make room.

---

## Channel Construction

### `chan`                                                           *[function]*

```
(chan)                        ; unbuffered rendezvous channel
(chan n)                      ; fixed buffer of size n
(chan (buffer n))             ; same as (chan n)
(chan (dropping-buffer n))    ; dropping buffer
(chan (sliding-buffer n))     ; sliding buffer
(chan buf-or-n xf)            ; buffered channel with transducer
(chan buf-or-n xf ex-handler) ; with error handler for transducer exceptions
```

Create a new channel. The optional `xf` is a transducer applied to items as they enter the buffer. `ex-handler` is called with any error thrown by `xf`; if it returns a non-nil value, that value is put into the channel instead.

**Examples**

```fol
(let [ch1 (chan)]          ; unbuffered
      ch2 (chan 10)        ; 10-item fixed buffer
      ch3 (chan (dropping-buffer 5))
      ch4 (chan 8 (map inc))]  ; filter using transducer
  ...)
```

---

## Closing

### `close!`                                                         *[function]*

```
(close! ch) → nil
```

Close channel `ch`. Pending takers receive `nil`. Pending putters are discarded. Idempotent — calling `close!` on an already-closed channel is safe.

### `closed?`                                                        *[function]*

```
(closed? ch) → boolean
```

Return `t` if `ch` is closed, `nil` otherwise.

---

## Blocking Operations

These operations block the calling thread. They are safe to call from any thread.

### `>!!`                                                            *[function]*

```
(>!! ch value) → t | nil
```

Put `value` into `ch`, blocking until a taker is ready or the buffer has space.
Returns `t` if the value was accepted, `nil` if `ch` is closed.

`>!` is an alias for `>!!` in this implementation.

### `<!!`                                                            *[function]*

```
(<!! ch) → value | nil
```

Take a value from `ch`, blocking until one is available or `ch` is closed.
Returns the value, or `nil` if `ch` is closed and empty.

`<!` is an alias for `<!!` in this implementation.

**Example — producer/consumer**

```fol
(let [ch (chan 4)]
  (go
    (>!! ch 1)
    (>!! ch 2)
    (>!! ch 3)
    (close! ch))
  (loop
    (let [v (<!! ch)]
      (if (nil? v)
          (println "done")
          (do (println v) (recur))))))
```

---

## Non-Blocking Operations

### `offer!`                                                         *[function]*

```
(offer! ch value) → t | nil
```

Attempt to put `value` into `ch` without blocking.
Returns `t` if accepted (buffer had space or a taker was waiting), `nil` otherwise.
Always returns `t` for dropping/sliding buffers (items may be dropped/evicted).

### `poll!`                                                         *[function]*

```
(poll! ch) → (values value t) | (values nil nil)
```

Attempt to take a value from `ch` without blocking.
Returns `(values value t)` if a value was immediately available, `(values nil nil)` otherwise.

---

## Go Blocks

### `go`                                                             *[macro]*

```
(go body*) → result-channel
```

Execute `body` in a new OS thread. Returns a channel (buffered, size 1) that delivers the result of the last expression. The result channel is closed after delivering the value.

```fol
(let [result (<!! (go (+ 1 2)))]
  (println result))  ; 3
```

### `go-loop`                                                        *[macro]*

```
(go-loop [var init ...] body*) → result-channel
```

Start a `go` block containing a named loop. `bindings` provides initial values for loop variables. Use `(recur new-val ...)` at tail position to iterate.

```fol
(go-loop [i 0 acc 0]
  (if (> i 100)
      acc
      (recur (inc i) (+ acc i))))
```

### `thread`                                                         *[macro]*

```
(thread body*) → result-channel
```

Run `body` in a new OS thread. Identical to `go` but semantically signals intent to use a full thread (not a lightweight block). Returns a result channel.

### `thread-call`                                                    *[function]*

```
(thread-call f) → result-channel
```

Run `(funcall f)` in a new thread. Returns a result channel.

---

## Timing

### `timeout`                                                        *[function]*

```
(timeout ms) → channel
```

Return a channel that closes after `ms` milliseconds. Taking from a timeout channel blocks until it closes, returning `nil`. Typically used with `alts!!` to implement timeouts.

```fol
(alts!! [result-ch (timeout 5000)])
```

---

## Combinators

### `onto-chan!!`                                                     *[function]*

```
(onto-chan!! ch coll &optional (close-p t)) → ch
```

Put each element of `coll` into `ch`, blocking between puts. Closes `ch` when done (unless `close-p` is `nil`). Returns `ch`.

### `onto-chan`                                                       *[function]*

```
(onto-chan ch coll &optional (close-p t)) → done-channel
```

Asynchronously put each element of `coll` into `ch` in a go block. Returns a channel that closes when all items have been put.

### `to-chan!!`                                                       *[function]*

```
(to-chan!! coll) → channel
```

Return a channel pre-loaded with all elements of `coll`. The channel is closed after the last element. Blocks the calling thread while loading.

### `to-chan`                                                        *[function]*

```
(to-chan coll) → channel
```

Asynchronous version of `to-chan!!`. Returns immediately with a channel that will receive all elements.

```fol
(let [ch (to-chan!! '(1 2 3))]
  (println (<!! ch))  ; 1
  (println (<!! ch))  ; 2
  (println (<!! ch))) ; 3
```

---

## Multi-Channel Operations

### `alts!!`                                                         *[function]*

```
(alts!! ops &key priority default) → (values result channel)
```

Block until one operation in `ops` is ready, then perform it.

Each element of `ops` is either:
- A bare channel — a **take** from that channel
- `(channel value)` — a **put** of `value` into that channel

Returns `(values result channel)` where `result` is the value taken (or `t`/`nil` for puts), and `channel` is the channel that fired.

| Keyword | Description |
|---------|-------------|
| `:priority t` | Try ops in order rather than random order |
| `:default v` | If no op is immediately ready, return `(values v nil)` without blocking |

`alts!` is an alias for `alts!!`.

```fol
(let [t-ch (timeout 1000)
      data-ch (async-fetch url)]
  (multiple-value-bind [result ch]
      (alts!! [data-ch t-ch])
    (if (= ch t-ch)
        (println "timed out")
        (println result))))
```

---

## Pipelines

### `pipe`                                                           *[function]*

```
(pipe from to &optional (close-p t)) → to
```

Take all values from `from` and put them into `to` in a dedicated go block. Closes `to` when `from` closes (unless `close-p` is `nil`). Returns `to`.

### `pipeline`                                                       *[function]*

```
(pipeline n to xf from &optional (close-p t) ex-handler) → to
```

Apply transducer `xf` to values from `from` and put results into `to`, using up to `n` parallel go blocks for processing.

| Parameter | Description |
|-----------|-------------|
| `n` | Degree of parallelism |
| `to` | Output channel |
| `xf` | Transducer (e.g. `(map f)`, `(filter p)`) |
| `from` | Input channel |
| `close-p` | Close `to` when `from` exhausts (default `t`) |
| `ex-handler` | `(err) → value` called on transducer errors |

### `pipeline-async`                                                 *[function]*

```
(pipeline-async n to af from &optional (close-p t)) → to
```

Like `pipeline` but each item is processed by calling `(af value result-ch)`. `af` should put its result(s) into `result-ch` and then close it. `n` parallel go blocks run `af` concurrently.

### `merge`                                                          *[function]*

```
(merge chs &optional (buf-or-n 0)) → output-channel
```

Merge a list of source channels `chs` into a single output channel. All values from every source are forwarded. The output channel closes when all sources are closed. `buf-or-n` controls the output buffer size.

```fol
(let [out (merge [ch1 ch2 ch3] 8)]
  (loop
    (let [v (<!! out)]
      (when (some? v)
        (process v)
        (recur)))))
```

---

## Pub/Sub

### `pub`                                                            *[function]*

```
(pub ch topic-fn &optional buf-fn) → publication
```

Create a publication from source channel `ch`. `topic-fn` maps each value to a topic key (compared with `equal`). Values are dispatched to all subscribers for the matching topic in a background thread.

### `sub`                                                            *[function]*

```
(sub p topic ch) → ch
```

Subscribe channel `ch` to `topic` on publication `p`. Values matching `topic` from the source are put into `ch`. Returns `ch`.

### `unsub`                                                          *[function]*

```
(unsub p topic ch) → nil
```

Remove `ch` from the subscribers for `topic` on publication `p`.

### `unsub-all`                                                      *[function]*

```
(unsub-all p &optional topic) → nil
```

Remove all subscribers for `topic` from publication `p`, or clear all subscriptions if `topic` is omitted.

**Example — pub/sub fan-out**

```fol
(let [src   (chan 8)
      p     (pub src (fn [v] (:type v)))
      errors (chan 8)
      info   (chan 8)]
  (sub p :error errors)
  (sub p :info  info)
  (go-loop []
    (let [v (<!! errors)]
      (when (some? v)
        (log-error v)
        (recur))))
  (go-loop []
    (let [v (<!! info)]
      (when (some? v)
        (log-info v)
        (recur)))))
```

---

## Transducer Protocol

Transducers are one-argument functions: `(xf rf) → step-fn`.
The step-fn has signature `(result input) → result`.
For channels, `result` is the channel struct (ignored) and `input` is the value being added.

```fol
; Map transducer: double every value
(let [xf (fn [rf]
           (fn [result item]
             (rf result (* item 2))))
      ch  (chan 4 xf)]
  (offer! ch 5)
  (<!! ch))   ; => 10
```

Standard Clojure transducer combinators (`map`, `filter`, `take`, `drop`, etc.) from `fol.compiler.transducers` work directly with `chan`.
