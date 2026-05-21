/**
 * Multi-threaded dispatch caching benchmark for Java
 * Tests how lock contention affects dispatch cache performance
 *
 * Compile: javac MultiThreadedDispatchBenchmark.java
 * Usage: java MultiThreadedDispatchBenchmark
 */

import java.util.*;
import java.util.concurrent.*;

enum TestType {
    INT, STRING, LIST, OTHER;

    static TestType fromIndex(int index) {
        return values()[index % 4];
    }
}

public class MultiThreadedDispatchBenchmark {
    private static final int CALL_COUNT = 100_000;
    private static final Map<TestType, Object> cache = new ConcurrentHashMap<>();
    private static final Object LOCK = new Object();

    // Dispatch functions (minimal work)
    static String dispatchInt(int x) {
        return "int";
    }

    static String dispatchString(String s) {
        return "string";
    }

    static String dispatchList() {
        return "list";
    }

    static String dispatchOther() {
        return "other";
    }

    // Uncached dispatch
    static String dispatchUncached(TestType type) {
        switch (type) {
            case INT:
                return dispatchInt(42);
            case STRING:
                return dispatchString("test");
            case LIST:
                return dispatchList();
            case OTHER:
                return dispatchOther();
            default:
                throw new IllegalArgumentException();
        }
    }

    // Cached dispatch with lock
    static String dispatchCached(TestType type) {
        if (!cache.containsKey(type)) {
            synchronized (LOCK) {
                if (!cache.containsKey(type)) {
                    switch (type) {
                        case INT:
                            cache.put(type, "int");
                            break;
                        case STRING:
                            cache.put(type, "string");
                            break;
                        case LIST:
                            cache.put(type, "list");
                            break;
                        case OTHER:
                            cache.put(type, "other");
                            break;
                    }
                }
            }
        }
        return (String) cache.get(type);
    }

    static long runBenchmark(int numThreads, boolean uncached) throws InterruptedException {
        cache.clear();
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        long start = System.nanoTime();

        for (int t = 0; t < numThreads; t++) {
            executor.submit(() -> {
                for (int i = 0; i < CALL_COUNT; i++) {
                    if (uncached) {
                        dispatchUncached(TestType.fromIndex(i));
                    } else {
                        dispatchCached(TestType.fromIndex(i));
                    }
                }
            });
        }

        executor.shutdown();
        executor.awaitTermination(10, TimeUnit.SECONDS);
        return (System.nanoTime() - start) / 1_000_000; // ms
    }

    public static void main(String[] args) throws InterruptedException {
        System.out.println("================================");
        System.out.println("Java Multi-Threaded Dispatch Caching");
        System.out.println("================================\n");

        System.out.println("Test parameters:");
        System.out.println("  Calls per thread: " + String.format("%,d", CALL_COUNT));
        System.out.println("  Thread counts: 1, 2, 4, 8");
        System.out.println("  Workload: 4-type repeating cycle\n");

        // Warmup
        System.out.println("Warming up...");
        for (int i = 0; i < 2; i++) {
            runBenchmark(2, true);
            runBenchmark(2, false);
        }
        System.out.println("Warmup complete.\n");

        // Benchmark
        System.out.println("=== Uncached Dispatch ===");
        Map<Integer, Long> uncachedTimes = new TreeMap<>();
        for (int nt : new int[]{1, 2, 4, 8}) {
            long timeMs = runBenchmark(nt, true);
            uncachedTimes.put(nt, timeMs);
            double perCall = (double) timeMs / (CALL_COUNT * nt) * 1000;
            System.out.printf("  %d thread%s: %7d ms (%7.2f µs/call/thread)%n",
                    nt, nt > 1 ? "s" : "", timeMs, perCall);
        }

        System.out.println("\n=== Cached Dispatch ===");
        Map<Integer, Long> cachedTimes = new TreeMap<>();
        for (int nt : new int[]{1, 2, 4, 8}) {
            long timeMs = runBenchmark(nt, false);
            cachedTimes.put(nt, timeMs);
            double perCall = (double) timeMs / (CALL_COUNT * nt) * 1000;
            System.out.printf("  %d thread%s: %7d ms (%7.2f µs/call/thread)%n",
                    nt, nt > 1 ? "s" : "", timeMs, perCall);
        }

        // Summary
        System.out.println("\n=== Slowdown Scaling ===");
        for (int nt : new int[]{1, 2, 4, 8}) {
            double ratio = (double) cachedTimes.get(nt) / uncachedTimes.get(nt);
            System.out.printf("  %d thread%s: %5.2fx slowdown%n",
                    nt, nt > 1 ? "s" : "", ratio);
        }

        System.out.println("\n================================");
    }
}
