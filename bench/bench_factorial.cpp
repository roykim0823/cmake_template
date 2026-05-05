// Microbenchmark for the sample library. Runs only when ENABLE_BENCHMARKS=ON.
#include <benchmark/benchmark.h>

#include <myproject/sample_library.hpp>

static void BM_Factorial(benchmark::State& state)
{
  const auto n = static_cast<int>(state.range(0));
  for (auto _ : state)
  {
    benchmark::DoNotOptimize(factorial(n));
  }
}
BENCHMARK(BM_Factorial)->Arg(5)->Arg(10)->Arg(15);
