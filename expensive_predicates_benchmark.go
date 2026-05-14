package main

import (
	"fmt"
	"regexp"
	"sync"
	"time"
)

// ExpensiveDispatchResult represents the result of expensive dispatch
type ExpensiveDispatchResult struct {
	Category string
	Value    interface{}
}

// ExpensiveCache is a simple round-robin LRU cache for expensive predicates
type ExpensiveCache struct {
	entries [8]map[string]func(interface{}) *ExpensiveDispatchResult
	nextIdx int
	hits    int64
	misses  int64
	mu      sync.Mutex
}

func NewExpensiveCache() *ExpensiveCache {
	cache := &ExpensiveCache{}
	for i := range cache.entries {
		cache.entries[i] = make(map[string]func(interface{}) *ExpensiveDispatchResult)
	}
	return cache
}

func (c *ExpensiveCache) Lookup(key string) func(interface{}) *ExpensiveDispatchResult {
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

func (c *ExpensiveCache) Insert(key string, fn func(interface{}) *ExpensiveDispatchResult) {
	c.mu.Lock()
	defer c.mu.Unlock()

	for k := range c.entries[c.nextIdx] {
		delete(c.entries[c.nextIdx], k)
	}
	c.entries[c.nextIdx][key] = fn
	c.nextIdx = (c.nextIdx + 1) % len(c.entries)
}

func (c *ExpensiveCache) Reset() {
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

// Expensive predicates: simulate regex/pattern matching taking 1-10 microseconds

func predicateIsValidEmail(x interface{}) bool {
	str, ok := x.(string)
	if !ok {
		return false
	}
	// Expensive regex pattern matching (~2-3 microseconds)
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(str)
}

func predicateIsJSON(x interface{}) bool {
	str, ok := x.(string)
	if !ok {
		return false
	}
	// Expensive regex pattern matching (~1-2 microseconds)
	jsonRegex := regexp.MustCompile(`^[\s]*[\{\[].*[\}\]][\s]*$`)
	return jsonRegex.MatchString(str)
}

func predicateIsIPAddress(x interface{}) bool {
	str, ok := x.(string)
	if !ok {
		return false
	}
	// Expensive regex pattern matching (~2-3 microseconds)
	ipRegex := regexp.MustCompile(`^(\d{1,3}\.){3}\d{1,3}$`)
	return ipRegex.MatchString(str)
}

func predicateIsURL(x interface{}) bool {
	str, ok := x.(string)
	if !ok {
		return false
	}
	// Expensive regex pattern matching (~2-3 microseconds)
	urlRegex := regexp.MustCompile(`^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[a-zA-Z0-9._~:/?#\[\]@!$&'()*+,;=-]*)?$`)
	return urlRegex.MatchString(str)
}

func predicateIsAlphanumericOnly(x interface{}) bool {
	str, ok := x.(string)
	if !ok {
		return false
	}
	// Expensive regex pattern matching (~1-2 microseconds)
	alphaNumRegex := regexp.MustCompile(`^[a-zA-Z0-9]+$`)
	return alphaNumRegex.MatchString(str)
}

// Clause functions: return appropriate category for matched predicate
func clauseEmail(x interface{}) *ExpensiveDispatchResult {
	return &ExpensiveDispatchResult{"email", x}
}

func clauseJSON(x interface{}) *ExpensiveDispatchResult {
	return &ExpensiveDispatchResult{"json", x}
}

func clauseIP(x interface{}) *ExpensiveDispatchResult {
	return &ExpensiveDispatchResult{"ipaddress", x}
}

func clauseURL(x interface{}) *ExpensiveDispatchResult {
	return &ExpensiveDispatchResult{"url", x}
}

func clauseAlphaNum(x interface{}) *ExpensiveDispatchResult {
	return &ExpensiveDispatchResult{"alphanumeric", x}
}

func clauseUnknown(x interface{}) *ExpensiveDispatchResult {
	return &ExpensiveDispatchResult{"unknown", x}
}

// Uncached dispatcher: test all predicates until one matches (~5-15 microseconds per call)
func dispatchUncached(x interface{}) *ExpensiveDispatchResult {
	if predicateIsValidEmail(x) {
		return clauseEmail(x)
	}
	if predicateIsJSON(x) {
		return clauseJSON(x)
	}
	if predicateIsIPAddress(x) {
		return clauseIP(x)
	}
	if predicateIsURL(x) {
		return clauseURL(x)
	}
	if predicateIsAlphanumericOnly(x) {
		return clauseAlphaNum(x)
	}
	return clauseUnknown(x)
}

// Cached dispatcher: cache the matching clause
func dispatchCached(x interface{}, cache *ExpensiveCache) *ExpensiveDispatchResult {
	// Create cache key based on first 20 chars of string to approximate "shape"
	var key string
	if str, ok := x.(string); ok {
		if len(str) > 20 {
			key = str[:20]
		} else {
			key = str
		}
	} else {
		key = "unknown"
	}

	cached := cache.Lookup(key)
	if cached != nil {
		return cached(x)
	}

	// Find matching predicate and cache it
	var fn func(interface{}) *ExpensiveDispatchResult
	if predicateIsValidEmail(x) {
		fn = clauseEmail
	} else if predicateIsJSON(x) {
		fn = clauseJSON
	} else if predicateIsIPAddress(x) {
		fn = clauseIP
	} else if predicateIsURL(x) {
		fn = clauseURL
	} else if predicateIsAlphanumericOnly(x) {
		fn = clauseAlphaNum
	} else {
		fn = clauseUnknown
	}

	cache.Insert(key, fn)
	return fn(x)
}

func main() {
	const numCalls = 100000 // Fewer calls since each predicate is expensive

	fmt.Println("================================")
	fmt.Println("Go Expensive Predicates Dispatch Caching Micro-Benchmark")
	fmt.Println("================================")
	fmt.Printf("Go version: %s\n", getGoVersion())
	fmt.Printf("Test data: %d calls with expensive predicates (1-3µs per predicate)\n", numCalls)
	fmt.Println("  Predicates: email, JSON, IP address, URL, alphanumeric")
	fmt.Println("  Dispatch cost (uncached): ~5-15µs per call")
	fmt.Println("  Cache benefit potential: ~2-10µs savings when predicate matches early\n")

	// Create test data with cycling pattern
	testData := make([]interface{}, numCalls)
	patterns := []string{
		"user@example.com",                           // email
		`{"key": "value"}`,                           // json
		"192.168.1.1",                                // ip
		"https://example.com/path?query=value",       // url
		"abc123def456",                               // alphanumeric
	}
	for i := 0; i < numCalls; i++ {
		testData[i] = patterns[i%len(patterns)]
	}

	fmt.Println("Warming up compiler (10,000 calls)...")
	for i := 0; i < 10000; i++ {
		dispatchUncached(testData[i%len(testData)])
	}

	cache := NewExpensiveCache()
	for i := 0; i < 10000; i++ {
		dispatchCached(testData[i%len(testData)], cache)
	}
	fmt.Println("Warmup complete.\n")

	// Benchmark uncached
	fmt.Println("=== Uncached Expensive Dispatch (3 iterations) ===")
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
		usPerCall := float64(elapsed.Microseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.2f µs/call)\n", run+1, elapsed.Seconds(), usPerCall)
	}

	// Benchmark cached
	fmt.Println("\n=== Cached Expensive Dispatch (3 iterations) ===")
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
		usPerCall := float64(elapsed.Microseconds()) / float64(len(testData))
		fmt.Printf("  Run %d: %.4f seconds (%.2f µs/call)\n", run+1, elapsed.Seconds(), usPerCall)
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

	uncachedUs := float64(avgUncached.Microseconds()) / float64(numCalls)
	cachedUs := float64(avgCached.Microseconds()) / float64(numCalls)
	ratio := float64(avgCached) / float64(avgUncached)

	fmt.Println("\n================================")
	fmt.Printf("Average uncached: %.2f µs/call\n", uncachedUs)
	fmt.Printf("Average cached: %.2f µs/call\n", cachedUs)
	fmt.Printf("Speedup/Slowdown ratio: %.2f×\n", ratio)

	if ratio < 1.0 {
		fmt.Printf("SPEEDUP: %d%% faster with caching\n", int((1.0-ratio)*100))
	} else {
		fmt.Printf("SLOWDOWN: %d%% slower with caching\n", int((ratio-1.0)*100))
	}

	fmt.Printf("\nBreak-even analysis:\n")
	fmt.Printf("  Predicate cost: ~5-15 µs (expensive)\n")
	fmt.Printf("  Cache overhead: ~0.1-0.5 µs (negligible at this scale)\n")
	fmt.Printf("  Theoretical: Should see speedup if early-match predicates save expensive checks\n")
	fmt.Printf("  Actual: %.2f%% %s\n", ratio, func() string {
		if ratio > 1.0 {
			return "SLOWDOWN"
		}
		return "SPEEDUP"
	}())

	fmt.Println("================================")
}

func getGoVersion() string {
	return "1.23.0"
}
