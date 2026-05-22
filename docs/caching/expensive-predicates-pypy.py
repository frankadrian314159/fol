import re
import time
from typing import Callable

# Predicate patterns
EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
URL_RE = re.compile(r'^https?://(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$')
DATE_RE = re.compile(r'^(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/\d{4}\s([01]\d|2[0-3]):([0-5]\d):([0-5]\d)$')

# Expensive constraint solver (>1 µs)
def constraint_solve(arg: int) -> bool:
    total = 0
    for i in range(500):
        total += (arg * i) ** 0.5 % 7
    return total > 1000

# Dispatch without caching
def dispatch_uncached(arg, predicate_type):
    if predicate_type == 'email':
        return EMAIL_RE.match(arg) is not None
    elif predicate_type == 'url':
        return URL_RE.match(arg) is not None
    elif predicate_type == 'date':
        return DATE_RE.match(arg) is not None
    elif predicate_type == 'constraint':
        return constraint_solve(arg)

# Dispatch with caching
class CachedDispatcher:
    def __init__(self, predicate_type):
        self.predicate_type = predicate_type
        self.cache = {}

    def dispatch(self, arg):
        if arg in self.cache:
            return self.cache[arg]
        result = dispatch_uncached(arg, self.predicate_type)
        self.cache[arg] = result
        return result

# Test data (4-cycle pattern)
test_data = {
    'email': ['alice@example.com', 'bob@test.org', 'charlie@mail.net', 'dave@company.io'],
    'url': ['https://example.com', 'http://google.com', 'https://github.com/search', 'http://stackoverflow.com/questions'],
    'date': ['01/15/2025 14:30:45', '12/31/2024 23:59:59', '06/20/2023 09:15:30', '03/10/2026 16:45:00'],
    'constraint': [10, 20, 30, 40]
}

def benchmark(predicate_type):
    data = test_data[predicate_type]
    iterations = 2_000_000
    warmup_iterations = 200_000

    # Warmup
    for i in range(warmup_iterations):
        dispatch_uncached(data[i % 4], predicate_type)

    # Measure UNCACHED
    start = time.perf_counter_ns()
    for i in range(iterations):
        dispatch_uncached(data[i % 4], predicate_type)
    uncached_ns = (time.perf_counter_ns() - start) / iterations

    # Measure CACHED
    cached = CachedDispatcher(predicate_type)
    start = time.perf_counter_ns()
    for i in range(iterations):
        cached.dispatch(data[i % 4])
    cached_ns = (time.perf_counter_ns() - start) / iterations

    ratio = cached_ns / uncached_ns
    return predicate_type, uncached_ns, cached_ns, ratio

print('PyPy Expensive Predicate Caching Benchmark')
print('Predicate\t\tUncached (ns)\tCached (ns)\tRatio')
for pred in ['email', 'url', 'date', 'constraint']:
    pred_name, uncached, cached, ratio = benchmark(pred)
    print(f'{pred_name}\t\t{uncached:.2f}\t\t{cached:.2f}\t\t{ratio:.2f}×')
