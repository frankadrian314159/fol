import java.util.*;

public class SimpleMicroBench {
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

    static DispatchCache homoCache = new DispatchCache();

    static Object dispatchHomoUncached(Object x) {
        if (x instanceof Integer || x instanceof Long || x instanceof Double) {
            return new Object[]{("number"), x};
        } else {
            return new Object[]{("other"), x};
        }
    }

    static Object dispatchHomoCached(Object x) {
        String key = "number";
        Object hit = homoCache.lookup(key);

        if (hit != null) {
            homoCache.hits++;
            java.util.function.Function<Object, Object> fn =
                (java.util.function.Function<Object, Object>) hit;
            return fn.apply(x);
        }

        homoCache.misses++;
        homoCache.insert(key, SimpleMicroBench::clauseNumber);
        return clauseNumber(x);
    }

    static void benchmarkUncached(int iterations, List<Object> testData) {
        for (int run = 1; run <= iterations; run++) {
            long startTime = System.nanoTime();
            int result = 0;
            for (Object item : testData) {
                Object r = dispatchHomoUncached(item);
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
            homoCache.hits = 0;
            homoCache.misses = 0;
            long startTime = System.nanoTime();
            int result = 0;
            for (Object item : testData) {
                Object r = dispatchHomoCached(item);
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
        System.out.println("Java Homogeneous Dispatch Caching Micro-Benchmark");
        System.out.println("================================");
        System.out.println("Implementation: " + System.getProperty("java.version"));
        System.out.println("Test data: 200,000 number-only calls\n");

        // Create test data
        List<Object> testData = new ArrayList<>();
        Random rand = new Random(42);
        for (int i = 0; i < 200000; i++) {
            testData.add(rand.nextInt(1000000));
        }

        System.out.println("Warming up JIT compiler (20,000 calls)...");
        for (int i = 0; i < 20000; i++) {
            dispatchHomoUncached(testData.get(i % testData.size()));
            dispatchHomoCached(testData.get(i % testData.size()));
        }
        System.out.println("Warmup complete.\n");

        System.out.println("=== Uncached Dispatch (3 iterations) ===");
        benchmarkUncached(3, testData);

        System.out.println("\n=== Cached Dispatch (3 iterations) ===");
        benchmarkCached(3, testData);

        System.out.println("\nCached Dispatch Stats:");
        long total = homoCache.hits + homoCache.misses;
        System.out.println("  Cache hits: " + homoCache.hits);
        System.out.println("  Cache misses: " + homoCache.misses);
        if (total > 0) {
            double hitRate = (100.0 * homoCache.hits) / total;
            System.out.printf("  Hit rate: %.4f%%%n", hitRate);
        }

        System.out.println("\n================================");
        System.out.println("Benchmark Complete");
        System.out.println("================================");
    }
}
