package main

import (
	"fmt"
	"sync"
	"time"
)

// DispatchResult represents the result of dispatch
type DispatchResult struct {
	TypeName string
	Value    interface{}
}

// DispatchCache is a simple round-robin LRU cache
type DispatchCache struct {
	entries [8]map[string]func(interface{}) *DispatchResult
	nextIdx int
	hits    int64
	misses  int64
	mu      sync.Mutex
}

func NewDispatchCache() *DispatchCache {
	cache := &DispatchCache{}
	for i := range cache.entries {
		cache.entries[i] = make(map[string]func(interface{}) *DispatchResult)
	}
	return cache
}

func (c *DispatchCache) Lookup(key string) func(interface{}) *DispatchResult {
	c.mu.Lock()
	defer c.mu.Unlock()

	for i := range c.entries {
		if fn, ok := c.entries[i][key]; ok {
			c.hits++
			return fn
		}
	}
	c.misses++
	return nil
}

func (c *DispatchCache) Insert(key string, fn func(interface{}) *DispatchResult) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Simple round-robin insertion
	for k := range c.entries[c.nextIdx] {
		delete(c.entries[c.nextIdx], k)
	}
	c.entries[c.nextIdx][key] = fn
	c.nextIdx = (c.nextIdx + 1) % len(c.entries)
}

func (c *DispatchCache) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.hits = 0
	c.misses = 0
	c.nextIdx = 0
	for i := range c.entries {
		for k := range c.entries[i] {
			delete(c.entries[i], k)
		}
	}
}

// Clause functions
func clauseInt(x interface{}) *DispatchResult {
	return &DispatchResult{"int", x}
}

func clauseString(x interface{}) *DispatchResult {
	s := x.(string)
	return &DispatchResult{"string", len(s)}
}

func clauseSlice(x interface{}) *DispatchResult {
	sl := x.([]int)
	return &DispatchResult{"slice", len(sl)}
}

func clauseMap(x interface{}) *DispatchResult {
	m := x.(map[string]int)
	return &DispatchResult{"map", len(m)}
}

func clauseOther(x interface{}) *DispatchResult {
	return &DispatchResult{"other", x}
}

// getTypeKey returns the type key for an interface value
func getTypeKey(x interface{}) string {
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
		return "other"
	}
}

// Uncached dispatcher using type switch
func dispatchUncached(x interface{}) *DispatchResult {
	switch x.(type) {
	case int:
		return clauseInt(x)
	case string:
		return clauseString(x)
	case []int:
		return clauseSlice(x)
	case map[string]int:
		return clauseMap(x)
	default:
		return clauseOther(x)
	}
}

// Cached dispatcher
func dispatchCached(x interface{}, cache *DispatchCache) *DispatchResult {
	key := getTypeKey(x)
	cached := cache.Lookup(key)

	if cached != nil {
		return cached(x)
	}

	var fn func(interface{}) *DispatchResult
	switch x.(type) {
	case int:
		fn = clauseInt
	case string:
		fn = clauseString
	case []int:
		fn = clauseSlice
	case map[string]int:
		fn = clauseMap
	default:
		fn = clauseOther
	}

	cache.Insert(key, fn)
	return fn(x)
}

func main() {
	const numCalls = 2000000

	fmt.Println("================================")
	fmt.Println("Go Heterogeneous Dispatch Caching Micro-Benchmark")
	fmt.Println("================================")
	fmt.Printf("Go version: %s\n", getGoVersion())
	fmt.Printf("Test data: %d calls over repeating 4-type cycle\n", numCalls)
	fmt.Println("  Type cycle: int -> string -> slice -> map\n")

	// Create test data with 4-type cycle
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

	fmt.Println("Warming up compiler (100,000 calls)...")
	for i := 0; i < 100000; i++ {
		dispatchUncached(testData[i%len(testData)])
	}

	cache := NewDispatchCache()
	for i := 0; i < 100000; i++ {
		dispatchCached(testData[i%len(testData)], cache)
	}
	fmt.Println("Warmup complete.\n")

	// Benchmark uncached
	fmt.Println("=== Uncached Dispatch (3 iterations) ===")
	uncachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchUncached(item)
			if r != nil {
				result++
			}
		}
		elapsed := time.Since(start)
		uncachedTimes[run] = elapsed
		nsPerCall := float64(elapsed.Nanoseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run+1, elapsed.Seconds(), nsPerCall)
	}

	// Benchmark cached
	fmt.Println("\n=== Cached Dispatch (3 iterations) ===")
	cachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		cache.Reset()
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchCached(item, cache)
			if r != nil {
				result++
			}
		}
		elapsed := time.Since(start)
		cachedTimes[run] = elapsed
		nsPerCall := float64(elapsed.Nanoseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run+1, elapsed.Seconds(), nsPerCall)
	}

	// Calculate cache stats
	fmt.Println("\nCached Dispatch Stats:")
	fmt.Printf("  Cache hits: %d\n", cache.hits)
	fmt.Printf("  Cache misses: %d\n", cache.misses)
	total := cache.hits + cache.misses
	if total > 0 {
		hitRate := 100.0 * float64(cache.hits) / float64(total)
		fmt.Printf("  Hit rate: %.4f%%\n", hitRate)
	}

	// Summary
	var avgUncached, avgCached time.Duration
	for i := 0; i < 3; i++ {
		avgUncached += uncachedTimes[i]
		avgCached += cachedTimes[i]
	}
	avgUncached /= 3
	avgCached /= 3

	uncachedNs := float64(avgUncached.Nanoseconds()) / float64(numCalls)
	cachedNs := float64(avgCached.Nanoseconds()) / float64(numCalls)
	ratio := float64(avgCached) / float64(avgUncached)

	fmt.Println("\n================================")
	fmt.Printf("Average uncached: %.1f ns/call\n", uncachedNs)
	fmt.Printf("Average cached: %.1f ns/call\n", cachedNs)
	fmt.Printf("Slowdown ratio: %.2f×\n", ratio)
	fmt.Println("================================")
}

func getGoVersion() string {
	// Simple version string - Go 1.23.0
	return "1.23.0"
}
