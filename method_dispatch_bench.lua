#!/usr/bin/env lua
-- Micro-benchmark: generic function dispatch (Lua version)
-- Basic dispatch performance test using a dispatch table

-- Dispatch table
local dispatch_table = {
    ["number"] = function(x) return {"number", x} end,
    ["string"] = function(x) return {"string", #x} end,
    ["table"] = function(x) return {"table", #x} end,
    ["boolean"] = function(x) return {"boolean", x} end,
    ["other"] = function(x) return {"other", x} end,
}

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

local function dispatch_generic(x)
    local key = get_type_key(x)
    return dispatch_table[key](x)
end

-- Test data: 200,000 calls with 5-type repeating cycle
local test_data = {}
local cycle = {1, "test string", {1, 2, 3, 4, 5}, true, "symbol"}
for i = 1, 200000 do
    table.insert(test_data, cycle[((i - 1) % 5) + 1])
end

local function benchmark_dispatch(iterations)
    local times = {}
    for run = 1, iterations do
        local result = 0
        local start_time = os.clock()
        for _, item in ipairs(test_data) do
            local r = dispatch_generic(item)
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
    print("Lua Generic Function Dispatch Micro-Benchmark")
    print("================================")
    print(string.format("Implementation: Lua %s", _VERSION))
    print("Test data: 200,000 calls over repeating 5-type cycle")
    print("  Type cycle: number -> string -> table -> boolean -> other\n")

    print("Warming up interpreter (10,000 calls)...")
    for i = 1, 10000 do
        dispatch_generic(test_data[(i % 200000) + 1])
    end
    print("Warmup complete.\n")

    print("Running dispatch benchmark (3 iterations):")
    benchmark_dispatch(3)

    print("\n================================")
    print("Benchmark Complete")
    print("================================")
end

run_all_benchmarks()
