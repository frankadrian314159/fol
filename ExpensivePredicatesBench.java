import java.util.HashMap;
import java.util.regex.Pattern;

public class ExpensivePredicatesBench {

    static class DispatchCache {
        HashMap<String, java.util.function.Function<String, String>>[] entries;
        int nextIdx = 0;
        long hits = 0;
        long misses = 0;

        @SuppressWarnings("unchecked")
        DispatchCache() {
            entries = new HashMap[8];
            for (int i = 0; i < 8; i++) {
                entries[i] = new HashMap<>();
            }
        }

        synchronized java.util.function.Function<String, String> lookup(String key) {
            for (int i = 0; i < 8; i++) {
                if (entries[i].containsKey(key)) {
                    hits++;
                    return entries[i].get(key);
                }
            }
            misses++;
            return null;
        }

        synchronized void insert(String key, java.util.function.Function<String, String> fn) {
            entries[nextIdx].clear();
            entries[nextIdx].put(key, fn);
            nextIdx = (nextIdx + 1) % 8;
        }

        synchronized void reset() {
            hits = 0;
            misses = 0;
            nextIdx = 0;
            for (int i = 0; i < 8; i++) {
                entries[i].clear();
            }
        }
    }

    // Expensive predicates with regex matching
    static Pattern EMAIL_PATTERN = Pattern.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$");
    static Pattern JSON_PATTERN = Pattern.compile("^[\\s]*[\\{\\[].*[\\}\\]][\\s]*$");
    static Pattern IP_PATTERN = Pattern.compile("^(\\d{1,3}\\.){3}\\d{1,3}$");
    static Pattern URL_PATTERN = Pattern.compile("^https?://[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}(/[a-zA-Z0-9._~:/?#\\[\\]@!$&'()*+,;=-]*)?$");
    static Pattern ALPHANUM_PATTERN = Pattern.compile("^[a-zA-Z0-9]+$");

    static boolean isEmail(String x) {
        return EMAIL_PATTERN.matcher(x).matches();
    }

    static boolean isJSON(String x) {
        return JSON_PATTERN.matcher(x).matches();
    }

    static boolean isIP(String x) {
        return IP_PATTERN.matcher(x).matches();
    }

    static boolean isURL(String x) {
        return URL_PATTERN.matcher(x).matches();
    }

    static boolean isAlphaNum(String x) {
        return ALPHANUM_PATTERN.matcher(x).matches();
    }

    static String clauseEmail(String x) { return "email"; }
    static String clauseJSON(String x) { return "json"; }
    static String clauseIP(String x) { return "ipaddress"; }
    static String clauseURL(String x) { return "url"; }
    static String clauseAlphaNum(String x) { return "alphanumeric"; }
    static String clauseUnknown(String x) { return "unknown"; }

    // Uncached dispatch
    static String dispatchUncached(String x) {
        if (isEmail(x)) return clauseEmail(x);
        if (isJSON(x)) return clauseJSON(x);
        if (isIP(x)) return clauseIP(x);
        if (isURL(x)) return clauseURL(x);
        if (isAlphaNum(x)) return clauseAlphaNum(x);
        return clauseUnknown(x);
    }

    // Cached dispatch
    static String dispatchCached(String x, DispatchCache cache) {
        String key = x.length() > 20 ? x.substring(0, 20) : x;
        java.util.function.Function<String, String> cached = cache.lookup(key);

        if (cached != null) {
            return cached.apply(x);
        }

        java.util.function.Function<String, String> fn;
        if (isEmail(x)) fn = ExpensivePredicatesBench::clauseEmail;
        else if (isJSON(x)) fn = ExpensivePredicatesBench::clauseJSON;
        else if (isIP(x)) fn = ExpensivePredicatesBench::clauseIP;
        else if (isURL(x)) fn = ExpensivePredicatesBench::clauseURL;
        else if (isAlphaNum(x)) fn = ExpensivePredicatesBench::clauseAlphaNum;
        else fn = ExpensivePredicatesBench::clauseUnknown;

        cache.insert(key, fn);
        return fn.apply(x);
    }

