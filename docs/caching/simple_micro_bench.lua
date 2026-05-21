#!/usr/bin/env lua
-- Micro-benchmark: homogeneous dispatch (Lua version)
-- All dispatches on numbers only

local CACHE_SIZE = 8

local DispatchCache = {}
DispatchCache.__index = DispatchCache

function DispatchCache:new()
    local self = setmetatable({}, DispatchCache)
    self.entries = {}
    self.next_idx = 0
    self.hits = 0
    self.misses = 0
    return self
end

function DispatchCache:lookup(key)
    for i = 1, CACHE_SIZE do
        local entry = self.entries[i]
        if entry and entry[1] == key then
            return entry[2]
        end
    end
    return nil
end

function DispatchCache:insert(key, fn)
    self.entries[self.next_idx + 1] = {key, fn}
    self.next_idx = (self.next_idx + 1) % CACHE_SIZE
end

local function clause_number(x)
    return {"number", x}
end

local homo_cache = DispatchCache:new()

local function dispatch_homo_uncached(x)
    if type(x) == "number" then
        return {"number", x}
    else
        return {"other", x}
    end
end

local function dispatch_homo_cached(x)
    local key = "number"
    local hit = homo_cache:lookup(key)

    if hit then
        homo_cache.hits = homo_cache.hits + 1
        return hit(x)
    end

    homo_cache.misses = homo_cache.misses + 1
    homo_cache:insert(key, clause_number)
    return clause_number(x)
end

-- Test data: 200,000 number-only calls
local test_data = {}
math.randomseed(42)
for i = 1, 200000 do
    table.insert(test_data, math.random(1000000))
end

local function benchmark_uncached(iterations)
    local times = {}
    for run = 1, iterations do
        local result = 0
        local start_time = os.clock()
        for _, item in ipairs(test_data) do
            local r = dispatch_homo_uncached(item)
            if r then result = result + 1 end
        end
        local elapsed = (os.clock() - start_time) * 1000.0
        print(string.format("  Run %d: %.1f seconds", run, elapsed / 1000.0))
        table.insert(times, result)
    end
    return times
end

local function benchmark_cached(iterations)
    local times = {}
    for run = 1, iterations do
        homo_cache.hits = 0
        homo_cache.misses = 0
        local result = 0
        local start_time = os.clock()
        for _, item in ipairs(test_data) do
            local r = dispatch_homo_cached(item)
            if r then result = result + 1 end
        end
        local elapsed = (os.clock() - start_time) * 1000.0
        print(string.format("  Run %d: %.1f seconds", run, elapsed / 1000.0))
        table.insert(times, result)
    end
    return times
end

local function run_all_benchmarks()
    print("\n================================")
    print("Lua Homogeneous Dispatch Caching Micro-Benchmark")
    print("================================")
    print(string.format("Implementation: Lua %s", _VERSION))
    print("Test data: 200,000 number-only calls\n")

    print("Warming up interpreter (10,000 calls)...")
    for i = 1, 10000 do
        dispatch_homo_uncached(test_data[(i % 200000) + 1])
    end
    for i = 1, 10000 do
        homo_cache.hits = 0
        homo_cache.misses = 0
        dispatch_homo_cached(test_data[(i % 200000) + 1])
    end
    print("Warmup complete.\n")

    print("=== Uncached Dispatch (3 iterations) ===")
    benchmark_uncached(3)

    print("\n=== Cached Dispatch (3 iterations) ===")
    benchmark_cached(3)

    print("\nCached Dispatch Stats:")
    local total = homo_cache.hits + homo_cache.misses
    print(string.format("  Cache hits: %d", homo_cache.hits))
    print(string.format("  Cache misses: %d", homo_cache.misses))
    if total > 0 then
        local hit_rate = 100.0 * homo_cache.hits / total
        print(string.format("  Hit rate: %.4f%%", hit_rate))
    end

    print("\n================================")
    print("Benchmark Complete")
    print("================================")
end

run_all_benchmarks()
