# Dependency dispatcher.
#
# DEPENDENCY_MANAGER cache var picks the source of third-party libraries:
#   CPM    — fetch sources at configure time via CPM.cmake (default).
#   VCPKG  — expect a vcpkg toolchain file on the cmake command line:
#              cmake --preset clang-debug \
#                    -DDEPENDENCY_MANAGER=VCPKG \
#                    --toolchain=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
#            Manifest: ./vcpkg.json
#   CONAN  — expect a conan-generated toolchain (run `conan install` first):
#              conan install . --output-folder=build --build=missing
#              cmake --preset clang-debug \
#                    -DDEPENDENCY_MANAGER=CONAN \
#                    --toolchain=build/conan_toolchain.cmake
#            Manifest: ./conanfile.txt
#
# The two non-CPM modes use find_package(), and each dependency block in
# setup_dependencies() is gated by `if(NOT TARGET …)` so the find_package
# call from one mode satisfies the gate before the matching cpmaddpackage
# would otherwise run.

set(DEPENDENCY_MANAGER "CPM" CACHE STRING
    "Where to fetch third-party libraries: CPM | VCPKG | CONAN")
set_property(CACHE DEPENDENCY_MANAGER PROPERTY STRINGS CPM VCPKG CONAN)

if(DEPENDENCY_MANAGER STREQUAL "CPM")
  include(cmake/CPM.cmake)
elseif(DEPENDENCY_MANAGER STREQUAL "VCPKG" OR DEPENDENCY_MANAGER STREQUAL "CONAN")
  message(STATUS "DEPENDENCY_MANAGER=${DEPENDENCY_MANAGER} — using find_package() for all dependencies")
else()
  message(FATAL_ERROR
    "Unknown DEPENDENCY_MANAGER='${DEPENDENCY_MANAGER}'. Use CPM, VCPKG, or CONAN.")
endif()


# Resolve a single dependency. Either fetches via CPM or calls find_package
# depending on DEPENDENCY_MANAGER. `cpm_args` is the full argument list that
# would be passed to cpmaddpackage(); `find_args` is what to pass to
# find_package() (typically just NAME [VERSION]).
#
# Usage:
#   _resolve_dependency(
#     IF_NOT_TARGET fmt::fmt
#     CPM           NAME fmt GITHUB_REPOSITORY fmtlib/fmt GIT_TAG 12.1.0 SYSTEM YES
#     FIND_PACKAGE  fmt CONFIG)
function(_resolve_dependency)
  cmake_parse_arguments(PARSE_ARGV 0 _ARG
    ""                       # no flags
    "IF_NOT_TARGET"          # one-value
    "CPM;FIND_PACKAGE")      # multi-value

  if(TARGET ${_ARG_IF_NOT_TARGET})
    return()
  endif()

  if(DEPENDENCY_MANAGER STREQUAL "CPM")
    cpmaddpackage(${_ARG_CPM})
  else()
    find_package(${_ARG_FIND_PACKAGE} REQUIRED)
  endif()
endfunction()


# Done as a function so that updates to variables like CMAKE_CXX_FLAGS
# don't propagate out to other targets.
function(setup_dependencies)

  _resolve_dependency(
    IF_NOT_TARGET fmt::fmt
    CPM           NAME fmt GITHUB_REPOSITORY "fmtlib/fmt" GIT_TAG 12.1.0 SYSTEM YES
    FIND_PACKAGE  fmt CONFIG)

  _resolve_dependency(
    IF_NOT_TARGET spdlog::spdlog
    CPM           NAME spdlog VERSION 1.17.0 GITHUB_REPOSITORY "gabime/spdlog" SYSTEM YES
                  OPTIONS "SPDLOG_FMT_EXTERNAL ON"
    FIND_PACKAGE  spdlog CONFIG)

  if(ENABLE_GTEST)
    _resolve_dependency(
      IF_NOT_TARGET GTest::gtest_main
      CPM           NAME googletest GITHUB_REPOSITORY "google/googletest" GIT_TAG v1.15.2 SYSTEM YES
                    OPTIONS "INSTALL_GTEST OFF" "BUILD_GMOCK ON" "gtest_force_shared_crt ON"
      FIND_PACKAGE  GTest CONFIG)
  endif()

  if(ENABLE_CATCH2)
    _resolve_dependency(
      IF_NOT_TARGET Catch2::Catch2WithMain
      CPM           NAME Catch2 VERSION 3.12.0 GITHUB_REPOSITORY "catchorg/Catch2" SYSTEM YES
      FIND_PACKAGE  Catch2 3 CONFIG)
  endif()

  _resolve_dependency(
    IF_NOT_TARGET CLI11::CLI11
    CPM           NAME CLI11 VERSION 2.6.1 GITHUB_REPOSITORY "CLIUtils/CLI11" SYSTEM YES
    FIND_PACKAGE  CLI11 CONFIG)

  if(ENABLE_BENCHMARKS)
    _resolve_dependency(
      IF_NOT_TARGET benchmark::benchmark
      CPM           NAME benchmark VERSION 1.9.0 GITHUB_REPOSITORY "google/benchmark" SYSTEM YES
                    OPTIONS "BENCHMARK_ENABLE_TESTING OFF" "BENCHMARK_ENABLE_INSTALL OFF"
      FIND_PACKAGE  benchmark CONFIG)
  endif()

endfunction()
