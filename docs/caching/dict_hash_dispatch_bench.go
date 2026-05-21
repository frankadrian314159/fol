package main

import (
	"fmt"
	"time"
)

// Dictionary/Hash dispatch: lookup dispatcher by key
// Common in scripting languages (Lua, JavaScript, Python)
// Direct table lookup vs. caching that lookup

// Dispatcher table: map of type -> handler
type DispatchTable struct {
	handlers map[string]func(interface{}) string
}

func NewDispatchTable() *DispatchTable {
	return &DispatchTable{
		handlers: make(map[string]func(interface{}) string),
	}
}

func (dt *DispatchTable) Register(typeKey string, handler func(interface{}) string) {
	dt.handlers[typeKey] = handler
}

func (dt *DispatchTable) Dispatch(x interface{}, key string) string {
	if handler, ok := dt.handlers[key]; ok {
		return handler(x)
	}
	return "unknown"
}

// Handlers
func handleDictInt(x interface{}) string {
	return "int"
}

func handleDictString(x interface{}) string {
	return "string"
}

func handleDictSlice(x interface{}) string {
	return "slice"
}

func handleDictMap(x interface{}) string {
	return "map"
}

// Get type key for dispatch table lookup
func getTypeKeyForDict(x interface{}) string {
	switch x.(type) {
	case int:
		return "int"
	case string:
		return "string"
	case []int:
		return "slice"
	case map[string]int:
		return "map"
	default:
		return "unknown"
	}
}

// Direct hash dispatch: single lookup in handler table
// This is the baseline for dictionary/hash dispatch
func dispatchDictDirect(x interface{}, dt *DispatchTable) string {
	key := getTypeKeyForDict(x)
	return dt.Dispatch(x, key)
}

// Two-level hash dispatch: cache the lookups
// Simulates caching dispatch decisions
type DispatchDecisionCache struct {
	cache map[string]func(interface{}) string
}

func NewDispatchDecisionCache() *DispatchDecisionCache {
	return &DispatchDecisionCache{
		cache: make(map[string]func(interface{}) string),
	}
}

func (ddc *DispatchDecisionCache) GetOrCompute(key string, dt *DispatchTable) func(interface{}) string {
	if cached, ok := ddc.cache[key]; ok {
		return cached
	}
	if handler, ok := dt.handlers[key]; ok {
		ddc.cache[key] = handler
		return handler
	}
	ddc.cache[key] = func(interface{}) string { return "unknown" }
	return ddc.cache[key]
}

func dispatchDictCached(x interface{}, dt *DispatchTable, cache *DispatchDecisionCache) string {
	key := getTypeKeyForDict(x)
	handler := cache.GetOrCompute(key, dt)
	return handler(x)
}

func main() {
	const numCalls = 2000000

	fmt.Println("================================")
	fmt.Println("Go Dictionary/Hash Dispatch Benchmark")
	fmt.Println("================================")
	fmt.Printf("Go version: 1.23.0\n")
	fmt.Printf("Test data: %d calls over repeating 4-type cycle\n", numCalls)
	fmt.Println("  Type cycle: int -> string -> slice -> map")
	fmt.Println("  Dispatch: DICTIONARY/HASH BASED (scripting language style)")
	fmt.Println("  Direct: Single hash table lookup")
	fmt.Println("  Cached: Cache of cached lookups (meta-caching)\n")

	// Create test data
	testData := make([]interface{}, numCalls)
	for i := 0; i < numCalls; i++ {
		switch i % 4 {
		case 0:
			testData[i] = 42
		case 1:
			testData[i] = "test string"
		case 2:
			testData[i] = []int{1, 2, 3, 4, 5}
		case 3:
			testData[i] = map[string]int{"a": 1, "b": 2}
		}
	}

	// Create dispatch table
	dt := NewDispatchTable()
	dt.Register("int", handleDictInt)
	dt.Register("string", handleDictString)
	dt.Register("slice", handleDictSlice)
	dt.Register("map", handleDictMap)

	fmt.Println("Warming up compiler (100,000 calls)...")
	for i := 0; i < 100000; i++ {
		dispatchDictDirect(testData[i%len(testData)], dt)
	}

	cache := NewDispatchDecisionCache()
	for i := 0; i < 100000; i++ {
		dispatchDictCached(testData[i%len(testData)], dt, cache)
	}
	fmt.Println("Warmup complete.\n")

	// Benchmark direct hash dispatch
	fmt.Println("=== Direct Hash Dispatch (3 iterations) ===")
	directTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchDictDirect(item, dt)
			if r != "" {
				result++
			}
		}
		elapsed := time.Since(start)
		directTimes[run] = elapsed
		nsPerCall := float64(elapsed.Nanoseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run+1, elapsed.Seconds(), nsPerCall)
	}

	// Benchmark cached hash dispatch
	fmt.Println("\n=== Cached Hash Dispatch (3 iterations) ===")
	cachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		cache = NewDispatchDecisionCache()
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchDictCached(item, dt, cache)
			if r != "" {
				result++
			}
		}
		elapsed := time.Since(start)
		cachedTimes[run] = elapsed
		nsPerCall := float64(elapsed.Nanoseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run+1, elapsed.Seconds(), nsPerCall)
	}

	// Summary
	var avgDirect, avgCached time.Duration
	for i := 0; i < 3; i++ {
		avgDirect += directTimes[i]
		avgCached += cachedTimes[i]
	}
	avgDirect /= 3
	avgCached /= 3

	directNs := float64(avgDirect.Nanoseconds()) / float64(numCalls)
	cachedNs := float64(avgCached.Nanoseconds()) / float64(numCalls)
	ratio := float64(avgCached) / float64(avgDirect)

	fmt.Println("\n================================")
	fmt.Printf("Average direct: %.1f ns/call\n", directNs)
	fmt.Printf("Average cached: %.1f ns/call\n", cachedNs)
	fmt.Printf("Slowdown ratio: %.2f×\n", ratio)
	fmt.Println("\nKey Finding: Hash dispatch already IS a form of caching.")
	fmt.Println("Caching hash dispatch means caching the cached lookup.")
	fmt.Println("Does meta-caching help or hurt?")
	fmt.Println("================================")
}
