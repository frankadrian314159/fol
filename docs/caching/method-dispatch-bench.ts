#!/usr/bin/env node
/// Micro-benchmark: generic function dispatch (TypeScript version)
/// Using a dispatch table with type-based function selection

// Type checking function
function getType(x: any): string {
  if (typeof x === "number") return "number";
  if (typeof x === "string") return "string";
  if (Array.isArray(x)) {
    if (typeof x[0] === "number") return "list";
    return "vector";
  }
  if (typeof x === "symbol") return "symbol";
  return "other";
}

// Dispatch table using Record (TypeScript's type-safe dict)
type DispatchTable = Record<string, (x: any) => any[]>;

const dispatchTable: DispatchTable = {
  number: (x: any) => ["number", x],
  string: (x: any) => ["string", (x as string).length],
  list: (x: any) => ["list", (x as any[]).length],
  vector: (x: any) => ["vector", (x as any[]).length],
  symbol: (x: any) => ["symbol", x],
  other: (x: any) => ["other", x],
};

// Generic dispatcher using dispatch table
function dispatchGeneric(x: any): any[] {
  const type = getType(x);
  const fn = dispatchTable[type] || dispatchTable["other"];
  return fn(x);
}

// Test data: 2,000,000 calls with 5-type repeating cycle
const testData: any[] = [];
const cycle = [
  1,
  "test string",
  [1, 2, 3, 4, 5],
  [1, 2, 3, 4, 5],
  Symbol("symbol"),
];
for (let i = 0; i < 2000000; i++) {
  testData.push(cycle[i % cycle.length]);
}

// Benchmark function
function benchmark(iterations: number): void {
  console.log("Running dispatch benchmark (3 iterations):");
  for (let run = 0; run < iterations; run++) {
    const startNs = process.hrtime.bigint();
    for (let i = 0; i < testData.length; i++) {
      const result = dispatchGeneric(testData[i]);
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
  "TypeScript Generic Function Dispatch Micro-Benchmark"
);
console.log("================================");
console.log(`Implementation: TypeScript (Node.js ${process.version})`);
console.log(
  "Test data: 2,000,000 calls over repeating 5-type cycle"
);
console.log("  Type cycle: number -> string -> list -> vector -> symbol\n");

console.log("Warming up JIT compiler (10,000 calls)...");
for (let i = 0; i < 10000; i++) {
  dispatchGeneric(testData[i % testData.length]);
}
console.log("Warmup complete.\n");

benchmark(3);

console.log("\n================================");
console.log("Benchmark Complete");
console.log("================================");
