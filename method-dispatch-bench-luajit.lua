#!/usr/bin/env luajit

-- Micro-benchmark: generic function dispatch (LuaJIT version)
-- Using a dispatch table with type-based function selection

-- Type checking function
local function get_type(x)
    if type(x) == "number" then
        return "number"
    elseif type(x) == "string" then
        return "string"
    elseif type(x) == "table" then
        if x[1] and #x > 0 then
            return "list"
        else
            return "table"
        end
    else
        return "other"
    end
end

-- Dispatch table
local dispatch_table = {
    number = function(x) return {"number", x} end,
    string = function(x) return {"string", #x} end,
    list = function(x) return {"list", #x} end,
    table = function(x) return {"table", x} end,
    other = function(x) return {"other", x} end,
}

-- Generic dispatcher using dispatch table
local function dispatch_generic(x)
    local typ = get_type(x)
    local fn = dispatch_table[typ] or dispatch_table.other
    return fn(x)
end

-- Test data: 2,000,000 calls with 5-type repeating cycle
local cycle = {1, "test string", {1, 2, 3, 4, 5}, {a=1, b=2}}
local test_data = {}
for i = 1, 2000000 do
    test_data[i] = cycle[(i - 1) % 4 + 1]
end

-- Benchmark function
local function benchmark(iterations)
    print("Running dispatch benchmark (3 iterations):")
    for run = 1, iterations do
        local start = os.clock()
        for _, item in ipairs(test_data) do
            dispatch_generic(item)
        end
        local elapsed = os.clock() - start
        print(string.format("  Run %d: %.10f seconds", run, elapsed))
    end
end

-- Main
print("================================")
print("LuaJIT Generic Function Dispatch Micro-Benchmark")
print("================================")
print(string.format("Implementation: LuaJIT %s", jit.version))
print("Test data: 2,000,000 calls over repeating 5-type cycle")
print("  Type cycle: number -> string -> list -> table -> symbol\n")

print("Warming up JIT compiler (10,000 calls)...")
for i = 1, 10000 do
    local idx = (i - 1) % #test_data + 1
    dispatch_generic(test_data[idx])
end
print("Warmup complete.\n")

benchmark(3)

print("\n================================")
print("Benchmark Complete")
print("================================")
