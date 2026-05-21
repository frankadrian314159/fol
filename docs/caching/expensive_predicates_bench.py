#!/usr/bin/env python3
"""
Expensive Predicates Dispatch Caching Benchmark for CPython and PyPy
Tests dispatch with expensive regex pattern matching predicates
"""

import re
import time
from typing import Dict, Callable, Optional

class DispatchCache:
    """Round-robin 8-slot LRU cache for dispatch decisions"""

    def __init__(self):
        self.entries = [dict() for _ in range(8)]
        self.next_idx = 0
        self.hits = 0
        self.misses = 0

    def lookup(self, key: str) -> Optional[Callable]:
        for entry in self.entries:
            if key in entry:
                self.hits += 1
                return entry[key]
        self.misses += 1
        return None

    def insert(self, key: str, fn: Callable) -> None:
        self.entries[self.next_idx].clear()
        self.entries[self.next_idx][key] = fn
        self.next_idx = (self.next_idx + 1) % 8

    def reset(self) -> None:
        self.hits = 0
        self.misses = 0
        self.next_idx = 0
        for entry in self.entries:
            entry.clear()

# Expensive predicates using regex (1-3 microseconds each)
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
JSON_REGEX = re.compile(r'^[\s]*[\{\[].*[\}\]][\s]*$')
IP_REGEX = re.compile(r'^(\d{1,3}\.){3}\d{1,3}$')
URL_REGEX = re.compile(r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[a-zA-Z0-9._~:/?#\[\]@!$&\'()*+,;=-]*)?$')
ALPHANUM_REGEX = re.compile(r'^[a-zA-Z0-9]+$')

def predicate_is_email(x: str) -> bool:
    """Check if x is a valid email (expensive regex, 2-3 microseconds)"""
    return bool(EMAIL_REGEX.match(x))

def predicate_is_json(x: str) -> bool:
    """Check if x looks like JSON (expensive regex, 1-2 microseconds)"""
    return bool(JSON_REGEX.match(x))

def predicate_is_ip(x: str) -> bool:
    """Check if x is an IP address (expensive regex, 2-3 microseconds)"""
    return bool(IP_REGEX.match(x))

def predicate_is_url(x: str) -> bool:
    """Check if x is a URL (expensive regex, 2-3 microseconds)"""
    return bool(URL_REGEX.match(x))

def predicate_is_alphanum(x: str) -> bool:
    """Check if x is alphanumeric only (expensive regex, 1-2 microseconds)"""
    return bool(ALPHANUM_REGEX.match(x))

# Clause functions
def clause_email(x: str) -> str:
    return "email"

def clause_json(x: str) -> str:
    return "json"

def clause_ip(x: str) -> str:
    return "ipaddress"

def clause_url(x: str) -> str:
    return "url"

def clause_alphanum(x: str) -> str:
    return "alphanumeric"

def clause_unknown(x: str) -> str:
    return "unknown"

# Uncached dispatch: test all predicates (5-15 microseconds per call)
def dispatch_uncached(x: str) -> str:
    if predicate_is_email(x):
        return clause_email(x)
    elif predicate_is_json(x):
        return clause_json(x)
    elif predicate_is_ip(x):
        return clause_ip(x)
    elif predicate_is_url(x):
        return clause_url(x)
    elif predicate_is_alphanum(x):
        return clause_alphanum(x)
    else:
        return clause_unknown(x)

# Cached dispatch
def dispatch_cached(x: str, cache: DispatchCache) -> str:
    key = x[:20] if len(x) > 20 else x
    cached = cache.lookup(key)

    if cached is not None:
        return cached(x)

    # Find matching predicate
    if predicate_is_email(x):
        fn = clause_email
    elif predicate_is_json(x):
        fn = clause_json
    elif predicate_is_ip(x):
        fn = clause_ip
    elif predicate_is_url(x):
        fn = clause_url
    elif predicate_is_alphanum(x):
        fn = clause_alphanum
    else:
        fn = clause_unknown

    cache.insert(key, fn)
    return fn(x)

def run_benchmark(implementation_name: str = "CPython") -> None:
    num_calls = 100000

    print("================================")
    print(f"{implementation_name} Expensive Predicates Dispatch Caching Benchmark")
    print("================================")
    print(f"Test data: {num_calls} calls with expensive predicates")
    print("  Predicates: email, JSON, IP address, URL, alphanumeric")
    print("  Predicate cost: 1-3 microseconds each (regex matching)")
    print("  Uncached dispatch cost: 5-15 microseconds")
    print("  Cache benefit potential: Massive if expensive predicates save checks\n")

    patterns = [
        "user@example.com",
        '{"key": "value"}',
        "192.168.1.1",
        "https://example.com/path?query=value",
        "abc123def456",
    ]

    # Create test data
    test_data = [patterns[i % 5] for i in range(num_calls)]

    # Warmup
    print("Warming up (10,000 calls)...")
    for i in range(10000):
        dispatch_uncached(test_data[i % num_calls])

    cache = DispatchCache()
    for i in range(10000):
        dispatch_cached(test_data[i % num_calls], cache)
    print("Warmup complete.\n")

    # Uncached benchmark
    print("=== Uncached Expensive Dispatch (3 iterations) ===")
    uncached_times = []
    for run in range(3):
        start = time.perf_counter()
        for item in test_data:
            dispatch_uncached(item)
        elapsed = time.perf_counter() - start
        uncached_times.append(elapsed)
        us_per_call = (elapsed * 1e6) / num_calls
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({us_per_call:.2f} us/call)")

    # Cached benchmark
    print("\n=== Cached Expensive Dispatch (3 iterations) ===")
    cached_times = []
    for run in range(3):
        cache.reset()
        start = time.perf_counter()
        for item in test_data:
            dispatch_cached(item, cache)
        elapsed = time.perf_counter() - start
        cached_times.append(elapsed)
        us_per_call = (elapsed * 1e6) / num_calls
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({us_per_call:.2f} us/call)")

    # Cache stats
    print("\nCached Dispatch Stats:")
    print(f"  Cache hits: {cache.hits}")
    print(f"  Cache misses: {cache.misses}")
    total = cache.hits + cache.misses
    if total > 0:
        hit_rate = 100.0 * cache.hits / total
        print(f"  Hit rate: {hit_rate:.4f}%")

    # Summary
    avg_uncached = sum(uncached_times) / 3
    avg_cached = sum(cached_times) / 3

    us_uncached = (avg_uncached * 1e6) / num_calls
    us_cached = (avg_cached * 1e6) / num_calls
    ratio = avg_cached / avg_uncached

    print("\n================================")
    print(f"Average uncached: {us_uncached:.2f} us/call")
    print(f"Average cached: {us_cached:.2f} us/call")

    if ratio < 1.0:
        print(f"SPEEDUP: {int((1.0 - ratio) * 100)}% faster with caching")
    else:
        print(f"SLOWDOWN: {int((ratio - 1.0) * 100)}% slower with caching")

    print("\nBreak-even analysis:")
    print("  Predicate cost: 5 to 15 microseconds (expensive)")
    print("  Cache overhead: negligible at this scale")
    print("  Theoretical: Should see speedup if expensive predicates save checks")
    print("================================\n")

if __name__ == "__main__":
    import sys
    impl_name = sys.argv[1] if len(sys.argv) > 1 else "CPython"
    run_benchmark(impl_name)
