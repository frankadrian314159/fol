import java.util.*;

public class DispatchCachingBenchmark {
    static class DispatchCache {
        private static final int CACHE_SIZE = 8;
        private Object[][] entries;
        private int nextIdx;
        private long hits;
        private long misses;

        public DispatchCache() {
            this.entries = new Object[CACHE_SIZE][2];
            this.nextIdx = 0;
            this.hits = 0;
            this.misses = 0;
        }

        public Object lookup(Object key) {
            for (int i = 0; i < CACHE_SIZE; i++) {
                if (entries[i] != null && entries[i][0] != null && entries[i][0].equals(key)) {
                    hits++;
                    return entries[i][1];
                }
            }
            misses++;
            return null;
        }

        public void insert(Object key, Object fn) {
            entries[nextIdx] = new Object[]{key, fn};
            nextIdx = (nextIdx + 1) % CACHE_SIZE;
        }

        public void reset() {
            entries = new Object[CACHE_SIZE][2];
            nextIdx = 0;
            hits = 0;
            misses = 0;
        }
    }

    interface Clause {
        Object call(Object x);
    }

    static Clause clauseLong = x -> new Object[]{"long", x};
    static Clause clauseString = x -> new Object[]{"string", ((String)x).length()};
    static Clause clauseList = x -> new Object[]{"list", ((List<?>)x).size()};
    static Clause clauseMap = x -> new Object[]{"map", ((Map<?,?>)x).size()};
    static Clause clauseOther = x -> new Object[]{"other", x};

    static String getType(Object x) {
        if (x instanceof Integer || x instanceof Double) {
            return "long";
        } else if (x instanceof String) {
            return "string";
        } else if (x instanceof List) {
            return "list";
        } else if (x instanceof Map) {
            return "map";
        } else {
            return "other";
        }
    }

    static Object dispatchUncached(Object x) {
        String type = getType(x);
        if (type.equals("long")) {
            return clauseLong.call(x);
        } else if (type.equals("string")) {
            return clauseString.call(x);
        } else if (type.equals("list")) {
            return clauseList.call(x);
        } else if (type.equals("map")) {
            return clauseMap.call(x);
        } else {
            return clauseOther.call(x);
        }
    }

    static Object dispatchCached(Object x, DispatchCache cache) {
        String type = getType(x);
        Object cached = cache.lookup(type);

        if (cached != null) {
            Clause fn = (Clause) cached;
            return fn.call(x);
        }

        Clause fn;
        if (type.equals("long")) {
            fn = clauseLong;
        } else if (type.equals("string")) {
            fn = clauseString;
        } else if (type.equals("list")) {
            fn = clauseList;
        } else if (type.equals("map")) {
            fn = clauseMap;
        } else {
            fn = clauseOther;
        }

        cache.insert(type, fn);
        return fn.call(x);
    }

    public static void main(String[] args) {
        System.out.println("================================");
        System.out.println("Java Heterogeneous Dispatch Caching Micro-Benchmark");
        System.out.println("================================");
        System.out.println("Implementation: " + System.getProperty("java.version"));
        System.out.println("VM: " + System.getProperty("java.vm.name"));
        System.out.println("Test data: 2,000,000 calls over repeating 4-type cycle\n");

        // Create test data: 2M items with 4-type repeating cycle
        Object[] cycle = {
            1,
            "test string",
            Arrays.asList(1, 2, 3, 4, 5),
            new HashMap<String, Integer>() {{
                put("a", 1);
            }}
        };

        Object[] testData = new Object[2000000];
        for (int i = 0; i < 2000000; i++) {
            testData[i] = cycle[i % 4];
        }

        System.out.println("Warming up JIT compiler (100,000 calls)...");
        for (int i = 0; i < 100000; i++) {
            dispatchUncached(testData[i % testData.length]);
        }

        DispatchCache cache = new DispatchCache();
        for (int i = 0; i < 100000; i++) {
            dispatchCached(testData[i % testData.length], cache);
        }
        System.out.println("Warmup complete.\n");

        // Benchmark uncached
        System.out.println("=== Uncached Dispatch (3 iterations, 2M calls each) ===");
        long[] uncachedTimes = new long[3];
        for (int run = 0; run < 3; run++) {
            long start = System.nanoTime();
            for (Object item : testData) {
                dispatchUncached(item);
            }
            long elapsed = System.nanoTime() - start;
            uncachedTimes[run] = elapsed;
            double seconds = elapsed / 1_000_000_000.0;
            double ns_per_call = (double)elapsed / testData.length;
            System.out.printf("  Run %d: %.4f seconds (%.1f ns/call)%n", run + 1, seconds, ns_per_call);
        }

        // Benchmark cached
        System.out.println("\n=== Cached Dispatch (3 iterations, 2M calls each) ===");
        long[] cachedTimes = new long[3];
        for (int run = 0; run < 3; run++) {
            cache.reset();
            long start = System.nanoTime();
            for (Object item : testData) {
                dispatchCached(item, cache);
            }
            long elapsed = System.nanoTime() - start;
            cachedTimes[run] = elapsed;
            double seconds = elapsed / 1_000_000_000.0;
            double ns_per_call = (double)elapsed / testData.length;
            System.out.printf("  Run %d: %.4f seconds (%.1f ns/call)%n", run + 1, seconds, ns_per_call);
        }

        // Summary
        System.out.println("\nCached Dispatch Stats:");
        long totalHits = 0, totalMisses = 0;
        for (int i = 0; i < 100; i++) {
            cache.reset();
            for (Object item : testData) {
                dispatchCached(item, cache);
            }
            totalHits += cache.hits;
            totalMisses += cache.misses;
        }
        double hitRate = 100.0 * totalHits / (totalHits + totalMisses);
        System.out.printf("  Total hits: %d%n", totalHits);
        System.out.printf("  Total misses: %d%n", totalMisses);
        System.out.printf("  Hit rate: %.4f%%%n", hitRate);

        // Calculate ratios
        double avgUncached = Arrays.stream(uncachedTimes).average().orElse(0);
        double avgCached = Arrays.stream(cachedTimes).average().orElse(0);
        double ratio = avgCached / avgUncached;

        System.out.println("\n================================");
        System.out.printf("Average uncached: %.1f ns/call%n", avgUncached / testData.length);
        System.out.printf("Average cached: %.1f ns/call%n", avgCached / testData.length);
        System.out.printf("Slowdown ratio: %.2f×%n", ratio);
        System.out.println("================================");
    }
}
