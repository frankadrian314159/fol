#include <chrono>
#include <iostream>
#include <unordered_map>
#include <functional>
#include <vector>
#include <cstdint>

enum class TestType : int {
    Int = 0,
    String = 1,
    Vector = 2,
    Other = 3
};

struct EnumHash {
    size_t operator()(TestType e) const {
        return std::hash<int>()(static_cast<int>(e));
    }
};

TestType get_type(int cycle_index) {
    return static_cast<TestType>(cycle_index % 4);
}

struct DispatchResult {
    const char* type_name;
    int size;
};

DispatchResult dispatch_uncached(TestType type) {
    switch (type) {
        case TestType::Int: return {"int", 42};
        case TestType::String: return {"string", 11};
        case TestType::Vector: return {"vector", 5};
        case TestType::Other: return {"other", 0};
        default: return {"error", 0};
    }
}

typedef DispatchResult (*DispatchHandler)();

DispatchResult int_handler() { return {"int", 42}; }
DispatchResult string_handler() { return {"string", 11}; }
DispatchResult vector_handler() { return {"vector", 5}; }
DispatchResult other_handler() { return {"other", 0}; }

DispatchResult dispatch_cached(TestType type, std::unordered_map<TestType, DispatchHandler, EnumHash>& cache) {
    auto it = cache.find(type);
    if (it != cache.end()) {
        return it->second();
    }

    DispatchHandler handler = nullptr;
    switch (type) {
        case TestType::Int: handler = int_handler; break;
        case TestType::String: handler = string_handler; break;
        case TestType::Vector: handler = vector_handler; break;
        case TestType::Other: handler = other_handler; break;
    }

    if (handler) {
        cache[type] = handler;
        return handler();
    }
    return {"error", 0};
}

int main() {
    const int TOTAL_CALLS = 2_000_000;
    const int CYCLE_SIZE = 4;
    const int WARMUP = 100_000;

    std::vector<TestType> test_data;
    test_data.reserve(TOTAL_CALLS);
    for (int i = 0; i < TOTAL_CALLS; ++i) {
        test_data.push_back(get_type(i));
    }

    std::cout << "================================\n";
    std::cout << "C++ Dispatch Caching Micro-Benchmark\n";
    std::cout << "================================\n";
    std::cout << "Test data: 2,000,000 calls over repeating 4-type cycle\n\n";

    // Warmup
    std::cout << "Warming up (100,000 calls)...\n";
    for (int i = 0; i < WARMUP; ++i) {
        auto _ = dispatch_uncached(test_data[i % test_data.size()]);
        (void)_;
    }

    std::unordered_map<TestType, DispatchHandler, EnumHash> cache;
    for (int i = 0; i < WARMUP; ++i) {
        auto _ = dispatch_cached(test_data[i % test_data.size()], cache);
        (void)_;
    }
    std::cout << "Warmup complete.\n\n";

    // Benchmark uncached
    std::cout << "=== Uncached Dispatch (3 iterations, 2M calls each) ===\n";
    std::vector<double> uncached_times;
    for (int run = 1; run <= 3; ++run) {
        auto start = std::chrono::high_resolution_clock::now();
        for (const auto& item : test_data) {
            auto _ = dispatch_uncached(item);
            (void)_;
        }
        auto end = std::chrono::high_resolution_clock::now();
        double elapsed_ns = std::chrono::duration<double, std::nano>(end - start).count();
        uncached_times.push_back(elapsed_ns);
        double ns_per_call = elapsed_ns / TOTAL_CALLS;
        printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run, elapsed_ns / 1e9, ns_per_call);
    }

    // Benchmark cached
    std::cout << "\n=== Cached Dispatch (3 iterations, 2M calls each) ===\n";
    std::vector<double> cached_times;
    for (int run = 1; run <= 3; ++run) {
        cache.clear();
        auto start = std::chrono::high_resolution_clock::now();
        for (const auto& item : test_data) {
            auto _ = dispatch_cached(item, cache);
            (void)_;
        }
        auto end = std::chrono::high_resolution_clock::now();
        double elapsed_ns = std::chrono::duration<double, std::nano>(end - start).count();
        cached_times.push_back(elapsed_ns);
        double ns_per_call = elapsed_ns / TOTAL_CALLS;
        printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run, elapsed_ns / 1e9, ns_per_call);
    }

    // Summary
    double avg_uncached = 0, avg_cached = 0;
    for (auto t : uncached_times) avg_uncached += t;
    for (auto t : cached_times) avg_cached += t;
    avg_uncached /= uncached_times.size();
    avg_cached /= cached_times.size();

    double ratio = avg_cached / avg_uncached;
    double avg_uncached_ns_per_call = avg_uncached / TOTAL_CALLS;
    double avg_cached_ns_per_call = avg_cached / TOTAL_CALLS;

    std::cout << "\n================================\n";
    printf("Average uncached: %.1f ns/call\n", avg_uncached_ns_per_call);
    printf("Average cached: %.1f ns/call\n", avg_cached_ns_per_call);
    printf("Slowdown ratio: %.2f×\n", ratio);
    std::cout << "================================\n";

    return 0;
}
