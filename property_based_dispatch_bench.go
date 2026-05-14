package main

import (
	"fmt"
	"sync"
	"time"
)

// Property-based dispatch: Clojure-style protocol/trait dispatch
// Tests dispatch based on object structure/protocol rather than type
// Different from type-based dispatch: same type can implement different protocols

type ProtocolImpl struct {
	name       string
	predicate  func(interface{}) bool
	handler    func(interface{}) string
}

type PropertyBasedCache struct {
	entries [8]map[string]func(interface{}) string
	nextIdx int
	hits    int64
	misses  int64
	mu      sync.Mutex
}

func NewPropertyBasedCache() *PropertyBasedCache {
	cache := &PropertyBasedCache{}
	for i := range cache.entries {
		cache.entries[i] = make(map[string]func(interface{}) string)
	}
	return cache
}

func (c *PropertyBasedCache) Lookup(key string) func(interface{}) string {
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

func (c *PropertyBasedCache) Insert(key string, fn func(interface{}) string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	for k := range c.entries[c.nextIdx] {
		delete(c.entries[c.nextIdx], k)
	}
	c.entries[c.nextIdx][key] = fn
	c.nextIdx = (c.nextIdx + 1) % len(c.entries)
}

func (c *PropertyBasedCache) Reset() {
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

// Simulate objects with different structures
type Writable struct {
	name string
}

type Readable struct {
	name string
}

type Iterator struct {
	name string
}

type Generic interface{}

// Property-based protocol implementations
// Predicate: does this object implement the protocol?

func implementsWritable(x interface{}) bool {
	_, ok := x.(*Writable)
	return ok
}

func implementsReadable(x interface{}) bool {
	_, ok := x.(*Readable)
	return ok
}

func implementsIterator(x interface{}) bool {
	_, ok := x.(*Iterator)
	return ok
}

func isGenericObject(x interface{}) bool {
	return x != nil
}

// Protocol handlers
func handleWritable(x interface{}) string {
	return "writable"
}

func handleReadable(x interface{}) string {
	return "readable"
}

func handleIterator(x interface{}) string {
	return "iterator"
}

func handleGeneric(x interface{}) string {
	return "generic"
}

// Uncached property-based dispatch: test each protocol predicate
func dispatchPropertyBasedUncached(x Generic) string {
	if implementsWritable(x) {
		return handleWritable(x)
	}
	if implementsReadable(x) {
		return handleReadable(x)
	}
	if implementsIterator(x) {
		return handleIterator(x)
	}
	if isGenericObject(x) {
		return handleGeneric(x)
	}
	return "unknown"
}

// Cached property-based dispatch
func dispatchPropertyBasedCached(x Generic, cache *PropertyBasedCache) string {
	// Cache key based on type name (protocol dispatch)
	var key string
	switch x.(type) {
	case *Writable:
		key = "writable"
	case *Readable:
		key = "readable"
	case *Iterator:
		key = "iterator"
	default:
		key = "generic"
	}

	cached := cache.Lookup(key)
	if cached != nil {
		return cached(x)
	}

	var fn func(interface{}) string
	if implementsWritable(x) {
		fn = handleWritable
	} else if implementsReadable(x) {
		fn = handleReadable
	} else if implementsIterator(x) {
		fn = handleIterator
	} else if isGenericObject(x) {
		fn = handleGeneric
	} else {
		fn = func(interface{}) string { return "unknown" }
	}

	cache.Insert(key, fn)
	return fn(x)
}

func main() {
	const numCalls = 2000000

	fmt.Println("================================")
	fmt.Println("Go Property-Based Dispatch (Protocol/Trait) Benchmark")
	fmt.Println("================================")
	fmt.Printf("Go version: 1.23.0\n")
	fmt.Printf("Test data: %d calls over repeating 4-protocol cycle\n", numCalls)
	fmt.Println("  Protocol cycle: Writable -> Readable -> Iterator -> Generic")
	fmt.Println("  Dispatch: PROTOCOL/TRAIT based (Clojure-style)")
	fmt.Println("  Predicates: Type assertions instead of type switch\n")

	// Create test data with 4-protocol cycle
	testData := make([]Generic, numCalls)
	for i := 0; i < numCalls; i++ {
		switch i % 4 {
		case 0:
			testData[i] = &Writable{name: "file1"}
		case 1:
			testData[i] = &Readable{name: "file2"}
		case 2:
			testData[i] = &Iterator{name: "iter1"}
		case 3:
			testData[i] = "generic_string"
		}
	}

	fmt.Println("Warming up compiler (100,000 calls)...")
	for i := 0; i < 100000; i++ {
		dispatchPropertyBasedUncached(testData[i%len(testData)])
	}

	cache := NewPropertyBasedCache()
	for i := 0; i < 100000; i++ {
		dispatchPropertyBasedCached(testData[i%len(testData)], cache)
	}
	fmt.Println("Warmup complete.\n")

	// Benchmark uncached
	fmt.Println("=== Uncached Property-Based Dispatch (3 iterations) ===")
	uncachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchPropertyBasedUncached(item)
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
	fmt.Println("\n=== Cached Property-Based Dispatch (3 iterations) ===")
	cachedTimes := make([]time.Duration, 3)
	for run := 0; run < 3; run++ {
		cache.Reset()
		start := time.Now()
		result := 0
		for _, item := range testData {
			r := dispatchPropertyBasedCached(item, cache)
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
	fmt.Println("\nKey Finding: Protocol/trait dispatch uses type assertions.")
	fmt.Println("Type assertions are more expensive than type switch.")
	fmt.Println("Does this change caching effectiveness?")
	fmt.Println("================================")
}
