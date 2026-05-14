#!/usr/bin/env luajit

-- Micro-benchmark: homogeneous dispatch (LuaJIT version)
-- All dispatches on numbers (integers) only

local cache_size = 8

-- Clause functions
local function clause_long(x)
    return {"long", x}
end

-- Uncached dispatcher (COND-style)
local function dispatch_uncached(x)
    if type(x) == "number" then
        return clause_long(x)
    else
        return {"other", x}
    end
end

-- Cached dispatcher with simple round-robin cache
local cache_entries = {}
local cache_next = 1

local function cache_lookup(key)
    for _, entry in ipairs(cache_entries) do
        if entry[1] == key then
            return entry[2]
        end
    end
    return nil
end

local function cache_insert(key, fn)
    cache_entries[cache_next] = {key, fn}
    cache_next = cache_next % cache_size + 1
end

local function dispatch_cached(x)
    local key = type(x) == "number" and "long" or "other"
    local hit = cache_lookup(key)

    if hit then
        return hit(x)
    else
        local fn = type(x) == "number" and clause_long or function(x) return {"other", x} end
        cache_insert(key, fn)
        return fn(x)
    end
end

-- Test data: 2,000,000 random numbers
local test_data = {}
math.randomseed(42)
for i = 1, 2000000 do
    test_data[i] = math.random(1000000)
end

-- Benchmark functions
local function benchmark_uncached(iterations)
    print("=== Uncached COND Dispatch (3 iterations) ===")
    for run = 1, iterations do
        local start = os.clock()
        for _, item in ipairs(test_data) do
            dispatch_uncached(item)
        end
        local elapsed = os.clock() - start
        print(string.format("  Run %d: %.10f seconds", run, elapsed))
    end
end

local function benchmark_cached(iterations)
    print("\n=== Cached Dispatch (3 iterations) ===")
    for run = 1, iterations do
        -- Clear cache
        cache_entries = {}
        cache_next = 1

        local start = os.clock()
        for _, item in ipairs(test_data) do
            dispatch_cached(item)
        end
        local elapsed = os.clock() - start
        print(string.format("  Run %d: %.10f seconds", run, elapsed))
    end
end

-- Main
print("================================")
print("LuaJIT Homogeneous Dispatch Caching Micro-Benchmark")
print("================================")
print(string.format("Implementation: LuaJIT %s", jit.version))
print("Test data: 2,000,000 number-only calls\n")

print("Warming up JIT compiler (10,000 calls)...")
for i = 1, 10000 do
    local idx = (i - 1) % #test_data + 1
    dispatch_uncached(test_data[idx])
    dispatch_cached(test_data[idx])
end
print("Warmup complete.\n")

benchmark_uncached(3)
benchmark_cached(3)

print("\n================================")
print("Benchmark Complete")
print("================================")
