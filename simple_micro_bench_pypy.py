#!/usr/bin/env python3
"""
Micro-benchmark: homogeneous dispatch (Python version, high iterations)
"""

import time

CACHE_SIZE = 8

class DispatchCache:
    def __init__(self):
        self.entries = [None] * CACHE_SIZE
        self.next_idx = 0

    def lookup(self, key):
        for i in range(CACHE_SIZE):
            entry = self.entries[i]
            if entry is not None and entry[0] == key:
                return entry[1]
        return None

    def insert(self, key, fn):
        self.entries[self.next_idx] = (key, fn)
        self.next_idx = (self.next_idx + 1) % CACHE_SIZE

def clause_long(x):
    return ('long', x)

def clause_other(x):
    return ('other', x)

cache = DispatchCache()

def dispatch_uncached(x):
    """Uncached homogeneous dispatcher"""
    if isinstance(x, (int, float)):
        return clause_long(x)
    else:
        return clause_other(x)

def dispatch_cached(x):
    """Cached homogeneous dispatcher"""
    key = 'long' if isinstance(x, (int, float)) else 'other'
    hit = cache.lookup(key)
    if hit is not None:
        return hit(x)

    if isinstance(x, (int, float)):
        cache.insert(key, clause_long)
        return clause_long(x)
    else:
        cache.insert(key, clause_other)
        return clause_other(x)

# Test data: 2,000,000 numbers
test_data = [i % 1000000 for i in range(2000000)]

def benchmark_uncached(iterations: int):
    times = []
    for run in range(iterations):
        start = time.perf_counter()
        for item in test_data:
            dispatch_uncached(item)
        elapsed = time.perf_counter() - start
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({elapsed*1e9/len(test_data):.1f} ns/call)")
        times.append(elapsed)
    return times

def benchmark_cached(iterations: int):
    times = []
    for run in range(iterations):
        start = time.perf_counter()
        for item in test_data:
            dispatch_cached(item)
        elapsed = time.perf_counter() - start
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({elapsed*1e9/len(test_data):.1f} ns/call)")
        times.append(elapsed)
    return times

def run_all_benchmarks():
    print("\n================================")
    print("Python Homogeneous Dispatch Caching Micro-Benchmark")
    print("================================")
    import sys
    print(f"Implementation: Python {sys.version.split()[0]}")
    print("Test data: 2,000,000 number-only calls\n")

    print("Warming up (10,000 calls)...")
    for i in range(10000):
        dispatch_uncached(test_data[i])
    for i in range(10000):
        dispatch_cached(test_data[i])
    print("Warmup complete.\n")

    print("=== Uncached Dispatch (3 iterations) ===")
    benchmark_uncached(3)

    print("\n=== Cached Dispatch (3 iterations) ===")
    benchmark_cached(3)

    print("\n================================")
    print("Benchmark Complete")
    print("================================")

if __name__ == "__main__":
    run_all_benchmarks()
