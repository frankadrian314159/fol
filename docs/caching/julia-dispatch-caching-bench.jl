#!/usr/bin/env julia
"""
Julia Dispatch Caching Benchmark

Tests single-argument type dispatch performance.
Compares:
1. Direct native multiple dispatch (Julia's native)
2. Manual hash-table based caching
"""

# Cache implementation
mutable struct DispatchCache
    entries::Vector{Union{Nothing, Tuple{Any, Function}}}
    next_idx::Int
    hits::Int
    misses::Int

    DispatchCache(size=8) = new(
        [nothing for _ in 1:size],
        1,
        0,
        0
    )
end

function lookup(cache::DispatchCache, key::Any)
    for entry in cache.entries
        if entry !== nothing && entry[1] == key
            cache.hits += 1
            return entry[2]
        end
    end
    cache.misses += 1
    return nothing
end

function insert!(cache::DispatchCache, key::Any, fn::Function)
    cache.entries[cache.next_idx] = (key, fn)
    cache.next_idx = mod(cache.next_idx, length(cache.entries)) + 1
end

function reset!(cache::DispatchCache)
    cache.entries = [nothing for _ in 1:length(cache.entries)]
    cache.next_idx = 1
    cache.hits = 0
    cache.misses = 0
end

# Clause functions
clause_int(x::Int) = ["int", x]
clause_string(x::String) = ["string", length(x)]
clause_vector(x::Vector) = ["vector", length(x)]
clause_dict(x::Dict) = ["dict", length(x)]
clause_other(x) = ["other", string(x)]

# Dispatch via type checking
function get_dispatch_fn(x::Any)
    if x isa Int
        return clause_int
    elseif x isa String
        return clause_string
    elseif x isa Vector
        return clause_vector
    elseif x isa Dict
        return clause_dict
    else
        return clause_other
    end
end

function dispatch_uncached(x::Any)
    fn = get_dispatch_fn(x)
    return fn(x)
end

function dispatch_cached(x::Any, cache::DispatchCache)
    type_key = typeof(x)
    cached_fn = lookup(cache, type_key)

    if cached_fn !== nothing
        return cached_fn(x)
    end

    fn = get_dispatch_fn(x)
    insert!(cache, type_key, fn)
    return fn(x)
end

function run_benchmark()
    # Test data: 4-type repeating cycle
    test_cycle = Any[
        42,
        "test string",
        [1, 2, 3, 4, 5],
        Dict("a" => 1)
    ]

    test_data = repeat(test_cycle, 2000000 ÷ length(test_cycle))

    println("================================")
    println("Julia Dispatch Caching Micro-Benchmark")
    println("================================")
    println("Test data: 2,000,000 calls over repeating 4-type cycle\n")

    # Warmup
    println("Warming up (100,000 calls)...")
    for i in 1:100000
        dispatch_uncached(test_data[mod(i-1, length(test_data)) + 1])
    end

    cache = DispatchCache()
    for i in 1:100000
        dispatch_cached(test_data[mod(i-1, length(test_data)) + 1], cache)
    end
    println("Warmup complete.\n")

    # Benchmark uncached
    println("=== Uncached Dispatch (3 iterations, 2M calls each) ===")
    uncached_times = []
    for run in 1:3
        start_time = time_ns()
        for item in test_data
            dispatch_uncached(item)
        end
        elapsed_ns = time_ns() - start_time
        push!(uncached_times, elapsed_ns)
        elapsed_s = elapsed_ns / 1e9
        ns_per_call = elapsed_ns / length(test_data)
        println("  Run $run: $(round(elapsed_s; digits=4)) seconds ($(round(ns_per_call; digits=1)) ns/call)")
    end

    # Benchmark cached
    println("\n=== Cached Dispatch (3 iterations, 2M calls each) ===")
    cached_times = []
    for run in 1:3
        reset!(cache)
        start_time = time_ns()
        for item in test_data
            dispatch_cached(item, cache)
        end
        elapsed_ns = time_ns() - start_time
        push!(cached_times, elapsed_ns)
        elapsed_s = elapsed_ns / 1e9
        ns_per_call = elapsed_ns / length(test_data)
        println("  Run $run: $(round(elapsed_s; digits=4)) seconds ($(round(ns_per_call; digits=1)) ns/call)")
    end

    # Summary stats
    println("\nCached Dispatch Stats:")
    total_hits = 0
    total_misses = 0
    for i in 1:100
        reset!(cache)
        for item in test_data
            dispatch_cached(item, cache)
        end
        total_hits += cache.hits
        total_misses += cache.misses
    end

    hit_rate = 100.0 * total_hits / (total_hits + total_misses)
    println("  Total hits: $total_hits")
    println("  Total misses: $total_misses")
    println("  Hit rate: $(round(hit_rate; digits=4))%")

    # Calculate ratios
    avg_uncached = sum(uncached_times) / length(uncached_times)
    avg_cached = sum(cached_times) / length(cached_times)
    ratio = avg_cached / avg_uncached

    avg_uncached_ns_per_call = avg_uncached / length(test_data)
    avg_cached_ns_per_call = avg_cached / length(test_data)

    println("\n================================")
    println("Average uncached: $(round(avg_uncached_ns_per_call; digits=1)) ns/call")
    println("Average cached: $(round(avg_cached_ns_per_call; digits=1)) ns/call")
    println("Slowdown ratio: $(round(ratio; digits=2))×")
    println("================================")
end

run_benchmark()
