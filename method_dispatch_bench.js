#!/usr/bin/env node
// Micro-benchmark: generic function dispatch (JavaScript version)
// Basic dispatch performance test using a dispatch table

// Dispatch table
const dispatchTable = {
  number: (x) => ["number", x],
  string: (x) => ["string", x.length],
  object: (x) => ["object", Object.keys(x).length],
  boolean: (x) => ["boolean", x],
  other: (x) => ["other", x],
};

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

function dispatchGeneric(x) {
  const key = getTypeKey(x);
  return dispatchTable[key](x);
}

// Test data: 2,000,000 calls with 5-type repeating cycle (10× iterations)
const testData = [];
const cycle = [1, "test string", { a: 1, b: 2, c: 3, d: 4, e: 5 }, true, "symbol"];
for (let repeat = 0; repeat < 10; repeat++) {
  for (let i = 0; i < 200000; i++) {
    testData.push(cycle[i % 5]);
  }
}

let globalResult = 0;

function benchmarkDispatch(iterations) {
  const times = [];
  for (let run = 1; run <= iterations; run++) {
    const startTime = performance.now();
    for (let i = 0; i < testData.length; i++) {
      const r = dispatchGeneric(testData[i]);
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
  console.log("JavaScript Generic Function Dispatch Micro-Benchmark");
  console.log("================================");
  console.log(`Implementation: Node.js ${process.version}`);
  console.log("Test data: 2,000,000 calls over repeating 5-type cycle (10× iterations)");
  console.log("  Type cycle: number -> string -> object -> boolean -> other\n");

  console.log("Warming up interpreter (10,000 calls)...");
  for (let i = 0; i < 10000; i++) {
    dispatchGeneric(testData[(i % 200000)]);
  }
  console.log("Warmup complete.\n");

  console.log("Running dispatch benchmark (10 iterations):");
  benchmarkDispatch(10);

  console.log(`\nInternal state (preventing JIT optimization): ${globalResult}`);
  console.log("\n================================");
  console.log("Benchmark Complete");
  console.log("================================");
}

runAllBenchmarks();
