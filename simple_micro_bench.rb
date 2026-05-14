#!/usr/bin/env ruby
# Micro-benchmark: homogeneous dispatch (Ruby version)
# All dispatches on integers only

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
$homo_cache = DispatchCache.new

def dispatch_homo_uncached(x)
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

def dispatch_homo_cached(x)
  key = case x
        when Integer, Float then :long
        when String then :string
        when Array then :array
        when Hash then :hash
        when Symbol then :symbol
        else :other
        end

  hit = $homo_cache.lookup(key)
  if hit
    $homo_cache.hits += 1
    return hit.call(x)
  end

  $homo_cache.misses += 1
  case x
  when Integer, Float
    $homo_cache.insert(key, method(:clause_long))
    clause_long(x)
  when String
    $homo_cache.insert(key, method(:clause_string))
    clause_string(x)
  when Array
    $homo_cache.insert(key, method(:clause_array))
    clause_array(x)
  when Hash
    $homo_cache.insert(key, method(:clause_hash))
    clause_hash(x)
  when Symbol
    $homo_cache.insert(key, method(:clause_symbol))
    clause_symbol(x)
  else
    $homo_cache.insert(key, method(:clause_other))
    clause_other(x)
  end
end

# Test data: 200,000 number-only calls
test_data = Array.new(200000) { rand(1000000) }

def benchmark_uncached(iterations, test_data)
  times = []
  iterations.times do |run|
    result = 0
    start_time = Time.now
    test_data.each do |item|
      r = dispatch_homo_uncached(item)
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
    $homo_cache.hits = 0
    $homo_cache.misses = 0
    result = 0
    start_time = Time.now
    test_data.each do |item|
      r = dispatch_homo_cached(item)
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
  puts "Ruby Homogeneous Dispatch Caching Micro-Benchmark"
  puts "================================"
  puts "Implementation: Ruby #{RUBY_VERSION}"
  puts "Test data: 200,000 number-only calls\n"

  puts "Warming up JIT compiler (10,000 calls)..."
  10000.times do |i|
    dispatch_homo_uncached(test_data[i % test_data.length])
  end
  10000.times do |i|
    $homo_cache.hits = 0
    $homo_cache.misses = 0
    dispatch_homo_cached(test_data[i % test_data.length])
  end
  puts "Warmup complete.\n"

  puts "=== Uncached Dispatch (3 iterations) ==="
  benchmark_uncached(3, test_data)

  puts "\n=== Cached Dispatch (3 iterations) ==="
  benchmark_cached(3, test_data)

  puts "\nCached Dispatch Stats:"
  total = $homo_cache.hits + $homo_cache.misses
  puts "  Cache hits: #{$homo_cache.hits}"
  puts "  Cache misses: #{$homo_cache.misses}"
  if total > 0
    hit_rate = 100.0 * $homo_cache.hits / total
    puts "  Hit rate: #{hit_rate.round(4)}%"
  end

  puts "\n================================"
  puts "Benchmark Complete"
  puts "================================"
end

run_all_benchmarks(test_data)
