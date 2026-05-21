#include <stdio.h>
#include <time.h>
#include <string.h>

typedef struct {
    const char* type_name;
    int size;
} DispatchResult;

typedef DispatchResult (*Handler)();

DispatchResult int_handler() { return {"int", 42}; }
DispatchResult string_handler() { return {"string", 11}; }
DispatchResult vector_handler() { return {"vector", 5}; }
DispatchResult other_handler() { return {"other", 0}; }

int test_type(int i) {
    return i % 4;
}

DispatchResult dispatch_uncached(int type) {
    switch (type) {
        case 0: return {"int", 42};
        case 1: return {"string", 11};
        case 2: return {"vector", 5};
        default: return {"other", 0};
    }
}

struct CacheEntry {
    int key;
    Handler handler;
};

DispatchResult dispatch_cached(int type, struct CacheEntry cache[256], int* cache_size) {
    for (int i = 0; i < *cache_size; i++) {
        if (cache[i].key == type) {
            return cache[i].handler();
        }
    }

    Handler handler = 0;
    switch (type) {
        case 0: handler = int_handler; break;
        case 1: handler = string_handler; break;
        case 2: handler = vector_handler; break;
        default: handler = other_handler; break;
    }

    if (*cache_size < 256) {
        cache[*cache_size].key = type;
        cache[*cache_size].handler = handler;
        (*cache_size)++;
    }

    return handler();
}

double time_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main() {
    const int TOTAL_CALLS = 2000000;
    const int WARMUP = 100000;

    printf("================================\n");
    printf("C++ Dispatch Caching Micro-Benchmark\n");
    printf("================================\n");
    printf("Test data: 2,000,000 calls over repeating 4-type cycle\n\n");

    printf("Warming up (100,000 calls)...\n");
    for (int i = 0; i < WARMUP; i++) {
        dispatch_uncached(test_type(i));
    }

    struct CacheEntry cache[256];
    int cache_size = 0;
    for (int i = 0; i < WARMUP; i++) {
        dispatch_cached(test_type(i), cache, &cache_size);
    }
    printf("Warmup complete.\n\n");

    printf("=== Uncached Dispatch (3 iterations, 2M calls each) ===\n");
    double uncached_times[3];
    for (int run = 0; run < 3; run++) {
        double start = time_ns();
        for (int i = 0; i < TOTAL_CALLS; i++) {
            dispatch_uncached(test_type(i));
        }
        double elapsed_ns = time_ns() - start;
        uncached_times[run] = elapsed_ns;
        printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run + 1, elapsed_ns / 1e9, elapsed_ns / TOTAL_CALLS);
    }

    printf("\n=== Cached Dispatch (3 iterations, 2M calls each) ===\n");
    double cached_times[3];
    for (int run = 0; run < 3; run++) {
        cache_size = 0;
        double start = time_ns();
        for (int i = 0; i < TOTAL_CALLS; i++) {
            dispatch_cached(test_type(i), cache, &cache_size);
        }
        double elapsed_ns = time_ns() - start;
        cached_times[run] = elapsed_ns;
        printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run + 1, elapsed_ns / 1e9, elapsed_ns / TOTAL_CALLS);
    }

    double avg_uncached = (uncached_times[0] + uncached_times[1] + uncached_times[2]) / 3;
    double avg_cached = (cached_times[0] + cached_times[1] + cached_times[2]) / 3;
    double ratio = avg_cached / avg_uncached;

    printf("\n================================\n");
    printf("Average uncached: %.1f ns/call\n", avg_uncached / TOTAL_CALLS);
    printf("Average cached: %.1f ns/call\n", avg_cached / TOTAL_CALLS);
    printf("Slowdown ratio: %.2f×\n", ratio);
    printf("================================\n");

    return 0;
}
