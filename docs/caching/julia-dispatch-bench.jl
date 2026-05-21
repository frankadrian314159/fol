#!/usr/bin/env julia
"""
Julia Dispatch Caching Benchmark

Tests single-argument type dispatch performance.
Compares:
1. Direct dispatch via multiple dispatch (Julia's native)
2. Cached dispatch via a manual cache dictionary
"""

using BenchmarkTools
using Statistics

# ============================================================================
# Test 1: Native Julia Multiple Dispatch (no caching)
# ============================================================================

abstract type MyType end
struct IntType <: MyType
    value::Int64
end
struct StringType <: MyType
    value::String
end
struct FloatType <: MyType
    value::Float64
end
struct BoolType <: MyType
    value::Bool
end
struct VectorType <: MyType
    value::Vector{Int64}
end

function dispatch_native(x::IntType)
    return x.value + 1
end

function dispatch_native(x::StringType)
    return length(x.value)
end

function dispatch_native(x::FloatType)
    return x.value * 2.0
end

function dispatch_native(x::BoolType)
    return x.value ? 1 : 0
end

function dispatch_native(x::VectorType)
    return sum(x.value)
end

# ============================================================================
# Test 2: Manual Dictionary-Based Cache
# ============================================================================

const dispatch_cache = Dict{DataType, Function}()

function cache_insert(typ::DataType, f::Function)
    dispatch_cache[typ] = f
end

function cache_lookup(x::MyType)
    typ = typeof(x)
    if haskey(dispatch_cache, typ)
        return dispatch_cache[typ](x)
    else
        # Fallback to dynamic dispatch
        return dispatch_native(x)
    end
end

function setup_cache()
    cache_insert(IntType, x -> x.value + 1)
    cache_insert(StringType, x -> length(x.value))
    cache_insert(FloatType, x -> x.value * 2.0)
    cache_insert(BoolType, x -> x.value ? 1 : 0)
    cache_insert(VectorType, x -> sum(x.value))
end

# ============================================================================
# Benchmark Suite
# ============================================================================

function run_benchmarks()
    println("Julia Dispatch Caching Benchmark")
    println("=" ^ 60)

    # Create test data
    test_data = MyType[
        IntType(42),
        StringType("hello"),
        FloatType(3.14),
        BoolType(true),
        VectorType([1, 2, 3, 4, 5])
    ]

    # Extend test data for longer benchmarks
    test_data_extended = repeat(test_data, 400000 ÷ 5)  # 400K items

    println("\nTest 1: Native Julia Multiple Dispatch (Uncached)")
    println("-" ^ 60)

    t_native = @benchmark begin
        for x in $test_data_extended
            dispatch_native(x)
        end
    end seconds=2

    time_native_ms = minimum(t_native.times) / 1e6
    println("Time: $(round(time_native_ms, digits=2)) ms")
    println("Per-call: $(round(time_native_ms * 1e3 / length(test_data_extended), digits=3)) µs")

    println("\nTest 2: Dictionary Cache-Based Dispatch (Cached)")
    println("-" ^ 60)

    setup_cache()

    t_cached = @benchmark begin
        for x in $test_data_extended
            cache_lookup(x)
        end
    end seconds=2

    time_cached_ms = minimum(t_cached.times) / 1e6
    println("Time: $(round(time_cached_ms, digits=2)) ms")
    println("Per-call: $(round(time_cached_ms * 1e3 / length(test_data_extended), digits=3)) µs")

    println("\nResults Summary")
    println("=" ^ 60)
    ratio = time_cached_ms / time_native_ms
    if ratio > 1.0
        println("Slowdown: $(round(ratio, digits=2))×")
    else
        println("Speedup: $(round(1/ratio, digits=2))×")
    end

    println("\nConclusion:")
    if ratio > 1.02
        println("Dictionary caching is SLOWER ($(round((ratio-1)*100, digits=1))% slowdown)")
    elseif ratio < 0.98
        println("Dictionary caching is FASTER ($(round((1-ratio)*100, digits=1))% speedup)")
    else
        println("Dictionary caching is NEUTRAL (within 2%)")
    end
end

# Run the benchmarks
if abspath(PROGRAM_FILE) == @__FILE__
    run_benchmarks()
end
