import java.util.*;
import java.util.function.Function;

public class MethodDispatchBench {
    // Dispatch table using a map
    static Map<String, Function<Object, Object>> dispatchTable = new HashMap<>();

    static {
        dispatchTable.put("number", x -> new Object[]{"number", x});
        dispatchTable.put("string", x -> new Object[]{"string", ((String) x).length()});
        dispatchTable.put("object", x -> new Object[]{"object", ((HashMap) x).size()});
        dispatchTable.put("boolean", x -> new Object[]{"boolean", x});
        dispatchTable.put("other", x -> new Object[]{"other", x});
    }

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

    static Object dispatchGeneric(Object x) {
        String key = getTypeKey(x);
        Function<Object, Object> fn = dispatchTable.get(key);
        return fn.apply(x);
    }

    static void benchmarkDispatch(int iterations, List<Object> testData) {
        for (int run = 1; run <= iterations; run++) {
            long startTime = System.nanoTime();
            int result = 0;
            for (Object item : testData) {
                Object r = dispatchGeneric(item);
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
        System.out.println("Java Generic Function Dispatch Micro-Benchmark");
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
            dispatchGeneric(testData.get(i % testData.size()));
        }
        System.out.println("Warmup complete.\n");

        System.out.println("Running dispatch benchmark (3 iterations):");
        benchmarkDispatch(3, testData);

        System.out.println("\n================================");
        System.out.println("Benchmark Complete");
        System.out.println("================================");
    }
}
