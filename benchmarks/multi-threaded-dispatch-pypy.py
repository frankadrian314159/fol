#!/usr/bin/env python3
"""
Multi-threaded dispatch caching benchmark for PyPy
Tests how lock contention affects dispatch cache performance

Usage: pypy3 multi-threaded-dispatch-pypy.py
"""

import threading
import time
from enum import IntEnum
from typing import Dict, Callable, Tuple

class TestType(IntEnum):
    Int = 0
    String = 1
    List = 2
    Other = 3

def get_test_type(cycle_index: int) -> TestType:
    return TestType(cycle_index % 4)

# Dispatch functions (minimal work)
def dispatch_int(x: int) -> Tuple[str, int]:
    return ("int", x & 0xFF)

def dispatch_string(s: str) -> Tuple[str, int]:
    return ("string", len(s))

def dispatch_list(lst: list) -> Tuple[str, int]:
    return ("list", len(lst))

def dispatch_other() -> Tuple[str, int]:
    return ("other", 0)

# Uncached dispatch
def dispatch_uncached(test_type: TestType) -> Tuple[str, int]:
    match test_type:
        case TestType.Int:
            return dispatch_int(42)
        case TestType.String:
            return dispatch_string("test")
        case TestType.List:
            return dispatch_list([1, 2, 3])
        case TestType.Other:
            return dispatch_other()

# Cached dispatch with lock
_cache: Dict[TestType, Callable] = {}
_cache_lock = threading.Lock()
CALL_COUNT = 100000

def dispatch_cached(test_type: TestType) -> Tuple[str, int]:
    with _cache_lock:
        if test_type not in _cache:
            match test_type:
                case TestType.Int:
                    _cache[test_type] = lambda: dispatch_int(42)
                case TestType.String:
                    _cache[test_type] = lambda: dispatch_string("test")
                case TestType.List:
                    _cache[test_type] = lambda: dispatch_list([1, 2, 3])
                case TestType.Other:
                    _cache[test_type] = dispatch_other
        return _cache[test_type]()

# Worker thread: perform N dispatch calls
def worker_thread(uncached: bool) -> None:
    fn = dispatch_uncached if uncached else dispatch_cached
    for i in range(CALL_COUNT):
        fn(get_test_type(i))

# Benchmark runner
def run_benchmark(num_threads: int, uncached: bool) -> float:
    global _cache
    _cache.clear()

    threads = []
    start = time.perf_counter()

    for _ in range(num_threads):
        t = threading.Thread(target=worker_thread, args=(uncached,))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    elapsed = time.perf_counter() - start
    return elapsed * 1000  # Convert to ms

def main():
    print("================================")
    print("PyPy Multi-Threaded Dispatch Caching")
    print("================================\n")

    print("Test parameters:")
    print(f"  Calls per thread: {CALL_COUNT:,}")
    print("  Thread counts: 1, 2, 4, 8")
    print("  Workload: 4-type repeating cycle\n")

    # Warmup
    print("Warming up...")
    for _ in range(2):
        run_benchmark(2, True)
        run_benchmark(2, False)
    print("Warmup complete.\n")

    # Benchmark
    print("=== Uncached Dispatch ===")
    uncached_times = {}
    for num_threads in [1, 2, 4, 8]:
        time_ms = run_benchmark(num_threads, True)
        uncached_times[num_threads] = time_ms
        per_call = (time_ms / (CALL_COUNT * num_threads) * 1000)
        print(f"  {num_threads} thread{'s' if num_threads > 1 else ''}: {time_ms:7.2f} ms ({per_call:7.2f} µs/call/thread)")

    print("\n=== Cached Dispatch ===")
    cached_times = {}
    for num_threads in [1, 2, 4, 8]:
        time_ms = run_benchmark(num_threads, False)
        cached_times[num_threads] = time_ms
        per_call = (time_ms / (CALL_COUNT * num_threads) * 1000)
        print(f"  {num_threads} thread{'s' if num_threads > 1 else ''}: {time_ms:7.2f} ms ({per_call:7.2f} µs/call/thread)")

    # Summary
    print("\n=== Slowdown Scaling ===")
    for num_threads in [1, 2, 4, 8]:
        ratio = cached_times[num_threads] / uncached_times[num_threads]
        print(f"  {num_threads} thread{'s' if num_threads > 1 else ''}: {ratio:5.2f}x slowdown")

    print("\n================================")

if __name__ == "__main__":
    main()
