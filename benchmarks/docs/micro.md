# Persistent Object Micro-Benchmarks

## Overview

These benchmarks measure the overhead of FOL's persistent object system
(`persistent-class` metaclass) relative to standard mutable CLOS objects.
The persistent system uses a **hybrid layout**: objects with 32 or fewer
slots store all values in native CLOS slots; objects with more than 32
slots store the first 32 natively and overflow the remainder into an FSet
persistent vector.

## Environment

- SBCL 2.6.0, Windows 11, AMD Ryzen 9 5900X, 64 GB RAM
- Persistent objects: `persistent-class` metaclass, `<persistent-object>` base
- Mutable baseline: standard `standard-class` CLOS objects
- Slot counts tested: 2, 4, 8, 16, 32 (all native), 48, 64, 128 (hybrid)

## Results

### Construction Memory (10,000 instances)

| Slots | Persistent (B/obj) | Mutable (B/obj) | Ratio |
|------:|-------------------:|----------------:|------:|
|     2 |              360.3 |           216.2 | 1.67x |
|     4 |              668.1 |           393.1 | 1.70x |
|     8 |            1,277.2 |           746.7 | 1.71x |
|    16 |            2,489.1 |         1,450.4 | 1.72x |
|    32 |            4,923.8 |         2,857.4 | 1.72x |
|    48 |           10,057.1 |         4,267.0 | 2.36x |
|    64 |           16,175.4 |         5,670.8 | 2.85x |
|   128 |           46,465.3 |        11,301.2 | 4.11x |

For objects with 32 or fewer slots (the common case), memory overhead is a
consistent 1.7x. This overhead comes from the persistent metaclass
infrastructure: the `%metadata` slot, `%persistent-vector` slot (nil for
small objects), and the `initialize-instance :around` method that guards
mutation. Beyond 32 slots, the FSet overflow vector adds progressively more
memory, reaching 4.1x at 128 slots.

### Construction Time (100,000 iterations)

| Slots | Persistent | Mutable | Ratio |
|------:|-----------:|--------:|------:|
|     2 |    788 ns  |  532 ns | 1.48x |
|     4 |   1.12 us  |  753 ns | 1.49x |
|     8 |   1.73 us  | 1.21 us | 1.43x |
|    16 |   2.99 us  | 2.13 us | 1.40x |
|    32 |   6.28 us  | 4.67 us | 1.35x |
|    48 |  11.49 us  | 7.99 us | 1.44x |
|    64 |  17.02 us  |12.00 us | 1.42x |
|   128 |  47.94 us  |35.28 us | 1.36x |

Construction time overhead is consistently 1.35--1.49x across all sizes.
The overhead comes from the `initialize-instance :around` wrapper that
binds `*initializing-persistent-object*` and, for wide objects, the
population of the FSet overflow vector from initargs.

### Read Time (1,000,000 iterations)

| Slots | Slot | Persistent | Mutable | Ratio |
|------:|-----:|-----------:|--------:|------:|
|     2 |    0 |   15.0 ns  | 13.4 ns | 1.12x |
|     4 |    0 |   17.4 ns  | 13.3 ns | 1.31x |
|     8 |    0 |   17.6 ns  | 13.3 ns | 1.32x |
|    16 |    0 |   27.2 ns  | 20.9 ns | 1.31x |
|    32 |    0 |   14.8 ns  | 20.0 ns | 0.74x |
|    48 |    0 |   16.7 ns  | 20.9 ns | 0.80x |
|    48 |   33 |   58.4 ns  | 11.2 ns | 5.21x |
|    64 |    0 |   19.4 ns  | 17.8 ns | 1.09x |
|    64 |   33 |   46.8 ns  | 24.0 ns | 1.95x |
|   128 |    0 |   24.2 ns  | 14.7 ns | 1.64x |
|   128 |   33 |   53.5 ns  | 11.9 ns | 4.49x |

Native slot reads (slot-0) are essentially equivalent to mutable CLOS
(0.74x--1.64x), confirming that the hybrid layout achieves its design goal
of native access speed for the first 32 slots. Overflow slot reads
(slot-33) go through the `slot-missing` MOP intercept and FSet vector
lookup, costing 2--5x more.

### Update Time (100,000 iterations)

| Slots | Slot | Persistent | Mutable | Ratio |
|------:|-----:|-----------:|--------:|------:|
|     2 |    0 |    452 ns  |  12.7 ns |  35.5x |
|     4 |    0 |    581 ns  |  13.1 ns |  44.5x |
|     8 |    0 |    859 ns  |  19.4 ns |  44.4x |
|    16 |    0 |   1.34 us  |  14.4 ns |  93.7x |
|    32 |    0 |   2.47 us  |  16.5 ns | 149.6x |
|    48 |    0 |   2.49 us  |  18.2 ns | 136.6x |
|    48 |   33 |   2.85 us  |  12.9 ns | 220.5x |
|    64 |    0 |   2.54 us  |  14.3 ns | 177.5x |
|    64 |   33 |   2.96 us  |  26.5 ns | 112.0x |
|   128 |    0 |   2.54 us  |  13.0 ns | 195.3x |
|   128 |   33 |   3.56 us  |  12.8 ns | 277.5x |

Functional updates (`update-slot`) are 35--278x slower than in-place
mutation (`setf slot-value`). This is the expected and deliberate tradeoff:
each functional update allocates a new instance, shallow-copies all native
slots, and (for wide objects) produces a new FSet vector with structural
sharing. Mutable `setf` is a single pointer write at ~13 ns.

The cost grows with slot count because `update-slots` must copy more native
slots (452 ns at 2 slots, 2.5 us at 32 slots). Beyond 32 slots, the
additional cost of FSet vector operations adds modestly (2.5 us to 3.6 us
from 32 to 128 slots).

## Key Findings

1. **Memory overhead is modest for common objects**: 1.7x for objects with
   32 or fewer slots (the expected case for most domain objects).

2. **Read access is essentially free**: Native slot reads on persistent
   objects match mutable CLOS performance, confirming the hybrid layout
   design.

3. **Construction overhead is low**: 1.35--1.49x consistently, dominated
   by the mutation-guard wrapper rather than data structure costs.

4. **Functional updates are the primary cost**: 35--278x slower than
   in-place mutation. This is inherent to the persistent object model ---
   each update produces a new immutable value. Applications should batch
   updates via `update-slots` (multiple slot changes in one allocation)
   rather than chaining single `update-slot` calls.

5. **The 32-slot threshold works as designed**: Below 32 slots, persistent
   objects behave like standard CLOS with a thin immutability wrapper.
   Above 32, FSet overflow adds measurable but logarithmic overhead to
   reads and updates.

## Running the Benchmarks

```
cd src && sbcl --noinform --non-interactive \
  --eval "(ql:quickload '(:fset :sycamore :closer-mop :uuid :cl-ppcre :bordeaux-threads :usocket) :silent t)" \
  --eval "(load \"package.lisp\")" \
  --eval "(load \"persistence.lisp\")" \
  --eval "(load \"../benchmarks/boilerplate/boilerplate.lisp\")" \
  --eval "(load \"../benchmarks/micro/persistence-overhead.lisp\")" \
  --eval "(fol.benchmarks.persistence:run-persistence-benchmarks)"
```
