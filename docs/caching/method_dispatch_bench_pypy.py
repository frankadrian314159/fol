#!/usr/bin/env python3
"""
Micro-benchmark: generic function dispatch (Python version, high iterations)
"""

import time

# Dispatch table
dispatch_table = {
    'long': lambda x: ('long', x),
    'string': lambda x: ('string', len(x)),
    'list': lambda x: ('list', len(x)),
    'dict': lambda x: ('dict', len(x)),
    'symbol': lambda x: ('symbol', x),
    'other': lambda x: ('other', x),
}

def get_type(x):
    if isinstance(x, (int, float)):
        return 'long'
    elif isinstance(x, str):
        return 'string'
    elif isinstance(x, list):
        return 'list'
    elif isinstance(x, dict):
        return 'dict'
    elif isinstance(x, tuple) and len(x) == 1 and isinstance(x[0], str):
        return 'symbol'
    else:
        return 'other'

def dispatch_generic(x):
    """Generic dispatcher using dispatch table"""
    typ = get_type(x)
    fn = dispatch_table.get(typ, dispatch_table['other'])
    return fn(x)

# Test data: 2,000,000 calls with 5-type repeating cycle
test_data = []
cycle = [1, "test string", [1, 2, 3, 4, 5], {'a': 1}, ('symbol',)]
for i in range(2000000):
    test_data.append(cycle[i % 5])

def benchmark(iterations: int):
    times = []
    for run in range(iterations):
        start = time.perf_counter()
        for item in test_data:
            dispatch_generic(item)
        elapsed = time.perf_counter() - start
        print(f"  Run {run + 1}: {elapsed:.4f} seconds ({elapsed*1e9/len(test_data):.1f} ns/call)")
        times.append(elapsed)
    return times

def run_all_benchmarks():
    print("\n================================")
    print("Python Generic Function Dispatch Micro-Benchmark")
    print("================================")
    import sys
    print(f"Implementation: Python {sys.version.split()[0]}")
    print("Test data: 2,000,000 calls over repeating 5-type cycle")
    print("  Type cycle: int -> string -> list -> dict -> symbol\n")

    print("Warming up (10,000 calls)...")
    for i in range(10000):
        dispatch_generic(test_data[i % len(test_data)])
    print("Warmup complete.\n")

    print("Running dispatch benchmark (3 iterations):")
    benchmark(3)

    print("\n================================")
    print("Benchmark Complete")
    print("================================")

if __name__ == "__main__":
    run_all_benchmarks()
