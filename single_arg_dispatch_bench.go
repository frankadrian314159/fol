package main

import (
	"fmt"
	"sync"
	"time"
)

// Single-argument dispatch: simplest and most common case
// Tests dispatch based on only one argument type

type SingleArgCache struct {
	entries [8]map[string]func(interface{}) string
	nextIdx int
	hits    int64
	misses  int64
	mu      sync.Mutex
}

func NewSingleArgCache() *SingleArgCache {
	cache := &SingleArgCache{}
	for i := range cache.entries {
		cache.entries[i] = make(map[string]func(interface{}) string)
	}
	return cache
}

func (c *SingleArgCache) Lookup(key string) func(interface{}) string {
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

func (c *SingleArgCache) Insert(key string, fn func(interface{}) string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	for k := range c.entries[c.nextIdx] {
		delete(c.entries[c.nextIdx], k)
	}
	c.entries[c.nextIdx][key] = fn
	c.nextIdx = (c.nextIdx + 1) % len(c.entries)
}

func (c *SingleArgCache) Reset() {
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

// Clause functions for single-argument dispatch
func handleInt(x interface{}) string {
	return "int"
}

func handleString(x interface{}) string {
	return "string"
}

func handleSlice(x interface{}) string {
	return "slice"
}

func handleMap(x interface{}) string {
	return "map"
}

func handleOther(x interface{}) string {
	return "other"
}

// Uncached single-argument dispatch: type switch
func dispatchSingleArgUncached(x interface{}) string {
	switch x.(type) {
	case int:
		return handleInt(x)
	case string:
		return handleString(x)
	case []int:
		return handleSlice(x)
	case map[string]int:
		return handleMap(x)
	default:
		return handleOther(x)
	}
}

// Cached single-argument dispatch
func dispatchSingleArgCached(x interface{}, cache *SingleArgCache) string {
	key := getTypeKeyForArg(x)
	cached := cache.Lookup(key)

	if cached != nil {
		return cached(x)
	}

	var fn func(interface{}) string
	switch x.(type) {
	case int:
		fn = handleInt
	case string:
		fn = handleString
	case []int:
		fn = handleSlice
	case map[string]int:
		fn = handleMap
	default:
		fn = handleOther
	}

	cache.Insert(key, fn)
	return fn(x)
}

func getTypeKeyForArg(x interface{}) string {
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

func main() {
	const numCalls = 2000000

	fmt.Println("================================")
	fmt.Println("Go Single-Argument Dispatch Caching Benchmark")
	fmt.Println("================================")
	fmt.Printf("Go version: 1.23.0\n")
	fmt.Printf("Test data: %d calls over repeating 4-type cycle\n", numCalls)
	fmt.Println("  Type cycle: int -> string -> slice -> map")
	fmt.Println("  Dispatch: SINGLE ARGUMENT (vs. multi-argument in original)\n")

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
		dispatchSingleArgUncached(testData[i%len(testData)])
	}

	cache := NewSingleArgCache()
	for i := 0; i < 100000; i++ {
		dispatchSingleArgCached(testData[i%len(testData)], cache)
	}
	fmt.Println("Warmup complete.\n")

	// Benchmark uncached
	fmt.Println("=== Uncached Single-Argument Dispatch (3 iterations) ===")
	uncachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchSingleArgUncached(item)
			if r != "" {
				result++
			}
		}
		elapsed := time.Since(start)
		uncachedTimes[run] = elapsed
		nsPerCall := float64(elapsed.Nanoseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.1f ns/call)\n", run+1, elapsed.Seconds(), nsPerCall)
	}

	// Benchmark cached
	fmt.Println("\n=== Cached Single-Argument Dispatch (3 iterations) ===")
	cachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		cache.Reset()
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchSingleArgCached(item, cache)
			if r != "" {
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
	fmt.Println("\nKey Finding: Single-argument dispatch is simpler than multi-argument.")
	fmt.Println("Does caching overhead scale down with simpler dispatch?")
	fmt.Println("================================")
}
