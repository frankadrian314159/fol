#!/usr/bin/env node
// Micro-benchmark: heterogeneous dispatch (JavaScript version)
// Compares dispatch caching across implementations

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

function clauseString(x) {
  return ["string", x.length];
}

function clauseObject(x) {
  return ["object", Object.keys(x).length];
}

function clauseBoolean(x) {
  return ["boolean", x];
}

function clauseOther(x) {
  return ["other", x];
}

const heteroCache = new DispatchCache();

function getTypeKey(x) {
  if (typeof x === "number") {
    return "number";
  } else if (typeof x === "string") {
    return "string";
  } else if (typeof x === "object" && x !== null) {
    return "object";
  } else if (typeof x === "boolean") {
    return "boolean";
  } else {
    return "other";
  }
}

function dispatchHeteroUncached(x) {
  if (typeof x === "number") {
    return ["number", x];
  } else if (typeof x === "string") {
    return ["string", x.length];
  } else if (typeof x === "object" && x !== null) {
    return ["object", Object.keys(x).length];
  } else if (typeof x === "boolean") {
    return ["boolean", x];
  } else {
    return ["other", x];
  }
}

function dispatchHeteroCached(x) {
  const key = getTypeKey(x);
  const hit = heteroCache.lookup(key);

  if (hit) {
    heteroCache.hits++;
    return hit(x);
  }

  heteroCache.misses++;
  const t = typeof x;
  if (t === "number") {
    heteroCache.insert(key, clauseNumber);
    return clauseNumber(x);
  } else if (t === "string") {
    heteroCache.insert(key, clauseString);
    return clauseString(x);
  } else if (t === "object" && x !== null) {
    heteroCache.insert(key, clauseObject);
    return clauseObject(x);
  } else if (t === "boolean") {
    heteroCache.insert(key, clauseBoolean);
    return clauseBoolean(x);
  } else {
    heteroCache.insert(key, clauseOther);
    return clauseOther(x);
  }
}

// Test data: 200,000 calls with 5-type repeating cycle (repeated 10x to increase workload)
const testData = [];
const cycle = [1, "test string", { a: 1, b: 2, c: 3, d: 4, e: 5 }, true, "symbol"];
for (let repeat = 0; repeat < 10; repeat++) {
  for (let i = 0; i < 200000; i++) {
    testData.push(cycle[i % 5]);
  }
}

function benchmarkUncached(iterations) {
  const times = [];
  for (let run = 1; run <= iterations; run++) {
    const startTime = performance.now();
    for (let i = 0; i < testData.length; i++) {
      const r = dispatchHeteroUncached(testData[i]);
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
    heteroCache.hits = 0;
    heteroCache.misses = 0;
    const startTime = performance.now();
    for (let i = 0; i < testData.length; i++) {
      const r = dispatchHeteroCached(testData[i]);
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

let globalResult = 0;

function runAllBenchmarks() {
  console.log("\n================================");
  console.log("JavaScript Heterogeneous Dispatch Caching Micro-Benchmark");
  console.log("================================");
  console.log(`Implementation: Node.js ${process.version}`);
  console.log("Test data: 2,000,000 calls over repeating 5-type cycle (10× iterations)");
  console.log("  Type cycle: number -> string -> object -> boolean -> other\n");

  console.log("Warming up interpreter (10,000 calls)...");
  for (let i = 0; i < 10000; i++) {
    dispatchHeteroUncached(testData[i % 200000]);
  }
  for (let i = 0; i < 10000; i++) {
    heteroCache.hits = 0;
    heteroCache.misses = 0;
    dispatchHeteroCached(testData[i % 200000]);
  }
  console.log("Warmup complete.\n");

  console.log("=== Uncached Dispatch (10 iterations) ===");
  benchmarkUncached(10);

  console.log("\n=== Cached Dispatch (10 iterations) ===");
  benchmarkCached(10);

  console.log("\nCached Dispatch Stats:");
  const total = heteroCache.hits + heteroCache.misses;
  console.log(`  Cache hits: ${heteroCache.hits}`);
  console.log(`  Cache misses: ${heteroCache.misses}`);
  if (total > 0) {
    const hitRate = (100.0 * heteroCache.hits) / total;
    console.log(`  Hit rate: ${hitRate.toFixed(4)}%`);
  }

  console.log(`\nInternal state (preventing JIT optimization): ${globalResult}`);
  console.log("\n================================");
  console.log("Benchmark Complete");
  console.log("================================");
}

runAllBenchmarks();
