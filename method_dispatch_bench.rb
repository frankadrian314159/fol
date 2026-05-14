#!/usr/bin/env ruby
# Micro-benchmark: generic function dispatch (Ruby version)
# Basic dispatch performance test using a dispatch table

# Dispatch table
dispatch_table = {
  :long => lambda { |x| [:long, x] },
  :string => lambda { |x| [:string, x.length] },
  :array => lambda { |x| [:array, x.length] },
  :hash => lambda { |x| [:hash, x.length] },
  :symbol => lambda { |x| [:symbol, x] },
  :other => lambda { |x| [:other, x] }
}

def dispatch_clj_impl(x, dispatch_table)
  key = case x
        when Integer, Float then :long
        when String then :string
        when Array then :array
        when Hash then :hash
        when Symbol then :symbol
        else :other
        end
  dispatch_table[key].call(x)
end

# Test data: 200,000 calls with 5-type repeating cycle
test_data = []
cycle = [1, "test string", [1, 2, 3, 4, 5], { a: 1 }, :symbol]
200000.times { |i| test_data << cycle[i % 5] }

def benchmark_dispatch(iterations, test_data, dispatch_table)
  times = []
  iterations.times do |run|
    result = 0
    start_time = Time.now
    test_data.each do |item|
      r = dispatch_clj_impl(item, dispatch_table)
      result += 1 if r
    end
    elapsed = (Time.now - start_time) * 1000.0
    puts "  Run #{run + 1}: #{sprintf('%.1f', elapsed / 1000.0)} seconds"
    times << result
  end
  times
end

def run_all_benchmarks(test_data, dispatch_table)
  puts "\n================================"
  puts "Ruby Generic Function Dispatch Micro-Benchmark"
  puts "================================"
  puts "Implementation: Ruby #{RUBY_VERSION}"
  puts "Test data: 200,000 calls over repeating 5-type cycle"
  puts "  Type cycle: integer -> string -> array -> hash -> symbol\n"

  puts "Warming up JIT compiler (10,000 calls)..."
  10000.times do |i|
    dispatch_clj_impl(test_data[i % test_data.length], dispatch_table)
  end
  puts "Warmup complete.\n"

  puts "Running dispatch benchmark (3 iterations):"
  benchmark_dispatch(3, test_data, dispatch_table)

  puts "\n================================"
  puts "Benchmark Complete"
  puts "================================"
end

run_all_benchmarks(test_data, dispatch_table)
