#!/usr/bin/env node
"use strict";
/// Micro-benchmark: heterogeneous dispatch (TypeScript version)
/// Compares dispatch caching across type cycles
const CACHE_SIZE = 8;
class DispatchCache {
    constructor() {
        this.entries = [];
        this.nextIdx = 0;
        this.hits = 0;
        this.misses = 0;
        for (let i = 0; i < CACHE_SIZE; i++) {
            this.entries[i] = { key: "", fn: () => { } };
        }
    }
    lookup(key) {
        for (let i = 0; i < CACHE_SIZE; i++) {
            if (this.entries[i] && this.entries[i].key === key) {
                return this.entries[i].fn;
            }
        }
        return null;
    }
    insert(key, fn) {
        this.entries[this.nextIdx] = { key, fn };
        this.nextIdx = (this.nextIdx + 1) % CACHE_SIZE;
    }
    reset() {
        this.hits = 0;
        this.misses = 0;
    }
}
// Type checking functions
function getType(x) {
    if (typeof x === "number")
        return "number";
    if (typeof x === "string")
        return "string";
    if (Array.isArray(x)) {
        if (typeof x[0] === "number")
            return "list";
        return "vector";
    }
    if (typeof x === "symbol")
        return "symbol";
    return "other";
}
// Clause functions
const clauseNumber = (x) => ["number", x];
const clauseString = (x) => ["string", x.length];
const clauseList = (x) => ["list", x.length];
const clauseVector = (x) => ["vector", x.length];
const clauseSymbol = (x) => ["symbol", x];
const clauseOther = (x) => ["other", x];
// Uncached dispatcher
function dispatchHeteroUncached(x) {
    const type = getType(x);
    switch (type) {
        case "number":
            return clauseNumber(x);
        case "string":
            return clauseString(x);
        case "list":
            return clauseList(x);
        case "vector":
            return clauseVector(x);
        case "symbol":
            return clauseSymbol(x);
        default:
            return clauseOther(x);
    }
}
// Cached dispatcher
const heteroCache = new DispatchCache();
function dispatchHetroCached(x) {
    const type = getType(x);
    const hit = heteroCache.lookup(type);
    if (hit) {
        heteroCache.hits++;
        return hit(x);
    }
    else {
        heteroCache.misses++;
        let fn = clauseOther;
        switch (type) {
            case "number":
                fn = clauseNumber;
                break;
            case "string":
                fn = clauseString;
                break;
            case "list":
                fn = clauseList;
                break;
            case "vector":
                fn = clauseVector;
                break;
            case "symbol":
                fn = clauseSymbol;
                break;
        }
        heteroCache.insert(type, fn);
        return fn(x);
    }
}
// Test data: 2,000,000 calls with 5-type repeating cycle
const testData = [];
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
function benchmarkUncached(iterations) {
    console.log("=== Uncached COND Dispatch (3 iterations) ===");
    for (let run = 0; run < iterations; run++) {
        const startNs = process.hrtime.bigint();
        for (let i = 0; i < testData.length; i++) {
            const result = dispatchHeteroUncached(testData[i]);
        }
        const elapsedNs = process.hrtime.bigint() - startNs;
        const elapsedMs = Number(elapsedNs) / 1000000;
        const elapsedSec = elapsedMs / 1000;
        console.log(`  Run ${run + 1}: ${elapsedSec.toFixed(1)} seconds`);
    }
}
function benchmarkCached(iterations) {
    console.log("\n=== Cached Dispatch (3 iterations) ===");
    for (let run = 0; run < iterations; run++) {
        heteroCache.reset();
        const startNs = process.hrtime.bigint();
        for (let i = 0; i < testData.length; i++) {
            const result = dispatchHetroCached(testData[i]);
        }
        const elapsedNs = process.hrtime.bigint() - startNs;
        const elapsedMs = Number(elapsedNs) / 1000000;
        const elapsedSec = elapsedMs / 1000;
        console.log(`  Run ${run + 1}: ${elapsedSec.toFixed(1)} seconds`);
    }
}
// Main
console.log("================================");
console.log("TypeScript Heterogeneous Dispatch Caching Micro-Benchmark");
console.log("================================");
console.log(`Implementation: TypeScript (Node.js ${process.version})`);
console.log("Test data: 2,000,000 calls over repeating 5-type cycle");
console.log("  Type cycle: number -> string -> list -> vector -> symbol\n");
console.log("Warming up JIT compiler (10,000 calls)...");
for (let i = 0; i < 10000; i++) {
    dispatchHeteroUncached(testData[i % testData.length]);
    dispatchHetroCached(testData[i % testData.length]);
}
console.log("Warmup complete.\n");
benchmarkUncached(3);
benchmarkCached(3);
console.log("\nCached Dispatch Stats:");
console.log(`  Cache hits: ${heteroCache.hits}`);
console.log(`  Cache misses: ${heteroCache.misses}`);
const total = heteroCache.hits + heteroCache.misses;
const hitRate = total > 0
    ? ((heteroCache.hits / total) * 100).toFixed(4)
    : "0.0000";
console.log(`  Hit rate: ${hitRate}%`);
console.log("\n================================");
console.log("Benchmark Complete");
console.log("================================");
