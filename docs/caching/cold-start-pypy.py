import time

def dispatch_uncached(arg, type_value):
    if type_value == 0: return arg + 1
    if type_value == 1: return arg * 2
    if type_value == 2: return arg - 1
    if type_value == 3: return arg / 2
    return arg

class CachedDispatcher:
    def __init__(self):
        self.cache = {}

    def dispatch(self, arg, type_value):
        key = (arg, type_value)
        if key in self.cache:
            return self.cache[key]
        result = dispatch_uncached(arg, type_value)
        self.cache[key] = result
        return result

def measure_phase(name, start_iter, end_iter, test_fn):
    times = []
    for run in range(3):
        start = time.perf_counter_ns()
        for i in range(start_iter, end_iter):
            test_fn(i % 4)
        end = time.perf_counter_ns()
        ns_per_call = (end - start) / (end_iter - start_iter)
        times.append(ns_per_call)
    avg = sum(times) / len(times)
    return name, f'{start_iter}-{end_iter}', avg

print('PyPy Lazy JIT Cold-Start Benchmark')
print('Measure dispatch cost at different JIT phases\n')

# UNCACHED
print('UNCACHED Dispatch:')
print('Phase\t\tIterations\tAvg (ns)')
uncached_cold = measure_phase('Pre-JIT', 0, 100, lambda i: dispatch_uncached(i, i % 4))
uncached_warm = measure_phase('JIT Warmup', 500, 600, lambda i: dispatch_uncached(i, i % 4))
uncached_hot = measure_phase('Post-JIT', 1001, 1101, lambda i: dispatch_uncached(i, i % 4))
print(f'Pre-JIT\t\t{uncached_cold[1]}\t{uncached_cold[2]:.2f}')
print(f'JIT Warmup\t{uncached_warm[1]}\t{uncached_warm[2]:.2f}')
print(f'Post-JIT\t{uncached_hot[1]}\t{uncached_hot[2]:.2f}\n')

# CACHED
print('CACHED Dispatch:')
print('Phase\t\tIterations\tAvg (ns)')
cached = CachedDispatcher()
cached_cold = measure_phase('Pre-JIT', 0, 100, lambda i: cached.dispatch(i, i % 4))
cached_warm = measure_phase('JIT Warmup', 500, 600, lambda i: cached.dispatch(i, i % 4))
cached_hot = measure_phase('Post-JIT', 1001, 1101, lambda i: cached.dispatch(i, i % 4))
print(f'Pre-JIT\t\t{cached_cold[1]}\t{cached_cold[2]:.2f}')
print(f'JIT Warmup\t{cached_warm[1]}\t{cached_warm[2]:.2f}')
print(f'Post-JIT\t{cached_hot[1]}\t{cached_hot[2]:.2f}\n')

# RATIOS
print('Speedup Ratios (Cached / Uncached):')
print(f'Pre-JIT (cold):\t{cached_cold[2] / uncached_cold[2]:.2f}×')
print(f'JIT Warmup:\t{cached_warm[2] / uncached_warm[2]:.2f}×')
print(f'Post-JIT (hot):\t{cached_hot[2] / uncached_hot[2]:.2f}×')
