#!/usr/bin/env python3
"""
Run Python benchmarks with timing precision for CPython and PyPy comparison
"""

import subprocess
import sys
import re
from pathlib import Path

def run_benchmark(python_exe, bench_file):
    """Run a single benchmark and extract timing data"""
    result = subprocess.run(
        [python_exe, str(bench_file)],
        capture_output=True,
        text=True,
        timeout=60
    )

    output = result.stdout + result.stderr

    # Extract timing data
    times = []
    for line in output.split('\n'):
        match = re.search(r'Run \d+: ([\d.]+) seconds', line)
        if match:
            times.append(float(match.group(1)))

    return output, times

def main():
    bench_dir = Path("C:/Users/frank/Projects/FOL/fol")
    python_exe = sys.executable  # CPython
    pypy_exe = Path("C:/Users/frank/Downloads/pypy3.10-v7.3.12-win64/pypy.exe")

    benchmarks = [
        "hetero_micro_bench.py",
        "simple_micro_bench.py",
        "method_dispatch_bench.py"
    ]

    results = {}

    print("\n" + "=" * 80)
    print("PyPy vs CPython Benchmark Comparison")
    print("=" * 80)

    for bench_name in benchmarks:
        bench_file = bench_dir / bench_name
        print(f"\n{'=' * 80}")
        print(f"Benchmark: {bench_name}")
        print(f"{'=' * 80}")

        # Run with CPython
        print(f"\nRunning with CPython ({python_exe})...")
        cpython_output, cpython_times = run_benchmark(python_exe, bench_file)

        # Run with PyPy
        print(f"Running with PyPy ({pypy_exe})...")
        pypy_output, pypy_times = run_benchmark(str(pypy_exe), bench_file)

        # Extract uncached vs cached timing
        cpython_uncached = [t for i, t in enumerate(cpython_times) if i < 3]
        cpython_cached = [t for i, t in enumerate(cpython_times) if 3 <= i < 6]
        pypy_uncached = [t for i, t in enumerate(pypy_times) if i < 3]
        pypy_cached = [t for i, t in enumerate(pypy_times) if 3 <= i < 6]

        # Calculate averages
        cpython_uncached_avg = sum(cpython_uncached) / len(cpython_uncached) if cpython_uncached else 0
        cpython_cached_avg = sum(cpython_cached) / len(cpython_cached) if cpython_cached else 0
        pypy_uncached_avg = sum(pypy_uncached) / len(pypy_uncached) if pypy_uncached else 0
        pypy_cached_avg = sum(pypy_cached) / len(pypy_cached) if pypy_cached else 0

        # Calculate per-call latency (200,000 calls)
        num_calls = 200000
        cpython_uncached_ns = (cpython_uncached_avg * 1e9) / num_calls if cpython_uncached_avg > 0 else 0
        cpython_cached_ns = (cpython_cached_avg * 1e9) / num_calls if cpython_cached_avg > 0 else 0
        pypy_uncached_ns = (pypy_uncached_avg * 1e9) / num_calls if pypy_uncached_avg > 0 else 0
        pypy_cached_ns = (pypy_cached_avg * 1e9) / num_calls if pypy_cached_avg > 0 else 0

        # Calculate slowdown ratios
        cpython_ratio = cpython_cached_avg / cpython_uncached_avg if cpython_uncached_avg > 0 else 0
        pypy_ratio = pypy_cached_avg / pypy_uncached_avg if pypy_uncached_avg > 0 else 0

        # Results
        results[bench_name] = {
            'cpython_uncached_s': cpython_uncached_avg,
            'cpython_cached_s': cpython_cached_avg,
            'cpython_uncached_ns': cpython_uncached_ns,
            'cpython_cached_ns': cpython_cached_ns,
            'cpython_ratio': cpython_ratio,
            'pypy_uncached_s': pypy_uncached_avg,
            'pypy_cached_s': pypy_cached_avg,
            'pypy_uncached_ns': pypy_uncached_ns,
            'pypy_cached_ns': pypy_cached_ns,
            'pypy_ratio': pypy_ratio,
        }

        print(f"\nResults for {bench_name}:")
        print(f"  CPython uncached:  {cpython_uncached_avg:.4f} s  ({cpython_uncached_ns:.1f} ns/call)")
        print(f"  CPython cached:    {cpython_cached_avg:.4f} s  ({cpython_cached_ns:.1f} ns/call)")
        print(f"  CPython ratio:     {cpython_ratio:.2f}×")
        print()
        print(f"  PyPy uncached:     {pypy_uncached_avg:.4f} s  ({pypy_uncached_ns:.1f} ns/call)")
        print(f"  PyPy cached:       {pypy_cached_avg:.4f} s  ({pypy_cached_ns:.1f} ns/call)")
        print(f"  PyPy ratio:        {pypy_ratio:.2f}×")
        print()
        speedup_uncached = cpython_uncached_avg / pypy_uncached_avg if pypy_uncached_avg > 0 else 0
        speedup_cached = cpython_cached_avg / pypy_cached_avg if pypy_cached_avg > 0 else 0
        print(f"  Speedup (PyPy/CPython uncached):  {speedup_uncached:.2f}×")
        print(f"  Speedup (PyPy/CPython cached):    {speedup_cached:.2f}×")

    # Summary table
    print(f"\n{'=' * 80}")
    print("Summary Table")
    print(f"{'=' * 80}")
    print(f"\n{'Benchmark':<25} {'CPython (ns)':<20} {'PyPy (ns)':<20} {'Ratio (C/P)':<15}")
    print(f"{'-' * 80}")
    for bench_name, data in results.items():
        print(f"{bench_name:<25}")
        uncached_ratio = data['cpython_uncached_ns']/data['pypy_uncached_ns'] if data['pypy_uncached_ns'] > 0 else 0
        cached_ratio = data['cpython_cached_ns']/data['pypy_cached_ns'] if data['pypy_cached_ns'] > 0 else 0
        print(f"  Uncached:          {data['cpython_uncached_ns']:<19.1f} {data['pypy_uncached_ns']:<19.1f} {uncached_ratio:<14.1f}×")
        print(f"  Cached:            {data['cpython_cached_ns']:<19.1f} {data['pypy_cached_ns']:<19.1f} {cached_ratio:<14.1f}×")
        print(f"  Caching slowdown:  {data['cpython_ratio']:<19.2f}× {data['pypy_ratio']:<19.2f}× ")
        print()

if __name__ == "__main__":
    main()
