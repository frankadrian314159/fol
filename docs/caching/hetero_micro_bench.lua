#!/usr/bin/env lua
-- Micro-benchmark: heterogeneous dispatch (Lua version)
-- Compares dispatch caching across Lisp/Scheme implementations

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

local function clause_string(x)
    return {"string", #x}
end

local function clause_table(x)
    return {"table", #x}
end

local function clause_boolean(x)
    return {"boolean", x}
end

local function clause_other(x)
    return {"other", x}
end

local hetero_cache = DispatchCache:new()

local function get_type_key(x)
    local t = type(x)
    if t == "number" then
        return "number"
    elseif t == "string" then
        return "string"
    elseif t == "table" then
        return "table"
    elseif t == "boolean" then
        return "boolean"
    else
        return "other"
    end
end

local function dispatch_hetero_uncached(x)
    local t = type(x)
    if t == "number" then
        return {"number", x}
    elseif t == "string" then
        return {"string", #x}
    elseif t == "table" then
        return {"table", #x}
    elseif t == "boolean" then
        return {"boolean", x}
    else
        return {"other", x}
    end
end

local function dispatch_hetero_cached(x)
    local key = get_type_key(x)
    local hit = hetero_cache:lookup(key)

    if hit then
        hetero_cache.hits = hetero_cache.hits + 1
        return hit(x)
    end

    hetero_cache.misses = hetero_cache.misses + 1
    local t = type(x)
    if t == "number" then
        hetero_cache:insert(key, clause_number)
        return clause_number(x)
    elseif t == "string" then
        hetero_cache:insert(key, clause_string)
        return clause_string(x)
    elseif t == "table" then
        hetero_cache:insert(key, clause_table)
        return clause_table(x)
    elseif t == "boolean" then
        hetero_cache:insert(key, clause_boolean)
        return clause_boolean(x)
    else
        hetero_cache:insert(key, clause_other)
        return clause_other(x)
    end
end

-- Test data: 200,000 calls with 5-type repeating cycle
local test_data = {}
local cycle = {1, "test string", {1, 2, 3, 4, 5}, true, "symbol"}
for i = 1, 200000 do
    table.insert(test_data, cycle[((i - 1) % 5) + 1])
end

local function benchmark_uncached(iterations)
    local times = {}
    for run = 1, iterations do
        local result = 0
        local start_time = os.clock()
        for _, item in ipairs(test_data) do
            local r = dispatch_hetero_uncached(item)
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
        hetero_cache.hits = 0
        hetero_cache.misses = 0
        local result = 0
        local start_time = os.clock()
        for _, item in ipairs(test_data) do
            local r = dispatch_hetero_cached(item)
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
    print("Lua Heterogeneous Dispatch Caching Micro-Benchmark")
    print("================================")
    print(string.format("Implementation: Lua %s", _VERSION))
    print("Test data: 200,000 calls over repeating 5-type cycle")
    print("  Type cycle: number -> string -> table -> boolean -> other\n")

    print("Warming up interpreter (10,000 calls)...")
    for i = 1, 10000 do
        dispatch_hetero_uncached(test_data[(i % 200000) + 1])
    end
    for i = 1, 10000 do
        hetero_cache.hits = 0
        hetero_cache.misses = 0
        dispatch_hetero_cached(test_data[(i % 200000) + 1])
    end
    print("Warmup complete.\n")

    print("=== Uncached Dispatch (3 iterations) ===")
    benchmark_uncached(3)

    print("\n=== Cached Dispatch (3 iterations) ===")
    benchmark_cached(3)

    print("\nCached Dispatch Stats:")
    local total = hetero_cache.hits + hetero_cache.misses
    print(string.format("  Cache hits: %d", hetero_cache.hits))
    print(string.format("  Cache misses: %d", hetero_cache.misses))
    if total > 0 then
        local hit_rate = 100.0 * hetero_cache.hits / total
        print(string.format("  Hit rate: %.4f%%", hit_rate))
    end

    print("\n================================")
    print("Benchmark Complete")
    print("================================")
end

run_all_benchmarks()
