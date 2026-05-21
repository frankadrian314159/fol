import 'dart:core';

class DispatchCache {
  static const int cacheSize = 8;
  late List<List<dynamic>?> entries;
  late int nextIdx;
  late int hits;
  late int misses;

  DispatchCache() {
    entries = List<List<dynamic>?>.filled(cacheSize, null);
    nextIdx = 0;
    hits = 0;
    misses = 0;
  }

  dynamic lookup(dynamic key) {
    for (int i = 0; i < cacheSize; i++) {
      if (entries[i] != null && entries[i]![0] == key) {
        hits++;
        return entries[i]![1];
      }
    }
    misses++;
    return null;
  }

  void insert(dynamic key, dynamic fn) {
    entries[nextIdx] = [key, fn];
    nextIdx = (nextIdx + 1) % cacheSize;
  }

  void reset() {
    entries = List<List<dynamic>?>.filled(cacheSize, null);
    nextIdx = 0;
    hits = 0;
    misses = 0;
  }
}

dynamic clauseLong(dynamic x) => ["long", x];
dynamic clauseString(dynamic x) => ["string", (x as String).length];
dynamic clauseList(dynamic x) => ["list", (x as List).length];
dynamic clauseMap(dynamic x) => ["map", (x as Map).length];
dynamic clauseOther(dynamic x) => ["other", x];

String getType(dynamic x) {
  if (x is int || x is double) {
    return "long";
  } else if (x is String) {
    return "string";
  } else if (x is List) {
    return "list";
  } else if (x is Map) {
    return "map";
  } else {
    return "other";
  }
}

dynamic dispatchUncached(dynamic x) {
  String type = getType(x);
  switch (type) {
    case "long":
      return clauseLong(x);
    case "string":
      return clauseString(x);
    case "list":
      return clauseList(x);
    case "map":
      return clauseMap(x);
    default:
      return clauseOther(x);
  }
}

dynamic dispatchCached(dynamic x, DispatchCache cache) {
  String type = getType(x);
  dynamic cached = cache.lookup(type);

  if (cached != null) {
    var fn = cached as Function;
    return Function.apply(fn, [x]);
  }

  dynamic fn;
  switch (type) {
    case "long":
      fn = clauseLong;
      break;
    case "string":
      fn = clauseString;
      break;
    case "list":
      fn = clauseList;
      break;
    case "map":
      fn = clauseMap;
      break;
    default:
      fn = clauseOther;
  }

  cache.insert(type, fn);
  return Function.apply(fn as Function, [x]);
}

void main() {
  print("================================");
  print("Dart Heterogeneous Dispatch Caching Micro-Benchmark");
  print("================================");
  print("Test data: 2,000,000 calls over repeating 4-type cycle\n");

  // Create test data: 2M items with 4-type repeating cycle
  final List<dynamic> cycle = [
    42,
    "test string",
    [1, 2, 3, 4, 5],
    {"a": 1}
  ];

  final List<dynamic> testData = List<dynamic>.generate(
    2000000,
    (i) => cycle[i % 4],
  );

  print("Warming up (100,000 calls)...");
  for (int i = 0; i < 100000; i++) {
    dispatchUncached(testData[i % testData.length]);
  }

  DispatchCache cache = DispatchCache();
  for (int i = 0; i < 100000; i++) {
    dispatchCached(testData[i % testData.length], cache);
  }
  print("Warmup complete.\n");

  // Benchmark uncached
  print("=== Uncached Dispatch (3 iterations, 2M calls each) ===");
  List<int> uncachedTimes = [];
  for (int run = 0; run < 3; run++) {
    final stopwatch = Stopwatch()..start();
    for (dynamic item in testData) {
      dispatchUncached(item);
    }
    stopwatch.stop();
    int elapsedMicros = stopwatch.elapsedMicroseconds;
    uncachedTimes.add(elapsedMicros);
    double seconds = elapsedMicros / 1000000.0;
    double nsPerCall = (elapsedMicros * 1000.0) / testData.length;
    print("  Run ${run + 1}: ${seconds.toStringAsFixed(4)} seconds (${nsPerCall.toStringAsFixed(1)} ns/call)");
  }

  // Benchmark cached
  print("\n=== Cached Dispatch (3 iterations, 2M calls each) ===");
  List<int> cachedTimes = [];
  for (int run = 0; run < 3; run++) {
    cache.reset();
    final stopwatch = Stopwatch()..start();
    for (dynamic item in testData) {
      dispatchCached(item, cache);
    }
    stopwatch.stop();
    int elapsedMicros = stopwatch.elapsedMicroseconds;
    cachedTimes.add(elapsedMicros);
    double seconds = elapsedMicros / 1000000.0;
    double nsPerCall = (elapsedMicros * 1000.0) / testData.length;
    print("  Run ${run + 1}: ${seconds.toStringAsFixed(4)} seconds (${nsPerCall.toStringAsFixed(1)} ns/call)");
  }

  // Summary
  print("\nCached Dispatch Stats:");
  int totalHits = 0, totalMisses = 0;
  for (int i = 0; i < 100; i++) {
    cache.reset();
    for (dynamic item in testData) {
      dispatchCached(item, cache);
    }
    totalHits += cache.hits;
    totalMisses += cache.misses;
  }
  double hitRate = 100.0 * totalHits / (totalHits + totalMisses);
  print("  Total hits: $totalHits");
  print("  Total misses: $totalMisses");
  print("  Hit rate: ${hitRate.toStringAsFixed(4)}%");

  // Calculate ratios
  double avgUncached = uncachedTimes.reduce((a, b) => a + b) / uncachedTimes.length.toDouble();
  double avgCached = cachedTimes.reduce((a, b) => a + b) / cachedTimes.length.toDouble();
  double ratio = avgCached / avgUncached;

  print("\n================================");
  print("Average uncached: ${(avgUncached * 1000.0 / testData.length).toStringAsFixed(1)} ns/call");
  print("Average cached: ${(avgCached * 1000.0 / testData.length).toStringAsFixed(1)} ns/call");
  print("Slowdown ratio: ${ratio.toStringAsFixed(2)}×");
  print("================================");
}
