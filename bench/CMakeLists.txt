# Microbenchmarks — built only when ENABLE_BENCHMARKS=ON.
# Google Benchmark is fetched via the configured dependency manager
# (CPM by default, find_package() under VCPKG/CONAN).

if(NOT TARGET benchmark::benchmark)
  message(FATAL_ERROR
    "ENABLE_BENCHMARKS=ON but benchmark::benchmark target not available. "
    "Check setup_dependencies() in cmake/Dependencies.cmake.")
endif()

add_executable(bench_factorial bench_factorial.cpp)

target_link_libraries(bench_factorial
  PRIVATE
    ${PROJECT_NAME}::warnings
    ${PROJECT_NAME}::options
    ${PROJECT_NAME}::sample_library
    benchmark::benchmark_main)

configure_linker(bench_factorial)

# Don't register the benchmark with ctest — benchmarks are timing-sensitive
# and shouldn't run alongside correctness tests. Run manually:
#   ./out/build/<preset>/bench/bench_factorial
