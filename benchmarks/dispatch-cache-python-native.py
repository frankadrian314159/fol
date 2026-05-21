#!/usr/bin/env python3
"""
Python native dispatch caching benchmark using switch-case pattern (Python 3.10+)
"""
import time
from enum import IntEnum
from typing import Dict, Callable, Tuple

class TestType(IntEnum):
    Int = 0
    String = 1
    Vector = 2
    Other = 3

def get_type(cycle_index: int) -> TestType:
    return TestType(cycle_index % 4)

def dispatch_uncached(test_type: TestType) -> Tuple[str, int]:
    match test_type:
        case TestType.Int:
            return ("int", 42)
        case TestType.String:
            return ("string", 11)
        case TestType.Vector:
            return ("vector", 5)
        case TestType.Other:
            return ("other", 0)

def dispatch_cached(test_type: TestType, cache: Dict[TestType, Callable]) -> Tuple[str, int]:
    if test_type in cache:
        return cache[test_type]()

    handlers = {
        TestType.Int: lambda: ("int", 42),
        TestType.String: lambda: ("string", 11),
        TestType.Vector: lambda: ("vector", 5),
        TestType.Other: lambda: ("other", 0),
    }

    handler = handlers[test_type]
    cache[test_type] = handler
    return handler()

def main():
    TOTAL_CALLS = 2_000_000
    CYCLE_SIZE = 4
    WARMUP = 100_000

    test_data = [TestType(i % 4) for i in range(TOTAL_CALLS)]

    print("================================")
    print("Python Dispatch Caching Micro-Benchmark (native match)")
    print("================================")
    print(f"Test data: {TOTAL_CALLS:,} calls over repeating {CYCLE_SIZE}-type cycle\n")

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

    print("\n================================")
    print(f"Average uncached: {avg_uncached_ns_per_call:.1f} ns/call")
    print(f"Average cached: {avg_cached_ns_per_call:.1f} ns/call")
    print(f"Slowdown ratio: {ratio:.2f}×")
    print("================================")

if __name__ == "__main__":
    main()
