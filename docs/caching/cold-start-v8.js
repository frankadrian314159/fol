// Measure dispatch cost as JIT warms up
// Iterations 1-100: pre-JIT (interpreted)
// Iterations 500-600: JIT transitioning
// Iterations 1001+: post-JIT (compiled)

function dispatchUncached(arg, typeValue) {
  // Simulate expensive dispatch predicate evaluation
  if (typeValue === 0) return arg + 1;
  if (typeValue === 1) return arg * 2;
  if (typeValue === 2) return arg - 1;
  if (typeValue === 3) return arg / 2;
  return arg;
}

class CachedDispatcher {
  constructor() {
    this.cache = new Map();
  }
  dispatch(arg, typeValue) {
    const key = `${arg}:${typeValue}`;
    if (this.cache.has(key)) {
      return this.cache.get(key);
    }
    const result = dispatchUncached(arg, typeValue);
    this.cache.set(key, result);
    return result;
  }
}

function measurePhase(name, iterations, startIter, endIter, testFn) {
  const times = [];
  for (let run = 0; run < 3; run++) {
    const start = process.hrtime.bigint();
    for (let i = startIter; i < endIter; i++) {
      testFn(i % 4);
    }
    const end = process.hrtime.bigint();
    const nsPerCall = Number(end - start) / (endIter - startIter);
    times.push(nsPerCall);
  }
  const avg = times.reduce((a, b) => a + b) / times.length;
  return { name, iterations: `${startIter}-${endIter}`, avgNs: avg.toFixed(2) };
}

console.log('V8 Lazy JIT Cold-Start Benchmark');
console.log('Measure dispatch cost at different JIT phases\n');

// UNCACHED
console.log('UNCACHED Dispatch:');
console.log('Phase\t\tIterations\tAvg (ns)');
let uncachedCold = measurePhase('Pre-JIT', 100, 0, 100, (i) => dispatchUncached(i, i % 4));
let uncachedWarm = measurePhase('JIT Warmup', 100, 500, 600, (i) => dispatchUncached(i, i % 4));
let uncachedHot = measurePhase('Post-JIT', 100, 1001, 1101, (i) => dispatchUncached(i, i % 4));
console.log(`Pre-JIT\t\t${uncachedCold.iterations}\t${uncachedCold.avgNs}`);
console.log(`JIT Warmup\t${uncachedWarm.iterations}\t${uncachedWarm.avgNs}`);
console.log(`Post-JIT\t${uncachedHot.iterations}\t${uncachedHot.avgNs}\n`);

// CACHED
console.log('CACHED Dispatch:');
console.log('Phase\t\tIterations\tAvg (ns)');
const cached = new CachedDispatcher();
let cachedCold = measurePhase('Pre-JIT', 100, 0, 100, (i) => cached.dispatch(i, i % 4));
let cachedWarm = measurePhase('JIT Warmup', 100, 500, 600, (i) => cached.dispatch(i, i % 4));
let cachedHot = measurePhase('Post-JIT', 100, 1001, 1101, (i) => cached.dispatch(i, i % 4));
console.log(`Pre-JIT\t\t${cachedCold.iterations}\t${cachedCold.avgNs}`);
console.log(`JIT Warmup\t${cachedWarm.iterations}\t${cachedWarm.avgNs}`);
console.log(`Post-JIT\t${cachedHot.iterations}\t${cachedHot.avgNs}\n`);

// RATIOS
console.log('Speedup Ratios (Cached / Uncached):');
console.log(`Pre-JIT (cold):\t${(parseFloat(cachedCold.avgNs) / parseFloat(uncachedCold.avgNs)).toFixed(2)}×`);
console.log(`JIT Warmup:\t${(parseFloat(cachedWarm.avgNs) / parseFloat(uncachedWarm.avgNs)).toFixed(2)}×`);
console.log(`Post-JIT (hot):\t${(parseFloat(cachedHot.avgNs) / parseFloat(uncachedHot.avgNs)).toFixed(2)}×`);
