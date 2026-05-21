#!/usr/bin/env node
// Micro-benchmark: homogeneous dispatch (JavaScript version)
// All dispatches on numbers only

const CACHE_SIZE = 8;

class DispatchCache {
  constructor() {
    this.entries = new Array(CACHE_SIZE);
    this.nextIdx = 0;
    this.hits = 0;
    this.misses = 0;
  }

  lookup(key) {
    for (let i = 0; i < CACHE_SIZE; i++) {
      const entry = this.entries[i];
      if (entry && entry[0] === key) {
        return entry[1];
      }
    }
    return null;
  }

  insert(key, fn) {
    this.entries[this.nextIdx] = [key, fn];
    this.nextIdx = (this.nextIdx + 1) % CACHE_SIZE;
  }
}

function clauseNumber(x) {
  return ["number", x];
}

const homoCache = new DispatchCache();

function dispatchHomoUncached(x) {
  if (typeof x === "number") {
    return ["number", x];
  } else {
    return ["other", x];
  }
}

function dispatchHomoCached(x) {
  const key = "number";
  const hit = homoCache.lookup(key);

  if (hit) {
    homoCache.hits++;
    return hit(x);
  }

  homoCache.misses++;
  homoCache.insert(key, clauseNumber);
  return clauseNumber(x);
}

// Test data: 2,000,000 number-only calls (10× iterations)
const testData = [];
for (let repeat = 0; repeat < 10; repeat++) {
  for (let i = 0; i < 200000; i++) {
    testData.push(Math.floor(Math.random() * 1000000));
  }
}

let globalResult = 0;

function benchmarkUncached(iterations) {
  const times = [];
  for (let run = 1; run <= iterations; run++) {
    const startTime = performance.now();
    for (let i = 0; i < testData.length; i++) {
      const r = dispatchHomoUncached(testData[i]);
      if (r) {
        globalResult = (globalResult + 1) % 1000000; // Force side effect
      }
    }
    const elapsed = performance.now() - startTime;
    console.log(`  Run ${run}: ${(elapsed / 1000).toFixed(1)} seconds`);
    times.push(elapsed);
  }
  return times;
}

function benchmarkCached(iterations) {
  const times = [];
  for (let run = 1; run <= iterations; run++) {
    homoCache.hits = 0;
    homoCache.misses = 0;
    const startTime = performance.now();
    for (let i = 0; i < testData.length; i++) {
      const r = dispatchHomoCached(testData[i]);
      if (r) {
        globalResult = (globalResult + 1) % 1000000; // Force side effect
      }
    }
    const elapsed = performance.now() - startTime;
    console.log(`  Run ${run}: ${(elapsed / 1000).toFixed(1)} seconds`);
    times.push(elapsed);
  }
  return times;
}

function runAllBenchmarks() {
  console.log("\n================================");
  console.log("JavaScript Homogeneous Dispatch Caching Micro-Benchmark");
  console.log("================================");
  console.log(`Implementation: Node.js ${process.version}`);
  console.log("Test data: 2,000,000 number-only calls (10× iterations)\n");

  console.log("Warming up interpreter (10,000 calls)...");
  for (let i = 0; i < 10000; i++) {
    dispatchHomoUncached(testData[i % testData.length]);
  }
  for (let i = 0; i < 10000; i++) {
    homoCache.hits = 0;
    homoCache.misses = 0;
    dispatchHomoCached(testData[i % testData.length]);
  }
  console.log("Warmup complete.\n");

  console.log("=== Uncached Dispatch (10 iterations) ===");
  benchmarkUncached(10);

  console.log("\n=== Cached Dispatch (10 iterations) ===");
  benchmarkCached(10);

  console.log("\nCached Dispatch Stats:");
  const total = homoCache.hits + homoCache.misses;
  console.log(`  Cache hits: ${homoCache.hits}`);
  console.log(`  Cache misses: ${homoCache.misses}`);
  if (total > 0) {
    const hitRate = (100.0 * homoCache.hits) / total;
    console.log(`  Hit rate: ${hitRate.toFixed(4)}%`);
  }

  console.log(`\nInternal state (preventing JIT optimization): ${globalResult}`);
  console.log("\n================================");
  console.log("Benchmark Complete");
  console.log("================================");
}

runAllBenchmarks();
