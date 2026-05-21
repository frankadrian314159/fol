package main

import (
	"fmt"
	"sync"
	"time"
)

// Cache size sensitivity benchmark
// Tests how caching performance varies with cache slot count
// Addresses critique: "Why always 8-slot? No justification or variants tested."

type SizeAdjustableCache struct {
	entries [256]map[string]func(interface{}) string // Maximum 256 slots
	size    int                                       // Actual slots in use
	nextIdx int
	hits    int64
	misses  int64
	mu      sync.Mutex
}

func NewSizeAdjustableCache(slotCount int) *SizeAdjustableCache {
	if slotCount > 256 {
		slotCount = 256
	}
	cache := &SizeAdjustableCache{size: slotCount}
	for i := 0; i < slotCount; i++ {
		cache.entries[i] = make(map[string]func(interface{}) string)
	}
	return cache
}

func (c *SizeAdjustableCache) Lookup(key string) func(interface{}) string {
	c.mu.Lock()
	defer c.mu.Unlock()

	for i := 0; i < c.size; i++ {
		if fn, ok := c.entries[i][key]; ok {
			c.hits++
			return fn
		}
	}
	c.misses++
	return nil
}

func (c *SizeAdjustableCache) Insert(key string, fn func(interface{}) string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	for k := range c.entries[c.nextIdx] {
		delete(c.entries[c.nextIdx], k)
	}
	c.entries[c.nextIdx][key] = fn
	c.nextIdx = (c.nextIdx + 1) % c.size
}

func (c *SizeAdjustableCache) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.hits = 0
	c.misses = 0
	c.nextIdx = 0
	for i := 0; i < c.size; i++ {
		for k := range c.entries[i] {
			delete(c.entries[i], k)
		}
	}
}

// Clause functions
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

// Type key
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

// Uncached dispatch
func dispatchUncached(x interface{}) string {
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

// Cached dispatch with adjustable cache size
func dispatchCached(x interface{}, cache *SizeAdjustableCache) string {
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

func runCacheSensitivityTest(numCalls int, cacheSize int) (uncachedNs float64, cachedNs float64) {
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

	// Warmup
	for i := 0; i < 10000; i++ {
		dispatchUncached(testData[i%numCalls])
	}

	cache := NewSizeAdjustableCache(cacheSize)
	for i := 0; i < 10000; i++ {
		dispatchCached(testData[i%numCalls], cache)
	}

	// Benchmark uncached
	start := time.Now()
	for _, item := range testData {
		dispatchUncached(item)
	}
	uncachedElapsed := time.Since(start)
	uncachedNs = float64(uncachedElapsed.Nanoseconds()) / float64(numCalls)

	// Benchmark cached
	cache.Reset()
	start = time.Now()
	for _, item := range testData {
		dispatchCached(item, cache)
	}
	cachedElapsed := time.Since(start)
	cachedNs = float64(cachedElapsed.Nanoseconds()) / float64(numCalls)

	return uncachedNs, cachedNs
}

func main() {
	const numCalls = 2000000

	fmt.Println("================================")
	fmt.Println("Go Cache Size Sensitivity Analysis")
	fmt.Println("================================")
	fmt.Printf("Test data: %d calls over repeating 4-type cycle\n", numCalls)
	fmt.Println("Varying cache slot count: 1, 2, 4, 8, 16, 32, 64, 128, 256\n")

	fmt.Println("Baseline (uncached):")
	uncachedNs, _ := runCacheSensitivityTest(numCalls, 1)
	fmt.Printf("  Uncached dispatch: %.1f ns/call\n\n", uncachedNs)

	fmt.Println("Cache Size Sensitivity Results:")
	fmt.Println("Slots | Cached (ns) | Ratio | Hit Rate | Analysis")
	fmt.Println("------|-------------|-------|----------|----------------------------------")

	sizes := []int{1, 2, 4, 8, 16, 32, 64, 128, 256}
	for _, size := range sizes {
		_, cachedNs := runCacheSensitivityTest(numCalls, size)
		ratio := cachedNs / uncachedNs

		// Create new cache to measure hit rate
		cache := NewSizeAdjustableCache(size)
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
		for _, item := range testData {
			dispatchCached(item, cache)
		}
		hitRate := 100.0 * float64(cache.hits) / float64(cache.hits+cache.misses)

		analysis := ""
		if ratio > 1.1 {
			analysis = "SLOWDOWN"
		} else if ratio > 1.05 {
			analysis = "Marginal slowdown"
		} else if ratio > 0.95 {
			analysis = "Neutral/Marginal"
		} else {
			analysis = "SPEEDUP"
		}

		fmt.Printf("%5d | %11.1f | %5.2f | %7.4f%% | %s\n",
			size, cachedNs, ratio, hitRate, analysis)
	}

	fmt.Println("\n================================")
	fmt.Println("Key Findings:")
	fmt.Println("1. Do smaller caches help? (overhead reduction)")
	fmt.Println("2. Do larger caches help? (hit rate improvement)")
	fmt.Println("3. What is the optimal cache size for this workload?")
	fmt.Println("4. Does cache size change the fundamental conclusion?")
	fmt.Println("================================")
}
