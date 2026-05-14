#!/usr/bin/env python3
"""
Micro-benchmark: homogeneous dispatch (Python version)
All dispatches on numbers (int) only
"""

import time
import random
from typing import Any, List

# Cache configuration
CACHE_SIZE = 8

class DispatchCache:
    """Simple round-robin dispatch cache"""
    def __init__(self):
        self.entries = [None] * CACHE_SIZE
        self.next_idx = 0
        self.hits = 0
        self.misses = 0

    def lookup(self, key):
        """Look up a cache entry by key"""
        for i in range(CACHE_SIZE):
            entry = self.entries[i]
            if entry is not None and entry[0] == key:
                return entry[1]
        return None

    def insert(self, key, fn):
        """Insert a cache entry"""
        self.entries[self.next_idx] = (key, fn)
        self.next_idx = (self.next_idx + 1) % CACHE_SIZE

def clause_long(x):
    return ('long', x)

def clause_string(x):
    return ('string', len(x))

def clause_list(x):
    return ('list', len(x))

def clause_dict(x):
    return ('dict', len(x))

def clause_symbol(x):
    return ('symbol', x)

def clause_other(x):
    return ('other', x)

# Cache instance
homo_cache = DispatchCache()

def dispatch_homo_uncached(x):
    """Uncached homogeneous dispatcher"""
    if isinstance(x, (int, float)):
        return ('long', x)
    elif isinstance(x, str):
        return ('string', len(x))
    elif isinstance(x, list):
        return ('list', len(x))
    elif isinstance(x, dict):
        return ('dict', len(x))
    elif isinstance(x, tuple) and len(x) == 1 and isinstance(x[0], str):
        return ('symbol', x)
    else:
        return ('other', x)

def dispatch_homo_cached(x):
    """Cached homogeneous dispatcher"""
    # Determine type key
    if isinstance(x, (int, float)):
        key = 'long'
    elif isinstance(x, str):
        key = 'string'
    elif isinstance(x, list):
        key = 'list'
    elif isinstance(x, dict):
        key = 'dict'
    elif isinstance(x, tuple) and len(x) == 1 and isinstance(x[0], str):
        key = 'symbol'
    else:
        key = 'other'

    # Check cache
    hit = homo_cache.lookup(key)
    if hit is not None:
        homo_cache.hits += 1
        return hit(x)

    # Cache miss - dispatch and cache the result
    homo_cache.misses += 1
    if isinstance(x, (int, float)):
        homo_cache.insert(key, clause_long)
        return clause_long(x)
    elif isinstance(x, str):
        homo_cache.insert(key, clause_string)
        return clause_string(x)
    elif isinstance(x, list):
        homo_cache.insert(key, clause_list)
        return clause_list(x)
    elif isinstance(x, dict):
        homo_cache.insert(key, clause_dict)
        return clause_dict(x)
    elif isinstance(x, tuple) and len(x) == 1 and isinstance(x[0], str):
        homo_cache.insert(key, clause_symbol)
        return clause_symbol(x)
    else:
        homo_cache.insert(key, clause_other)
        return clause_other(x)

# Test data: 200,000 number-only calls
test_data = [random.randint(0, 1000000) for _ in range(200000)]

def benchmark_uncached(iterations: int) -> List[int]:
    """Benchmark uncached dispatcher"""
    times = []
    for run in range(iterations):
        result = 0
        start_ns = time.perf_counter()
        for item in test_data:
            r = dispatch_homo_uncached(item)
            if r:
                result += 1
        elapsed_ms = (time.perf_counter() - start_ns) * 1000.0
        print(f"  Run {run + 1}: {elapsed_ms / 1000.0:.1f} seconds")
        times.append(result)
    return times

def benchmark_cached(iterations: int) -> List[int]:
    """Benchmark cached dispatcher"""
    times = []
    for run in range(iterations):
        homo_cache.hits = 0
        homo_cache.misses = 0
        result = 0
        start_ns = time.perf_counter()
        for item in test_data:
            r = dispatch_homo_cached(item)
            if r:
                result += 1
        elapsed_ms = (time.perf_counter() - start_ns) * 1000.0
        print(f"  Run {run + 1}: {elapsed_ms / 1000.0:.1f} seconds")
        times.append(result)
    return times

def run_all_benchmarks():
    """Run all benchmarks"""
    print("\n================================")
    print("Python Homogeneous Dispatch Caching Micro-Benchmark")
    print("================================")
    import sys
    print(f"Implementation: Python {sys.version.split()[0]}")
    print("Test data: 200,000 number-only calls\n")

    print("Warming up JIT compiler (10,000 calls)...")
    for i in range(10000):
        dispatch_homo_uncached(test_data[i % len(test_data)])
    for i in range(10000):
        homo_cache.hits = 0
        homo_cache.misses = 0
        dispatch_homo_cached(test_data[i % len(test_data)])
    print("Warmup complete.\n")

    print("=== Uncached Dispatch (3 iterations) ===")
    benchmark_uncached(3)

    print("\n=== Cached Dispatch (3 iterations) ===")
    benchmark_cached(3)

    print("\nCached Dispatch Stats:")
    total = homo_cache.hits + homo_cache.misses
    print(f"  Cache hits: {homo_cache.hits}")
    print(f"  Cache misses: {homo_cache.misses}")
    if total > 0:
        hit_rate = 100.0 * homo_cache.hits / total
        print(f"  Hit rate: {hit_rate:.4f}%")

    print("\n================================")
    print("Benchmark Complete")
    print("================================")

if __name__ == "__main__":
    run_all_benchmarks()
