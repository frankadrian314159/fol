#!/usr/bin/env node
/// Micro-benchmark: homogeneous dispatch (TypeScript version)
/// All dispatches on numbers (integers) only

// Cache structure
interface CacheEntry {
  key: string;
  fn: (x: any) => any;
}

const CACHE_SIZE = 8;

class DispatchCache {
  entries: CacheEntry[] = [];
  nextIdx: number = 0;
  hits: number = 0;
  misses: number = 0;

  constructor() {
    for (let i = 0; i < CACHE_SIZE; i++) {
      this.entries[i] = { key: "", fn: () => {} };
    }
  }

  lookup(key: string): ((x: any) => any) | null {
    for (let i = 0; i < CACHE_SIZE; i++) {
      if (this.entries[i] && this.entries[i].key === key) {
        return this.entries[i].fn;
      }
    }
    return null;
  }

  insert(key: string, fn: (x: any) => any): void {
    this.entries[this.nextIdx] = { key, fn };
    this.nextIdx = (this.nextIdx + 1) % CACHE_SIZE;
  }

  reset(): void {
    this.hits = 0;
    this.misses = 0;
  }
}

// Clause functions
const clauseLong = (x: any): any[] => ["long", x];

// Uncached dispatcher (COND-style)
function dispatchHomoUncached(x: any): any[] {
  if (typeof x === "number") {
    return clauseLong(x);
  }
  return ["other", x];
}

// Cached dispatcher
const homoCache = new DispatchCache();

function dispatchHomoCached(x: any): any[] {
  const key = typeof x === "number" ? "long" : "other";
  const hit = homoCache.lookup(key);

  if (hit) {
    homoCache.hits++;
    return hit(x);
  } else {
    homoCache.misses++;
    let fn: (x: any) => any[];

    if (typeof x === "number") {
      fn = clauseLong;
    } else {
      fn = (x: any) => ["other", x];
    }

    homoCache.insert(key, fn);
    return fn(x);
  }
}

// Test data: 2,000,000 random numbers
const testData: number[] = [];
for (let i = 0; i < 2000000; i++) {
  testData.push(Math.floor(Math.random() * 1000000));
}

// Benchmark functions
function benchmarkUncached(iterations: number): void {
  console.log("=== Uncached COND Dispatch (3 iterations) ===");
  for (let run = 0; run < iterations; run++) {
    const startNs = process.hrtime.bigint();
    for (let i = 0; i < testData.length; i++) {
      const result = dispatchHomoUncached(testData[i]);
    }
    const elapsedNs = process.hrtime.bigint() - startNs;
    const elapsedMs = Number(elapsedNs) / 1000000;
    const elapsedSec = elapsedMs / 1000;
    console.log(
      `  Run ${run + 1}: ${elapsedSec.toFixed(1)} seconds`
    );
  }
}

function benchmarkCached(iterations: number): void {
  console.log("\n=== Cached Dispatch (3 iterations) ===");
  for (let run = 0; run < iterations; run++) {
    homoCache.reset();
    const startNs = process.hrtime.bigint();
    for (let i = 0; i < testData.length; i++) {
      const result = dispatchHomoCached(testData[i]);
    }
    const elapsedNs = process.hrtime.bigint() - startNs;
    const elapsedMs = Number(elapsedNs) / 1000000;
    const elapsedSec = elapsedMs / 1000;
    console.log(
      `  Run ${run + 1}: ${elapsedSec.toFixed(1)} seconds`
    );
  }
}

// Main
console.log("================================");
console.log(
  "TypeScript Homogeneous Dispatch Caching Micro-Benchmark"
);
console.log("================================");
console.log(`Implementation: TypeScript (Node.js ${process.version})`);
console.log("Test data: 2,000,000 number-only calls\n");

console.log("Warming up JIT compiler (10,000 calls)...");
for (let i = 0; i < 10000; i++) {
  dispatchHomoUncached(testData[i % testData.length]);
  dispatchHomoCached(testData[i % testData.length]);
}
console.log("Warmup complete.\n");

benchmarkUncached(3);
benchmarkCached(3);

console.log("\nCached Dispatch Stats:");
console.log(`  Cache hits: ${homoCache.hits}`);
console.log(`  Cache misses: ${homoCache.misses}`);
const total = homoCache.hits + homoCache.misses;
const hitRate =
  total > 0
    ? ((homoCache.hits / total) * 100).toFixed(4)
    : "0.0000";
console.log(`  Hit rate: ${hitRate}%`);

console.log("\n================================");
console.log("Benchmark Complete");
console.log("================================");
