# Pull in the dependency block so a single setup_project() call wires
# everything up — options, IPO, hardening, dependencies, per-target settings.
include(cmake/Dependencies.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)
include(CheckCXXSourceCompiles)


# Probe whether the toolchain supports ASan / UBSan at link time. Sets
# SUPPORTS_ASAN and SUPPORTS_UBSAN in the calling scope. Used to pick
# default values for ENABLE_SANITIZER_* options.
macro(supports_sanitizers)
  if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*")
    set(_test "int main() { return 0; }")

    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${_test}" SUPPORTS_UBSAN)

    set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
    check_cxx_source_compiles("${_test}" SUPPORTS_ASAN)
  else()
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  endif()
endmacro()


# Decide whether to layer the UBSan minimal runtime on top of hardening.
# Used by both the global and the per-target hardening paths.
macro(_compute_ubsan_minimal_runtime)
  if(NOT SUPPORTS_UBSAN
     OR ENABLE_SANITIZER_UNDEFINED
     OR ENABLE_SANITIZER_ADDRESS
     OR ENABLE_SANITIZER_THREAD
     OR ENABLE_SANITIZER_LEAK)
    set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
  else()
    set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
  endif()
endmacro()


# Single entry point. Run from CMakeLists.txt after project(). Order is:
#   1. declare options and probe sanitizer support
#   2. apply project-wide settings (IPO, global hardening) — before deps
#   3. fetch dependencies via setup_dependencies()
#   4. apply per-target settings on the `options` / `warnings` interface libs
macro(setup_project)
  # ── 1. Declare options ─────────────────────────────────────────────────────
  option(ENABLE_HARDENING "Enable hardening" ON)
  option(ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    ENABLE_GLOBAL_HARDENING
    "Push hardening options to built dependencies"
    ON
    ENABLE_HARDENING
    OFF)

  supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR PACKAGING_MAINTAINER_MODE)
    option(ENABLE_IPO "Enable IPO/LTO" OFF)
    option(WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)
    option(ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(ENABLE_SANITIZER_UNDEFINED "Enable undefined-behavior sanitizer" OFF)
    option(ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(ENABLE_CPPCHECK "Enable cppcheck analysis" OFF)
    option(ENABLE_CPPLINT "Enable cpplint (Google C++ style linter)" OFF)
    option(ENABLE_IWYU "Enable include-what-you-use" OFF)
    option(ENABLE_PCH "Enable precompiled headers" OFF)
    option(ENABLE_CACHE "Enable ccache / sccache" OFF)
  else()
    option(ENABLE_IPO "Enable IPO/LTO" ON)
    option(WARNINGS_AS_ERRORS "Treat warnings as errors" ON)
    option(ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(ENABLE_SANITIZER_UNDEFINED "Enable undefined-behavior sanitizer" ${SUPPORTS_UBSAN})
    option(ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(ENABLE_CPPCHECK "Enable cppcheck analysis" ON)
    # cpplint enforces Google C++ style — opt-in even at top level since
    # most users don't want both Google style and this template's .clang-format.
    option(ENABLE_CPPLINT "Enable cpplint (Google C++ style linter)" OFF)
    # IWYU is noisy and typically run on demand rather than every build.
    option(ENABLE_IWYU "Enable include-what-you-use" OFF)
    option(ENABLE_PCH "Enable precompiled headers" OFF)
    option(ENABLE_CACHE "Enable ccache / sccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      ENABLE_IPO
      WARNINGS_AS_ERRORS
      ENABLE_SANITIZER_ADDRESS
      ENABLE_SANITIZER_LEAK
      ENABLE_SANITIZER_UNDEFINED
      ENABLE_SANITIZER_THREAD
      ENABLE_SANITIZER_MEMORY
      ENABLE_UNITY_BUILD
      ENABLE_CLANG_TIDY
      ENABLE_CPPCHECK
      ENABLE_CPPLINT
      ENABLE_IWYU
      ENABLE_COVERAGE
      ENABLE_PCH
      ENABLE_CACHE)
  endif()

  check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (ENABLE_SANITIZER_ADDRESS OR ENABLE_SANITIZER_THREAD OR ENABLE_SANITIZER_UNDEFINED))
    set(_default_fuzzer ON)
  else()
    set(_default_fuzzer OFF)
  endif()
  option(BUILD_FUZZ_TESTS "Build the libFuzzer harness" ${_default_fuzzer})

  option(ENABLE_GTEST "Enable Google Test framework (default)" ON)
  option(ENABLE_CATCH2 "Enable Catch2 test framework" OFF)
  option(ENABLE_BENCHMARKS "Build microbenchmarks (Google Benchmark)" OFF)
  option(ENABLE_DOXYGEN "Generate API docs with Doxygen (target: docs)" OFF)

  # ── 2. Apply project-wide settings ─────────────────────────────────────────
  if(ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    enable_ipo()
  endif()

  if(ENABLE_HARDENING AND ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    _compute_ubsan_minimal_runtime()
    enable_hardening(options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

  # ── 3. Fetch dependencies ──────────────────────────────────────────────────
  setup_dependencies()

  # ── 4. Apply per-target settings ───────────────────────────────────────────
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(warnings INTERFACE)
  add_library(options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  set_project_warnings(warnings ${WARNINGS_AS_ERRORS} "" "" "")

  include(cmake/Linker.cmake)
  include(cmake/Sanitizers.cmake)
  enable_sanitizers(
    options
    ${ENABLE_SANITIZER_ADDRESS}
    ${ENABLE_SANITIZER_LEAK}
    ${ENABLE_SANITIZER_UNDEFINED}
    ${ENABLE_SANITIZER_THREAD}
    ${ENABLE_SANITIZER_MEMORY})

  set_target_properties(options PROPERTIES UNITY_BUILD ${ENABLE_UNITY_BUILD})

  if(ENABLE_PCH)
    target_precompile_headers(options INTERFACE <vector> <string> <utility>)
  endif()

  if(ENABLE_CACHE)
    include(cmake/Cache.cmake)
    enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(ENABLE_CLANG_TIDY)
    enable_clang_tidy(options ${WARNINGS_AS_ERRORS})
  endif()
  if(ENABLE_CPPCHECK)
    enable_cppcheck(${WARNINGS_AS_ERRORS} "")
  endif()
  if(ENABLE_CPPLINT)
    enable_cpplint(${WARNINGS_AS_ERRORS})
  endif()
  if(ENABLE_IWYU)
    enable_iwyu()
  endif()

  if(ENABLE_COVERAGE)
    include(cmake/Coverage.cmake)
    enable_coverage(options)
  endif()

  if(ENABLE_HARDENING AND NOT ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    _compute_ubsan_minimal_runtime()
    enable_hardening(options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

  if(ENABLE_DOXYGEN)
    include(cmake/Doxygen.cmake)
    enable_doxygen()
  endif()
endmacro()
