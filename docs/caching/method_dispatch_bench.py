#!/usr/bin/env python3
"""
Micro-benchmark: generic function dispatch (Python version)
Basic dispatch performance test
"""

import time
from typing import Any, List, Callable

# Simple type-based dispatcher
dispatch_table = {}

def defmethod(type_name: str) -> Callable:
    """Decorator to register a dispatcher method"""
    def decorator(fn: Callable) -> Callable:
        dispatch_table[type_name] = fn
        return fn
    return decorator

@defmethod('long')
def dispatch_long(x):
    return ('long', x)

@defmethod('string')
def dispatch_string(x):
    return ('string', len(x))

@defmethod('list')
def dispatch_list(x):
    return ('list', len(x))

@defmethod('dict')
def dispatch_dict(x):
    return ('dict', len(x))

@defmethod('symbol')
def dispatch_symbol(x):
    return ('symbol', x)

@defmethod('other')
def dispatch_other(x):
    return ('other', x)

def dispatch_clj_impl(x):
    """Generic dispatcher using type-based dispatch"""
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

    return dispatch_table[key](x)

# Test data: 200,000 calls with 5-type repeating cycle
test_data = []
cycle = [1, "test string", [1, 2, 3, 4, 5], {'a': 1}, ('symbol',)]
for i in range(200000):
    test_data.append(cycle[i % 5])

def benchmark_dispatch(iterations: int) -> List[int]:
    """Benchmark generic dispatcher"""
    times = []
    for run in range(iterations):
        result = 0
        start_ns = time.perf_counter()
        for item in test_data:
            r = dispatch_clj_impl(item)
            if r:
                result += 1
        elapsed_ms = (time.perf_counter() - start_ns) * 1000.0
        print(f"  Run {run + 1}: {elapsed_ms / 1000.0:.1f} seconds")
        times.append(result)
    return times

def run_all_benchmarks():
    """Run all benchmarks"""
    print("\n================================")
    print("Python Generic Function Dispatch Micro-Benchmark")
    print("================================")
    import sys
    print(f"Implementation: Python {sys.version.split()[0]}")
    print("Test data: 200,000 calls over repeating 5-type cycle")
    print("  Type cycle: int -> string -> list -> dict -> symbol\n")

    print("Warming up JIT compiler (10,000 calls)...")
    for i in range(10000):
        dispatch_clj_impl(test_data[i % len(test_data)])
    print("Warmup complete.\n")

    print("Running dispatch benchmark (3 iterations):")
    benchmark_dispatch(3)

    print("\n================================")
    print("Benchmark Complete")
    print("================================")

if __name__ == "__main__":
    run_all_benchmarks()
