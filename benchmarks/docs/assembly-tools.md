# SBCL Assembly-Level Debugging Tools

This guide shows how to use SBCL's built-in tools to inspect machine code and performance characteristics.

## 1. DISASSEMBLE: View Function Machine Code

### Basic Usage

```lisp
;; Disassemble a named function
(disassemble 'dispatch-uncached)

;; Disassemble a lambda or compiled function object
(disassemble (lambda (x) (+ x 1)))

;; Disassemble with options
(disassemble 'dispatch-uncached :use-labels t)
```

### Output Format

```
Address | Instruction       | Operands          | Comment
───────────────────────────────────────────────────────
CDB5:   SUB RSP, 16         ; Stack frame setup
CDB9:   MOV [RBP-16], RBX   ; Save register
CDC1:   CMP QWORD PTR [RBP-8], -2000  ; Type test
CDF2:   JL L5               ; Jump if less than
```

### Key Assembly Instruction Categories

**Compare & Branch** (dispatch predicates):
- `CMP reg1, reg2` - Compare two values
- `JL label` - Jump if less than
- `JGE label` - Jump if greater or equal
- `JE label` - Jump if equal
- `JS label` - Jump if signed (negative)

**Arithmetic** (clause bodies):
- `ADD reg, imm` - Addition
- `SUB reg, imm` - Subtraction
- `SAR reg, imm` - Arithmetic shift right (fixnum division by 2)
- `MOV reg, value` - Load value into register

**Memory Access** (cache lookups):
- `MOV reg, [mem]` - Load from memory
- `MOV [mem], reg` - Store to memory
- `LEA reg, [mem]` - Load effective address

**Function Calls** (overhead):
- `CALL [reg-offset]` - Indirect function call (expensive!)
- `RET` - Return from function

### Performance Analysis from Disassembly

1. **Count the instructions** in the hot path (uncached vs cached)
2. **Identify function calls** - each `CALL` adds 10-20 cycles
3. **Identify memory accesses** - each `MOV [mem]` can be 5-10 cycles
4. **Look for indirect jumps** - `JMP [reg]` or `CALL [reg]` destroy branch prediction

## 2. SB-SPROF: Statistical Profiler

### Usage

```lisp
(require 'sb-sprof)

;; Start profiling
(sb-sprof:start-profiling :mode :time)

;; Run your code
(loop for i from 0 below 1000000
      do (dispatch-uncached i))

;; Stop and report
(sb-sprof:report)
```

### Output

```
; Total time: 100.02 seconds
; Mode: TIME
; Time in other system code: 0.36 seconds

; Seconds |  GC  |Count
;───────────────────────────────────────────
;  98.52  | 0.35 |100000 DISPATCH-UNCACHED
;   0.98  |      | 1000 LOOP
;   0.16  |      |    5 SB-IMPL::HALT
```

### Key Metrics

- **Seconds**: Total time spent in function
- **GC**: Time spent in garbage collection
- **Count**: Number of times function was called

### What to Look For

- **Which functions dominate?** If dispatch is <5%, overhead isn't the problem
- **GC column**: If high, the code is causing allocation pressure (cache key creation!)
- **Count**: Should match your loop count

## 3. SB-PROF: Function Call Profiler

For more detailed analysis of function calls:

```lisp
(require 'sb-prof)

(sb-prof:profile 'dispatch-cached 'dispatch-uncached)

;; Run code
(time (loop for i from 0 below 1000000 do (dispatch-cached i)))

;; Report
(sb-prof:report)

(sb-prof:unprofile)
```

## 4. TIME: Measure Execution Time

Built-in timing macro:

```lisp
(time (loop for i from 0 below 1000000
            sum (dispatch-uncached i)))

;Evaluation took:
;  0.023 seconds of real time
;  0.022896 seconds of total run time (0.022567 user, 0.000329 system)
;  99.57% CPU
;  75,283,952 processor cycles
;  22,157,376 bytes consed  ← Memory allocation (cache key creation!)
```

### Key Metrics from TIME

- **Real time**: Wall-clock time
- **Run time**: CPU time (user + system)
- **Processor cycles**: CPU cycles executed
- **Bytes consed**: Memory allocated (indicator of allocation overhead)

**For caching analysis**:
- High "bytes consed" indicates cache key allocation overhead
- Cached version should have 100-1000x higher allocation if creating lists

