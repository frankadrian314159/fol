#!/usr/bin/env luajit

-- Micro-benchmark: heterogeneous dispatch (LuaJIT version)
-- Compares dispatch caching across type cycles

local cache_size = 8

-- Type checking function
local function get_type(x)
    if type(x) == "number" then
        return "number"
    elseif type(x) == "string" then
        return "string"
    elseif type(x) == "table" then
        -- Check if it's a list or other table
        if x[1] and #x > 0 then
            return "list"
        else
            return "table"
        end
    else
        return "other"
    end
end

-- Clause functions
local function clause_number(x)
    return {"number", x}
end

local function clause_string(x)
    return {"string", #x}
end

local function clause_list(x)
    return {"list", #x}
end

local function clause_table(x)
    return {"table", x}
end

local function clause_other(x)
    return {"other", x}
end

-- Uncached dispatcher
local function dispatch_uncached(x)
    local typ = get_type(x)
    if typ == "number" then
        return clause_number(x)
    elseif typ == "string" then
        return clause_string(x)
    elseif typ == "list" then
        return clause_list(x)
    elseif typ == "table" then
        return clause_table(x)
    else
        return clause_other(x)
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
    -- Round-robin insertion
    cache_entries[cache_next] = {key, fn}
    cache_next = cache_next % cache_size + 1
end

local function dispatch_cached(x)
    local typ = get_type(x)
    local hit = cache_lookup(typ)

    if hit then
        return hit(x)
    else
        local fn
        if typ == "number" then
            fn = clause_number
        elseif typ == "string" then
            fn = clause_string
        elseif typ == "list" then
            fn = clause_list
        elseif typ == "table" then
            fn = clause_table
        else
            fn = clause_other
        end
        cache_insert(typ, fn)
        return fn(x)
    end
end

-- Test data: 2,000,000 calls with 5-type repeating cycle
local cycle = {1, "test string", {1, 2, 3, 4, 5}, {a=1, b=2}}
local test_data = {}
for i = 1, 2000000 do
    test_data[i] = cycle[(i - 1) % 4 + 1]
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
print("LuaJIT Heterogeneous Dispatch Caching Micro-Benchmark")
print("================================")
print(string.format("Implementation: LuaJIT %s", jit.version))
print("Test data: 2,000,000 calls over repeating 5-type cycle")
print("  Type cycle: number -> string -> list -> table -> symbol\n")

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
