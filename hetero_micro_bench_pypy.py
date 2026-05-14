#!/usr/bin/env python3
"""
Micro-benchmark: heterogeneous dispatch (Python version, high iterations for PyPy)
Compares dispatch caching across CPython and PyPy
"""

import time
from typing import Any, List, Tuple

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
hetero_cache = DispatchCache()

def dispatch_hetero_uncached(x):
    """Uncached heterogeneous dispatcher using isinstance checks"""
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

def dispatch_hetero_cached(x):
    """Cached heterogeneous dispatcher"""
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
    hit = hetero_cache.lookup(key)
    if hit is not None:
        hetero_cache.hits += 1
        return hit(x)

    # Cache miss - dispatch and cache the result
    hetero_cache.misses += 1
    if isinstance(x, (int, float)):
        hetero_cache.insert(key, clause_long)
        return clause_long(x)
    elif isinstance(x, str):
        hetero_cache.insert(key, clause_string)
        return clause_string(x)
    elif isinstance(x, list):
        hetero_cache.insert(key, clause_list)
        return clause_list(x)
    elif isinstance(x, dict):
        hetero_cache.insert(key, clause_dict)
        return clause_dict(x)
    elif isinstance(x, tuple) and len(x) == 1 and isinstance(x[0], str):
        hetero_cache.insert(key, clause_symbol)
        return clause_symbol(x)
    else:
        hetero_cache.insert(key, clause_other)
        return clause_other(x)

# Test data: 2,000,000 calls with 5-type repeating cycle
test_data = []
cycle = [1, "test string", [1, 2, 3, 4, 5], {'a': 1}, ('symbol',)]
for i in range(2000000):
    test_data.append(cycle[i % 5])

def benchmark_uncached(iterations: int) -> List[float]:
    """Benchmark uncached dispatcher"""
    times = []
    for run in range(iterations):
        start = time.perf_counter()
        for item in test_data:
            r = dispatch_hetero_uncached(item)
        elapsed = time.perf_counter() - start
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({elapsed*1e9/len(test_data):.1f} ns/call)")
        times.append(elapsed)
    return times

def benchmark_cached(iterations: int) -> List[float]:
    """Benchmark cached dispatcher"""
    times = []
    for run in range(iterations):
        hetero_cache.hits = 0
        hetero_cache.misses = 0
        start = time.perf_counter()
        for item in test_data:
            r = dispatch_hetero_cached(item)
        elapsed = time.perf_counter() - start
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({elapsed*1e9/len(test_data):.1f} ns/call)")
        times.append(elapsed)
    return times

def run_all_benchmarks():
    """Run all benchmarks"""
    print("\n================================")
    print("Python Heterogeneous Dispatch Caching Micro-Benchmark")
    print("================================")
    import sys
    print(f"Implementation: Python {sys.version.split()[0]}")
    print("Test data: 2,000,000 calls over repeating 5-type cycle")
    print("  Type cycle: int -> string -> list -> dict -> symbol\n")

    print("Warming up (10,000 calls)...")
    for i in range(10000):
        dispatch_hetero_uncached(test_data[i % len(test_data)])
    for i in range(10000):
        hetero_cache.hits = 0
        hetero_cache.misses = 0
        dispatch_hetero_cached(test_data[i % len(test_data)])
    print("Warmup complete.\n")

    print("=== Uncached Dispatch (3 iterations) ===")
    benchmark_uncached(3)

    print("\n=== Cached Dispatch (3 iterations) ===")
    benchmark_cached(3)

    print("\nCached Dispatch Stats:")
    total = hetero_cache.hits + hetero_cache.misses
    print(f"  Cache hits: {hetero_cache.hits}")
    print(f"  Cache misses: {hetero_cache.misses}")
    if total > 0:
        hit_rate = 100.0 * hetero_cache.hits / total
        print(f"  Hit rate: {hit_rate:.4f}%")

    print("\n================================")
    print("Benchmark Complete")
    print("================================")

if __name__ == "__main__":
    run_all_benchmarks()
