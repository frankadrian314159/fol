package main

import (
	"fmt"
	"sync"
	"time"
)

// Generic function dispatch: beyond CLOS-style multi-methods
// Tests dispatch based on multiple argument types in a function registry
// Different from type-switch: uses a function registry with dispatch logic

type GenericFunc struct {
	implementations []GenericMethod
	name            string
}

type GenericMethod struct {
	// Dispatch predicate: checks if this method handles these arguments
	predicate func(interface{}, interface{}) bool
	handler   func(interface{}, interface{}) string
}

type GenericFuncCache struct {
	entries [8]map[string]func(interface{}, interface{}) string
	nextIdx int
	hits    int64
	misses  int64
	mu      sync.Mutex
}

func NewGenericFuncCache() *GenericFuncCache {
	cache := &GenericFuncCache{}
	for i := range cache.entries {
		cache.entries[i] = make(map[string]func(interface{}, interface{}) string)
	}
	return cache
}

func (c *GenericFuncCache) Lookup(key string) func(interface{}, interface{}) string {
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

func (c *GenericFuncCache) Insert(key string, fn func(interface{}, interface{}) string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	for k := range c.entries[c.nextIdx] {
		delete(c.entries[c.nextIdx], k)
	}
	c.entries[c.nextIdx][key] = fn
	c.nextIdx = (c.nextIdx + 1) % len(c.entries)
}

func (c *GenericFuncCache) Reset() {
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

// Generic handlers for different type combinations
func handleIntString(x interface{}, y interface{}) string {
	return "int-string"
}

func handleStringInt(x interface{}, y interface{}) string {
	return "string-int"
}

func handleIntInt(x interface{}, y interface{}) string {
	return "int-int"
}

func handleStringString(x interface{}, y interface{}) string {
	return "string-string"
}

// Type key for two arguments
func getTypeKeyForGeneric(x interface{}, y interface{}) string {
	key1 := getTypeKeyForArg(x)
	key2 := getTypeKeyForArg(y)
	return key1 + "-" + key2
}

func getTypeKeyForArg(x interface{}) string {
	switch x.(type) {
	case int:
		return "int"
	case string:
		return "string"
	default:
		return "unknown"
	}
}

// Uncached generic dispatch: try each method's predicate
func dispatchGenericUncached(x interface{}, y interface{}) string {
	// Try int-string
	if xi, okx := x.(int); okx {
		if ys, oky := y.(string); oky {
			_ = xi
			_ = ys
			return handleIntString(x, y)
		}
	}
	// Try string-int
	if xs, okx := x.(string); okx {
		if yi, oky := y.(int); oky {
			_ = xs
			_ = yi
			return handleStringInt(x, y)
		}
	}
	// Try int-int
	if xi, okx := x.(int); okx {
		if yi, oky := y.(int); oky {
			_ = xi
			_ = yi
			return handleIntInt(x, y)
		}
	}
	// Try string-string
	if xs, okx := x.(string); okx {
		if ys, oky := y.(string); oky {
			_ = xs
			_ = ys
			return handleStringString(x, y)
		}
	}
	return "unknown"
}

// Cached generic dispatch
func dispatchGenericCached(x interface{}, y interface{}, cache *GenericFuncCache) string {
	key := getTypeKeyForGeneric(x, y)
	cached := cache.Lookup(key)

	if cached != nil {
		return cached(x, y)
	}

	var fn func(interface{}, interface{}) string

	// Find matching method
	if xi, okx := x.(int); okx {
		if ys, oky := y.(string); oky {
			_ = xi
			_ = ys
			fn = handleIntString
		} else if yi, oky := y.(int); oky {
			_ = xi
			_ = yi
			fn = handleIntInt
		} else {
			fn = func(interface{}, interface{}) string { return "unknown" }
		}
	} else if xs, okx := x.(string); okx {
		if yi, oky := y.(int); oky {
			_ = xs
			_ = yi
			fn = handleStringInt
		} else if ys, oky := y.(string); oky {
			_ = xs
			_ = ys
			fn = handleStringString
		} else {
			fn = func(interface{}, interface{}) string { return "unknown" }
		}
	} else {
		fn = func(interface{}, interface{}) string { return "unknown" }
	}

	cache.Insert(key, fn)
	return fn(x, y)
}

func main() {
	const numCalls = 2000000

	fmt.Println("================================")
	fmt.Println("Go Generic Function Dispatch Benchmark")
	fmt.Println("================================")
	fmt.Printf("Go version: 1.23.0\n")
	fmt.Printf("Test data: %d calls with 2-argument dispatch\n", numCalls)
	fmt.Println("  Type combinations: int-string, string-int, int-int, string-string")
	fmt.Println("  Dispatch: GENERIC FUNCTION (multimethod-style)")
	fmt.Println("  Two-argument dispatch with 4 method variants\n")

	// Create test data with 4 type combinations
	type Args struct {
		x interface{}
		y interface{}
	}

	testData := make([]Args, numCalls)
	for i := 0; i < numCalls; i++ {
		switch i % 4 {
		case 0:
			testData[i] = Args{42, "test"}
		case 1:
			testData[i] = Args{"test", 42}
		case 2:
			testData[i] = Args{100, 200}
		case 3:
			testData[i] = Args{"foo", "bar"}
		}
	}

	fmt.Println("Warming up compiler (100,000 calls)...")
	for i := 0; i < 100000; i++ {
		item := testData[i%len(testData)]
		dispatchGenericUncached(item.x, item.y)
	}

	cache := NewGenericFuncCache()
	for i := 0; i < 100000; i++ {
		item := testData[i%len(testData)]
		dispatchGenericCached(item.x, item.y, cache)
	}
	fmt.Println("Warmup complete.\n")

	// Benchmark uncached
	fmt.Println("=== Uncached Generic Function Dispatch (3 iterations) ===")
	uncachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchGenericUncached(item.x, item.y)
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
	fmt.Println("\n=== Cached Generic Function Dispatch (3 iterations) ===")
	cachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		cache.Reset()
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchGenericCached(item.x, item.y, cache)
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
	fmt.Println("\nKey Finding: Generic functions test multiple predicates.")
	fmt.Println("More predicates tested = more expensive baseline.")
	fmt.Println("Does higher baseline make caching more effective?")
	fmt.Println("================================")
}
