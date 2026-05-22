// Dispatch with different predicate costs
// Warm up: 200K iterations (allow V8 to warm up)
// Measurement: 3 runs × 2M iterations

const predicates = {
  email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  url: /^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$/,
  date: /^(0[1-9]|1[0-2])\/(0[1-9]|[12]\d|3[01])\/\d{4}\s([01]\d|2[0-3]):([0-5]\d):([0-5]\d)$/,
  constraint: null // Custom constraint solver below
};

// Simple constraint solver (>1 µs cost)
function constraintSolve(arg) {
  // Simulates expensive constraint checking: 1-2 µs
  let sum = 0;
  for (let i = 0; i < 500; i++) {
    sum += Math.sqrt(arg * i) % 7;
  }
  return sum > 1000;
}

// Dispatch function WITHOUT caching
function dispatchUncached(arg, predicateName) {
  const pred = predicates[predicateName];
  if (predicateName === 'constraint') {
    return constraintSolve(arg);
  }
  return pred.test(arg);
}

// Dispatch function WITH caching
class CachedDispatcher {
  constructor(predicateName) {
    this.pred = predicates[predicateName];
    this.predicateName = predicateName;
    this.cache = new Map();
  }

  dispatch(arg) {
    if (this.cache.has(arg)) {
      return this.cache.get(arg);
    }
    let result;
    if (this.predicateName === 'constraint') {
      result = constraintSolve(arg);
    } else {
      result = this.pred.test(arg);
    }
    this.cache.set(arg, result);
    return result;
  }
}

// Test data: 4-cycle pattern
const testData = {
  email: ['alice@example.com', 'bob@test.org', 'charlie@mail.net', 'dave@company.io'],
  url: ['https://example.com', 'http://google.com', 'https://github.com/search', 'http://stackoverflow.com/questions'],
  date: ['01/15/2025 14:30:45', '12/31/2024 23:59:59', '06/20/2023 09:15:30', '03/10/2026 16:45:00'],
  constraint: [10, 20, 30, 40]
};

function benchmark(predicateName) {
  const data = testData[predicateName];
  const iterations = 2_000_000;
  const warmupIterations = 200_000;

  // Warmup
  for (let i = 0; i < warmupIterations; i++) {
    dispatchUncached(data[i % 4], predicateName);
  }

  // Measure UNCACHED
  const uncachedStart = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    dispatchUncached(data[i % 4], predicateName);
  }
  const uncachedEnd = process.hrtime.bigint();
  const uncachedNs = Number(uncachedEnd - uncachedStart) / iterations;

  // Measure CACHED
  const cached = new CachedDispatcher(predicateName);
  const cachedStart = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    cached.dispatch(data[i % 4]);
  }
  const cachedEnd = process.hrtime.bigint();
  const cachedNs = Number(cachedEnd - cachedStart) / iterations;

  const ratio = cachedNs / uncachedNs;
  return { predicateName, uncachedNs: uncachedNs.toFixed(2), cachedNs: cachedNs.toFixed(2), ratio: ratio.toFixed(2) };
}

// Run benchmarks
console.log('V8 Expensive Predicate Caching Benchmark');
console.log('Predicate\t\tUncached (ns)\tCached (ns)\tRatio');
['email', 'url', 'date', 'constraint'].forEach(pred => {
  const result = benchmark(pred);
  console.log(`${result.predicateName}\t\t${result.uncachedNs}\t\t${result.cachedNs}\t\t${result.ratio}×`);
});
