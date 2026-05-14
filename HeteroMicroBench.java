import java.util.*;

public class HeteroMicroBench {
    private static final int CACHE_SIZE = 8;

    static class DispatchCache {
        Object[][] entries = new Object[CACHE_SIZE][2];
        int nextIdx = 0;
        long hits = 0;
        long misses = 0;

        Object lookup(String key) {
            for (int i = 0; i < CACHE_SIZE; i++) {
                if (entries[i] != null && entries[i][0] != null && entries[i][0].equals(key)) {
                    return entries[i][1];
                }
            }
            return null;
        }

        void insert(String key, java.util.function.Function<Object, Object> fn) {
            entries[nextIdx] = new Object[]{key, fn};
            nextIdx = (nextIdx + 1) % CACHE_SIZE;
        }
    }

    static Object clauseNumber(Object x) {
        return new Object[]{("number"), x};
    }

    static Object clauseString(Object x) {
        return new Object[]{("string"), ((String) x).length()};
    }

    static Object clauseObject(Object x) {
        return new Object[]{("object"), ((java.util.HashMap) x).size()};
    }

    static Object clauseBoolean(Object x) {
        return new Object[]{("boolean"), x};
    }

    static Object clauseOther(Object x) {
        return new Object[]{("other"), x};
    }

    static DispatchCache heteroCache = new DispatchCache();

    static String getTypeKey(Object x) {
        if (x instanceof Integer || x instanceof Long || x instanceof Double) {
            return "number";
        } else if (x instanceof String) {
            return "string";
        } else if (x instanceof HashMap) {
            return "object";
        } else if (x instanceof Boolean) {
            return "boolean";
        } else {
            return "other";
        }
    }

    static Object dispatchHeteroUncached(Object x) {
        if (x instanceof Integer || x instanceof Long || x instanceof Double) {
            return clauseNumber(x);
        } else if (x instanceof String) {
            return clauseString(x);
        } else if (x instanceof HashMap) {
            return clauseObject(x);
        } else if (x instanceof Boolean) {
            return clauseBoolean(x);
        } else {
            return clauseOther(x);
        }
    }

    static Object dispatchHeteroCached(Object x) {
        String key = getTypeKey(x);
        Object hit = heteroCache.lookup(key);

        if (hit != null) {
            heteroCache.hits++;
            java.util.function.Function<Object, Object> fn =
                (java.util.function.Function<Object, Object>) hit;
            return fn.apply(x);
        }

        heteroCache.misses++;
        if (x instanceof Integer || x instanceof Long || x instanceof Double) {
            heteroCache.insert(key, HeteroMicroBench::clauseNumber);
            return clauseNumber(x);
        } else if (x instanceof String) {
            heteroCache.insert(key, HeteroMicroBench::clauseString);
            return clauseString(x);
        } else if (x instanceof HashMap) {
            heteroCache.insert(key, HeteroMicroBench::clauseObject);
            return clauseObject(x);
        } else if (x instanceof Boolean) {
            heteroCache.insert(key, HeteroMicroBench::clauseBoolean);
            return clauseBoolean(x);
        } else {
            heteroCache.insert(key, HeteroMicroBench::clauseOther);
            return clauseOther(x);
        }
    }

    static void benchmarkUncached(int iterations, List<Object> testData) {
        for (int run = 1; run <= iterations; run++) {
            long startTime = System.nanoTime();
            int result = 0;
            for (Object item : testData) {
                Object r = dispatchHeteroUncached(item);
                if (r != null) result++;
            }
            long elapsedNs = System.nanoTime() - startTime;
            double elapsedMs = elapsedNs / 1_000_000.0;
            double elapsedSec = elapsedMs / 1000.0;
            System.out.printf("  Run %d: %.1f seconds%n", run, elapsedSec);
        }
    }

    static void benchmarkCached(int iterations, List<Object> testData) {
        for (int run = 1; run <= iterations; run++) {
            heteroCache.hits = 0;
            heteroCache.misses = 0;
            long startTime = System.nanoTime();
            int result = 0;
            for (Object item : testData) {
                Object r = dispatchHeteroCached(item);
                if (r != null) result++;
            }
            long elapsedNs = System.nanoTime() - startTime;
            double elapsedMs = elapsedNs / 1_000_000.0;
            double elapsedSec = elapsedMs / 1000.0;
            System.out.printf("  Run %d: %.1f seconds%n", run, elapsedSec);
        }
    }

    public static void main(String[] args) {
        System.out.println("\n================================");
        System.out.println("Java Heterogeneous Dispatch Caching Micro-Benchmark");
        System.out.println("================================");
        System.out.println("Implementation: " + System.getProperty("java.version"));
        System.out.println("Test data: 200,000 calls over repeating 5-type cycle");
        System.out.println("  Type cycle: number -> string -> object -> boolean -> other\n");

        // Create test data
        List<Object> testData = new ArrayList<>();
        Object[] cycle = new Object[]{
            1,
            "test string",
            new HashMap<String, Integer>() {{
                put("a", 1); put("b", 2); put("c", 3); put("d", 4); put("e", 5);
            }},
            true,
            "symbol"
        };
        for (int i = 0; i < 200000; i++) {
            testData.add(cycle[i % 5]);
        }

        System.out.println("Warming up JIT compiler (20,000 calls)...");
        for (int i = 0; i < 20000; i++) {
            dispatchHeteroUncached(testData.get(i % testData.size()));
            dispatchHeteroCached(testData.get(i % testData.size()));
        }
        System.out.println("Warmup complete.\n");

        System.out.println("=== Uncached Dispatch (3 iterations) ===");
        benchmarkUncached(3, testData);

        System.out.println("\n=== Cached Dispatch (3 iterations) ===");
        benchmarkCached(3, testData);

        System.out.println("\nCached Dispatch Stats:");
        long total = heteroCache.hits + heteroCache.misses;
        System.out.println("  Cache hits: " + heteroCache.hits);
        System.out.println("  Cache misses: " + heteroCache.misses);
        if (total > 0) {
            double hitRate = (100.0 * heteroCache.hits) / total;
            System.out.printf("  Hit rate: %.4f%%%n", hitRate);
        }

        System.out.println("\n================================");
        System.out.println("Benchmark Complete");
        System.out.println("================================");
    }
}
