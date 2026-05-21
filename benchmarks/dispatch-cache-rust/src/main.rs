use std::collections::HashMap;
use std::time::Instant;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
enum TestType {
    Int,
    String,
    Vector,
    Other,
}

#[derive(Clone, Debug)]
enum Value {
    Int(i64),
    String,
    Vector,
    Other,
}

fn dispatch_uncached(val: TestType) -> (String, usize) {
    match val {
        TestType::Int => ("int".to_string(), 42),
        TestType::String => ("string".to_string(), 11),
        TestType::Vector => ("vector".to_string(), 5),
        TestType::Other => ("other".to_string(), 0),
    }
}

fn dispatch_cached(val: TestType, cache: &mut HashMap<TestType, fn() -> (String, usize)>) -> (String, usize) {
    if let Some(handler) = cache.get(&val) {
        return handler();
    }

    let handler = match val {
        TestType::Int => || ("int".to_string(), 42),
        TestType::String => || ("string".to_string(), 11),
        TestType::Vector => || ("vector".to_string(), 5),
        TestType::Other => || ("other".to_string(), 0),
    };

    cache.insert(val, handler);
    handler()
}

fn main() {
    let test_cycle = vec![TestType::Int, TestType::String, TestType::Vector, TestType::Other];
    let test_data: Vec<TestType> = test_cycle.repeat(2_000_000 / 4);

    println!("================================");
    println!("Rust Dispatch Caching Micro-Benchmark");
    println!("================================");
    println!("Test data: 2,000,000 calls over repeating 4-type cycle\n");

    println!("Warming up (100,000 calls)...");
    for i in 0..100_000 {
        let _ = dispatch_uncached(test_data[i % test_data.len()]);
    }

    let mut cache = HashMap::new();
    for i in 0..100_000 {
        let _ = dispatch_cached(test_data[i % test_data.len()], &mut cache);
    }
    println!("Warmup complete.\n");

    println!("=== Uncached Dispatch (3 iterations, 2M calls each) ===");
    let mut uncached_times = vec![];
    for run in 1..=3 {
        let start = Instant::now();
        for &item in &test_data {
            let _ = dispatch_uncached(item);
        }
        let elapsed = start.elapsed();
        let elapsed_ns = elapsed.as_nanos() as f64;
        uncached_times.push(elapsed_ns);
        let ns_per_call = elapsed_ns / test_data.len() as f64;
        println!("  Run {}: {:.4} seconds ({:.1} ns/call)", run, elapsed.as_secs_f64(), ns_per_call);
    }

    println!("\n=== Cached Dispatch (3 iterations, 2M calls each) ===");
    let mut cached_times = vec![];
    for run in 1..=3 {
        cache.clear();
        let start = Instant::now();
        for &item in &test_data {
            let _ = dispatch_cached(item, &mut cache);
        }
        let elapsed = start.elapsed();
        let elapsed_ns = elapsed.as_nanos() as f64;
        cached_times.push(elapsed_ns);
        let ns_per_call = elapsed_ns / test_data.len() as f64;
        println!("  Run {}: {:.4} seconds ({:.1} ns/call)", run, elapsed.as_secs_f64(), ns_per_call);
    }

    let avg_uncached: f64 = uncached_times.iter().sum::<f64>() / uncached_times.len() as f64;
    let avg_cached: f64 = cached_times.iter().sum::<f64>() / cached_times.len() as f64;
    let ratio = avg_cached / avg_uncached;

    let avg_uncached_ns_per_call = avg_uncached / test_data.len() as f64;
    let avg_cached_ns_per_call = avg_cached / test_data.len() as f64;

    println!("\n================================");
    println!("Average uncached: {:.1} ns/call", avg_uncached_ns_per_call);
    println!("Average cached: {:.1} ns/call", avg_cached_ns_per_call);
    println!("Slowdown ratio: {:.2}×", ratio);
    println!("================================");
}
