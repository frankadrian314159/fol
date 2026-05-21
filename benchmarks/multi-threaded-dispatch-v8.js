#!/usr/bin/env node
/**
 * Multi-threaded dispatch caching benchmark for V8 (Node.js)
 * Tests how lock contention affects dispatch cache performance
 *
 * Usage: node multi-threaded-dispatch-v8.js
 */

const { Worker, isMainThread, parentPort, workerData } = require('worker_threads');
const fs = require('fs');
const path = require('path');

const TEST_TYPE = {
  Int: 0,
  String: 1,
  List: 2,
  Other: 3
};

function getTestType(cycleIndex) {
  return Object.values(TEST_TYPE)[cycleIndex % 4];
}

// Dispatch functions (minimal work)
function dispatchInt(x) {
  return ['int', x & 0xFF];
}

function dispatchString(s) {
  return ['string', s.length];
}

function dispatchList(lst) {
  return ['list', lst.length];
}

function dispatchOther() {
  return ['other', 0];
}

// Uncached dispatch
function dispatchUncached(typ) {
  switch (typ) {
    case TEST_TYPE.Int:
      return dispatchInt(42);
    case TEST_TYPE.String:
      return dispatchString('test');
    case TEST_TYPE.List:
      return dispatchList([1, 2, 3]);
    case TEST_TYPE.Other:
      return dispatchOther();
  }
}

// Cached dispatch (Map-based, no lock needed in worker)
const cache = new Map();

function dispatchCached(typ) {
  if (!cache.has(typ)) {
    switch (typ) {
      case TEST_TYPE.Int:
        cache.set(typ, () => dispatchInt(42));
        break;
      case TEST_TYPE.String:
        cache.set(typ, () => dispatchString('test'));
        break;
      case TEST_TYPE.List:
        cache.set(typ, () => dispatchList([1, 2, 3]));
        break;
      case TEST_TYPE.Other:
        cache.set(typ, () => dispatchOther());
        break;
    }
  }
  return cache.get(typ)();
}

const CALL_COUNT = 100000;

// Worker thread code
if (!isMainThread) {
  const { uncached } = workerData;
  const fn = uncached ? dispatchUncached : dispatchCached;

  for (let i = 0; i < CALL_COUNT; i++) {
    fn(getTestType(i));
  }

  parentPort.postMessage({ done: true });
}

// Main thread code
async function runBenchmark(numThreads, uncached) {
  cache.clear();

  return new Promise((resolve) => {
    const workers = [];
    let completed = 0;
    const start = Date.now();

    for (let i = 0; i < numThreads; i++) {
      const worker = new Worker(__filename, {
        workerData: { uncached }
      });

      worker.on('message', () => {
        completed++;
        if (completed === numThreads) {
          const elapsed = Date.now() - start;
          resolve(elapsed);
          workers.forEach(w => w.terminate());
        }
      });

      workers.push(worker);
    }
  });
}

async function main() {
  console.log('================================');
  console.log('V8 (Node.js) Multi-Threaded Dispatch Caching');
  console.log('================================\n');

  console.log('Test parameters:');
  console.log(`  Calls per thread: ${CALL_COUNT.toLocaleString()}`);
  console.log('  Thread counts: 1, 2, 4, 8');
  console.log('  Workload: 4-type repeating cycle\n');

  // Warmup
  console.log('Warming up...');
  for (let i = 0; i < 2; i++) {
    await runBenchmark(2, false);
    await runBenchmark(2, true);
  }
  console.log('Warmup complete.\n');

  // Benchmark
  console.log('=== Uncached Dispatch ===');
  const uncachedTimes = {};
  for (const numThreads of [1, 2, 4, 8]) {
    const time = await runBenchmark(numThreads, true);
    uncachedTimes[numThreads] = time;
    const perCall = (time / (CALL_COUNT * numThreads) * 1000).toFixed(2);
    console.log(`  ${numThreads} thread${numThreads > 1 ? 's' : ''}: ${time.toFixed(2).padStart(7)} ms (${perCall.padStart(7)} µs/call/thread)`);
  }

  console.log('\n=== Cached Dispatch ===');
  const cachedTimes = {};
  for (const numThreads of [1, 2, 4, 8]) {
    const time = await runBenchmark(numThreads, false);
    cachedTimes[numThreads] = time;
    const perCall = (time / (CALL_COUNT * numThreads) * 1000).toFixed(2);
    console.log(`  ${numThreads} thread${numThreads > 1 ? 's' : ''}: ${time.toFixed(2).padStart(7)} ms (${perCall.padStart(7)} µs/call/thread)`);
  }

  // Summary
  console.log('\n=== Slowdown Scaling ===');
  for (const numThreads of [1, 2, 4, 8]) {
    const ratio = (cachedTimes[numThreads] / uncachedTimes[numThreads]).toFixed(2);
    console.log(`  ${numThreads} thread${numThreads > 1 ? 's' : ''}: ${ratio.padStart(5)}x slowdown`);
  }

  console.log('\n================================');
}

main().catch(console.error);