## 5. COMPILE-FILE with Trace Output

Get detailed compiler output:

```lisp
;; See how code is being compiled
(sb-ext:restrict-compiler-switches :inline :off)  ; Disable inlining to see actual calls
(compile-file "dispatch.lisp")  ; Observe compiler notes
```

### Reading Compiler Notes

```
; Note: Inlining DISPATCH-UNCACHED
; Note: Specializing (< X 0) to machine operation
; Note: Reusing CONS from inline cache
```

These notes tell you:
- Whether functions are being inlined (good for small functions)
- Whether type predicates are being optimized (good for dispatch)
- Whether allocations are detected (bad for performance)

## 6. Detailed Example: Profiling Cache Overhead

```lisp
(require 'sb-sprof)

(format t "~%UNCACHED DISPATCH PROFILE:~%")
(sb-sprof:start-profiling :mode :time)
(time (loop for i from 0 below 1000000 do (dispatch-uncached i)))
(sb-sprof:report)
(sb-sprof:stop-profiling)

(format t "~%CACHED DISPATCH PROFILE:~%")
(sb-sprof:start-profiling :mode :time)
(time (loop for i from 0 below 1000000 do (dispatch-cached i)))
(sb-sprof:report)
(sb-sprof:stop-profiling)

;; Compare: cached should show higher allocation in "bytes consed"
```

Expected output:
```
UNCACHED: 10 ms, 0 bytes consed       ← Zero allocation overhead
CACHED:   50 ms, 45,000,000 bytes     ← Huge allocation from cache keys!
```

## 7. Assembly Inspection with SB-DISASSEM

Low-level assembly with syntax highlighting:

```lisp
(require 'sb-disassem)

;; Show assembly with annotations
(disassemble 'dispatch-uncached :use-labels t :stream t)
```

Look for:
- **`CALL [reg]`**: Indirect function call (expensive, unpredictable)
- **`SUB RSP, 16`**: Stack frame (overhead)
- **Repeated `MOV` chains**: Pointer chasing (memory latency)
- **Sequential `CMP` + `J*`**: Good (branch-prediction friendly)

## 8. Using SBCL's Profiling Output for Paper

Extract useful metrics:

```lisp
(defun profile-dispatch-pair ()
  "Profile both versions and extract key metrics"
  (let ((uncached-time nil) (uncached-cycles nil) (uncached-cons nil))
    ;; Profile uncached
    (sb-sprof:start-profiling :mode :time)
    (let ((start-cycles (sb-impl::get-internal-run-time)))
      (loop for i from 0 below 1000000 do (dispatch-uncached i))
      (setf uncached-time (- (sb-impl::get-internal-run-time) start-cycles)))
    (sb-sprof:report :stream (make-string-output-stream))
    (sb-sprof:stop-profiling)
    
    ;; Profile cached
    (sb-sprof:start-profiling :mode :time)
    (let ((start-cycles (sb-impl::get-internal-run-time)))
      (loop for i from 0 below 1000000 do (dispatch-cached i))
      (setf cached-time (- (sb-impl::get-internal-run-time) start-cycles)))
    (sb-sprof:report :stream (make-string-output-stream))
    (sb-sprof:stop-profiling)
    
    ;; Output for paper
    (format t "Dispatch Overhead Analysis~%")
    (format t "~%Time per call (microseconds):~%")
    (format t "  Uncached: ~,2F µs~%" (/ uncached-time 1000.0))
    (format t "  Cached:   ~,2F µs~%" (/ cached-time 1000.0))))
```

## Tips for Analysis

1. **Always use `(optimize (speed 3) (safety 0))`** - matches production code
2. **Run multiple times** - first run includes compilation, later runs are warmed up
3. **Disable GC during measurement** - use `(sb-ext:gc-off)`
4. **Compare equivalent code** - make sure both versions do the same amount of work
5. **Look at disassembly** - numbers don't lie, but assembly tells the story
6. **Check memory allocation** - `bytes consed` often reveals the real bottleneck

## References

- [SBCL Manual: Disassembly](http://sbcl.org/manual/#Introspection)
- [SBCL Manual: Profiling](http://sbcl.org/manual/#Profiling)
- [x86-64 Instruction Reference](https://www.felixcloutier.com/x86/)

---

**Last Updated**: 2026-05-12  
**SBCL Version**: 2.6.0  
**Tested On**: Windows 11, Linux (x86-64)
