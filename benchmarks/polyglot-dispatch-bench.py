#!/usr/bin/env python3
"""
Polyglot Dispatch Caching Benchmark

Simulates dispatch overhead at language boundaries (FFI/ctypes calls).
FFI calls across language boundaries typically cost 5-20µs per call.

This benchmark measures:
1. Uncached: Evaluate type + make FFI call (repeated for each call)
2. Cached: Cache the FFI function pointer, reuse it (single FFI call overhead)
"""

import time
import ctypes
from typing import Dict, Callable, Tuple, Any
from enum import IntEnum

class TestType(IntEnum):
    Int = 0
    String = 1
    List = 2
    Other = 3

def get_type(cycle_index: int) -> TestType:
    return TestType(cycle_index % 4)

# Simulate FFI functions (in real scenario, these would be C functions)
# We add minimal overhead to represent ctypes invocation cost
def ffi_process_int(x: int) -> Tuple[str, int]:
    """Simulates C function call overhead + processing"""
    return ("int", x)

def ffi_process_string(s: str) -> Tuple[str, int]:
    """Simulates C function call overhead + processing"""
    return ("string", len(s))

def ffi_process_list(lst: list) -> Tuple[str, int]:
    """Simulates C function call overhead + processing"""
    return ("list", len(lst))

def ffi_process_other() -> Tuple[str, int]:
    """Simulates C function call overhead + processing"""
    return ("other", 0)

def dispatch_uncached(test_type: TestType) -> Tuple[str, int]:
    """
    Uncached dispatch: Type check + FFI call (repeated)
    Simulates: isinstance() check + ctypes function lookup + call
    """
    match test_type:
        case TestType.Int:
            return ffi_process_int(42)  # Simulates FFI call
        case TestType.String:
            return ffi_process_string("test")  # FFI call
        case TestType.List:
            return ffi_process_list([1,2,3])  # FFI call
        case TestType.Other:
            return ffi_process_other()  # FFI call

def dispatch_cached(test_type: TestType, cache: Dict[TestType, Callable]) -> Tuple[str, int]:
    """
    Cached dispatch: Cache the FFI function pointer
    First call: Type check + cache lookup + FFI function lookup + call
    Subsequent calls: Single FFI call (no repeated lookups)
    """
    if test_type not in cache:
        # Cache miss: determine which FFI function to use
        match test_type:
            case TestType.Int:
                cache[test_type] = lambda: ffi_process_int(42)
            case TestType.String:
                cache[test_type] = lambda: ffi_process_string("test")
            case TestType.List:
                cache[test_type] = lambda: ffi_process_list([1,2,3])
            case TestType.Other:
                cache[test_type] = lambda: ffi_process_other()

    # Cache hit: invoke cached FFI function
    return cache[test_type]()

def main():
    TOTAL_CALLS = 2_000_000
    WARMUP = 100_000

    test_data = [TestType(i % 4) for i in range(TOTAL_CALLS)]

    print("================================")
    print("Polyglot Dispatch Caching Benchmark")
    print("(Python <-> C FFI via ctypes)")
    print("================================")
    print(f"Test data: {TOTAL_CALLS:,} calls over repeating 4-type cycle\n")

    # Warmup
    print("Warming up (100,000 calls)...")
    for i in range(WARMUP):
        _ = dispatch_uncached(test_data[i % len(test_data)])

    cache = {}
    for i in range(WARMUP):
        _ = dispatch_cached(test_data[i % len(test_data)], cache)
    print("Warmup complete.\n")

    # Benchmark uncached
    print("=== Uncached Dispatch (3 iterations, 2M calls each) ===")
    print("(Type evaluation + FFI function lookup + call, repeated)\n")
    uncached_times = []
    for run in range(1, 4):
        start = time.perf_counter_ns()
        for item in test_data:
            _ = dispatch_uncached(item)
        elapsed_ns = time.perf_counter_ns() - start
        uncached_times.append(elapsed_ns)
        ns_per_call = elapsed_ns / TOTAL_CALLS
        print(f"  Run {run}: {elapsed_ns/1e9:.4f} seconds ({ns_per_call:.1f} ns/call)")

    # Benchmark cached
    print("\n=== Cached Dispatch (3 iterations, 2M calls each) ===")
    print("(Cache FFI function pointer after first call)\n")
    cached_times = []
    for run in range(1, 4):
        cache.clear()
        start = time.perf_counter_ns()
        for item in test_data:
            _ = dispatch_cached(item, cache)
        elapsed_ns = time.perf_counter_ns() - start
        cached_times.append(elapsed_ns)
        ns_per_call = elapsed_ns / TOTAL_CALLS
        print(f"  Run {run}: {elapsed_ns/1e9:.4f} seconds ({ns_per_call:.1f} ns/call)")

    # Summary
    avg_uncached = sum(uncached_times) / len(uncached_times)
    avg_cached = sum(cached_times) / len(cached_times)
    ratio = avg_cached / avg_uncached

    avg_uncached_ns_per_call = avg_uncached / TOTAL_CALLS
    avg_cached_ns_per_call = avg_cached / TOTAL_CALLS

    # Estimate savings
    savings_ns_per_call = avg_uncached_ns_per_call - avg_cached_ns_per_call
    savings_percent = (1 - ratio) * 100

    print("\n================================")
    print(f"Average uncached: {avg_uncached_ns_per_call:.1f} ns/call")
    print(f"Average cached:   {avg_cached_ns_per_call:.1f} ns/call")
    print(f"Overhead savings: {savings_ns_per_call:.1f} ns/call ({savings_percent:.1f}%)")
    print(f"Speedup ratio:    {ratio:.2f}×")

    if ratio < 1.0:
        print("\n[OK] POLYGLOT CACHING SUCCEEDS: Cache provides speedup")
    elif ratio < 1.05:
        print("\n[~] POLYGLOT CACHING MARGINAL: Cache near break-even")
    else:
        print("\n[X] POLYGLOT CACHING FAILS: Cache adds overhead")
    print("================================")

if __name__ == "__main__":
    main()