    public static void main(String[] args) throws InterruptedException {
        int numCalls = 100000;

        System.out.println("================================");
        System.out.println("OpenJDK C2 Expensive Predicates Dispatch Caching Benchmark");
        System.out.println("================================");
        System.out.println("Test data: " + numCalls + " calls with expensive predicates");
        System.out.println("  Predicates: email, JSON, IP address, URL, alphanumeric");
        System.out.println("  Predicate cost: 1-3 microseconds each (regex matching)");
        System.out.println("  Uncached dispatch cost: 5-15 microseconds");
        System.out.println("  Cache benefit potential: Massive if expensive predicates save checks\n");

        String[] testData = new String[numCalls];
        String[] patterns = {
            "user@example.com",
            "{\"key\": \"value\"}",
            "192.168.1.1",
            "https://example.com/path?query=value",
            "abc123def456"
        };

        for (int i = 0; i < numCalls; i++) {
            testData[i] = patterns[i % 5];
        }

        // Warmup
        System.out.println("Warming up JIT (10,000 calls)...");
        for (int i = 0; i < 10000; i++) {
            dispatchUncached(testData[i % numCalls]);
        }

        DispatchCache cache = new DispatchCache();
        for (int i = 0; i < 10000; i++) {
            dispatchCached(testData[i % numCalls], cache);
        }
        System.out.println("Warmup complete.\n");

        // Uncached benchmark
        System.out.println("=== Uncached Expensive Dispatch (3 iterations) ===");
        long[] uncachedTimes = new long[3];
        for (int run = 0; run < 3; run++) {
            long start = System.nanoTime();
            for (int i = 0; i < numCalls; i++) {
                dispatchUncached(testData[i]);
            }
            long elapsed = System.nanoTime() - start;
            uncachedTimes[run] = elapsed;
            double seconds = elapsed / 1e9;
            double usPerCall = (elapsed / 1e3) / numCalls;
            System.out.printf("  Run %d: %.4f seconds (%.2f us/call)%n", run + 1, seconds, usPerCall);
        }

        // Cached benchmark
        System.out.println("\n=== Cached Expensive Dispatch (3 iterations) ===");
        long[] cachedTimes = new long[3];
        for (int run = 0; run < 3; run++) {
            cache.reset();
            long start = System.nanoTime();
            for (int i = 0; i < numCalls; i++) {
                dispatchCached(testData[i], cache);
            }
            long elapsed = System.nanoTime() - start;
            cachedTimes[run] = elapsed;
            double seconds = elapsed / 1e9;
            double usPerCall = (elapsed / 1e3) / numCalls;
            System.out.printf("  Run %d: %.4f seconds (%.2f us/call)%n", run + 1, seconds, usPerCall);
        }

        // Stats
        System.out.println("\nCached Dispatch Stats:");
        System.out.println("  Cache hits: " + cache.hits);
        System.out.println("  Cache misses: " + cache.misses);
        long total = cache.hits + cache.misses;
        if (total > 0) {
            double hitRate = 100.0 * cache.hits / total;
            System.out.printf("  Hit rate: %.4f%%%n", hitRate);
        }

        // Summary
        long avgUncached = (uncachedTimes[0] + uncachedTimes[1] + uncachedTimes[2]) / 3;
        long avgCached = (cachedTimes[0] + cachedTimes[1] + cachedTimes[2]) / 3;

        double usUncached = (avgUncached / 1e3) / numCalls;
        double usCached = (avgCached / 1e3) / numCalls;
        double ratio = (double) avgCached / avgUncached;

        System.out.println("\n================================");
        System.out.printf("Average uncached: %.2f us/call%n", usUncached);
        System.out.printf("Average cached: %.2f us/call%n", usCached);
        System.out.printf("Speedup/Slowdown ratio: %.2f%%%n", ratio * 100);

        if (ratio < 1.0) {
            System.out.printf("SPEEDUP: %d%% faster%n", (int) ((1.0 - ratio) * 100));
        } else {
            System.out.printf("SLOWDOWN: %d%% slower%n", (int) ((ratio - 1.0) * 100));
        }

        System.out.println("\nBreak-even analysis:");
        System.out.println("  Predicate cost: 5 to 15 microseconds (expensive)");
        System.out.println("  Cache overhead: Varies with JIT optimization");
        System.out.println("  Theoretical: Should see speedup if expensive predicates save checks");
        System.out.println("================================");
    }
}
