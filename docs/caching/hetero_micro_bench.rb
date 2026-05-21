#!/usr/bin/env ruby
# Micro-benchmark: heterogeneous dispatch (Ruby version)
# Compares dispatch caching across Lisp/Scheme implementations

CACHE_SIZE = 8

class DispatchCache
  attr_accessor :entries, :next_idx, :hits, :misses

  def initialize
    @entries = Array.new(CACHE_SIZE, nil)
    @next_idx = 0
    @hits = 0
    @misses = 0
  end

  def lookup(key)
    CACHE_SIZE.times do |i|
      entry = @entries[i]
      return entry[1] if entry && entry[0] == key
    end
    nil
  end

  def insert(key, fn)
    @entries[@next_idx] = [key, fn]
    @next_idx = (@next_idx + 1) % CACHE_SIZE
  end
end

def clause_long(x)
  [:long, x]
end

def clause_string(x)
  [:string, x.length]
end

def clause_array(x)
  [:array, x.length]
end

def clause_hash(x)
  [:hash, x.length]
end

def clause_symbol(x)
  [:symbol, x]
end

def clause_other(x)
  [:other, x]
end

# Cache instance
$hetero_cache = DispatchCache.new

def dispatch_hetero_uncached(x)
  case x
  when Integer, Float
    [:long, x]
  when String
    [:string, x.length]
  when Array
    [:array, x.length]
  when Hash
    [:hash, x.length]
  when Symbol
    [:symbol, x]
  else
    [:other, x]
  end
end

def dispatch_hetero_cached(x)
  key = case x
        when Integer, Float then :long
        when String then :string
        when Array then :array
        when Hash then :hash
        when Symbol then :symbol
        else :other
        end

  hit = $hetero_cache.lookup(key)
  if hit
    $hetero_cache.hits += 1
    return hit.call(x)
  end

  $hetero_cache.misses += 1
  case x
  when Integer, Float
    $hetero_cache.insert(key, method(:clause_long))
    clause_long(x)
  when String
    $hetero_cache.insert(key, method(:clause_string))
    clause_string(x)
  when Array
    $hetero_cache.insert(key, method(:clause_array))
    clause_array(x)
  when Hash
    $hetero_cache.insert(key, method(:clause_hash))
    clause_hash(x)
  when Symbol
    $hetero_cache.insert(key, method(:clause_symbol))
    clause_symbol(x)
  else
    $hetero_cache.insert(key, method(:clause_other))
    clause_other(x)
  end
end

# Test data: 200,000 calls with 5-type repeating cycle
test_data = []
cycle = [1, "test string", [1, 2, 3, 4, 5], { a: 1 }, :symbol]
200000.times { |i| test_data << cycle[i % 5] }

def benchmark_uncached(iterations, test_data)
  times = []
  iterations.times do |run|
    result = 0
    start_time = Time.now
    test_data.each do |item|
      r = dispatch_hetero_uncached(item)
      result += 1 if r
    end
    elapsed = (Time.now - start_time) * 1000.0
    puts "  Run #{run + 1}: #{sprintf('%.1f', elapsed / 1000.0)} seconds"
    times << result
  end
  times
end

def benchmark_cached(iterations, test_data)
  times = []
  iterations.times do |run|
    $hetero_cache.hits = 0
    $hetero_cache.misses = 0
    result = 0
    start_time = Time.now
    test_data.each do |item|
      r = dispatch_hetero_cached(item)
      result += 1 if r
    end
    elapsed = (Time.now - start_time) * 1000.0
    puts "  Run #{run + 1}: #{sprintf('%.1f', elapsed / 1000.0)} seconds"
    times << result
  end
  times
end

def run_all_benchmarks(test_data)
  puts "\n================================"
  puts "Ruby Heterogeneous Dispatch Caching Micro-Benchmark"
  puts "================================"
  puts "Implementation: Ruby #{RUBY_VERSION}"
  puts "Test data: 200,000 calls over repeating 5-type cycle"
  puts "  Type cycle: integer -> string -> array -> hash -> symbol\n"

  puts "Warming up JIT compiler (10,000 calls)..."
  10000.times do |i|
    dispatch_hetero_uncached(test_data[i % test_data.length])
  end
  10000.times do |i|
    $hetero_cache.hits = 0
    $hetero_cache.misses = 0
    dispatch_hetero_cached(test_data[i % test_data.length])
  end
  puts "Warmup complete.\n"

  puts "=== Uncached Dispatch (3 iterations) ==="
  benchmark_uncached(3, test_data)

  puts "\n=== Cached Dispatch (3 iterations) ==="
  benchmark_cached(3, test_data)

  puts "\nCached Dispatch Stats:"
  total = $hetero_cache.hits + $hetero_cache.misses
  puts "  Cache hits: #{$hetero_cache.hits}"
  puts "  Cache misses: #{$hetero_cache.misses}"
  if total > 0
    hit_rate = 100.0 * $hetero_cache.hits / total
    puts "  Hit rate: #{hit_rate.round(4)}%"
  end

  puts "\n================================"
  puts "Benchmark Complete"
  puts "================================"
end

run_all_benchmarks(test_data)
