cmake_minimum_required(VERSION 3.15...3.23)

project(CmakeConfigPackageTests
  VERSION ${PROJECT_VERSION}
  LANGUAGES CXX)

# ---- Test as standalone project the exported config package ----

if(PROJECT_IS_TOP_LEVEL OR TEST_INSTALLED_VERSION)
  enable_testing()

  find_package(myproject CONFIG REQUIRED) # for intro, project_options, ...

  if(NOT TARGET options)
    message(FATAL_ERROR "Required config package not found!")
    return() # be strictly paranoid for Template Janitor github action! CK
  endif()
endif()

if(NOT ENABLE_GTEST AND NOT ENABLE_CATCH2)
  message(FATAL_ERROR
    "BUILD_TESTING is on but no test framework is selected. "
    "Set -DENABLE_GTEST=ON and/or -DENABLE_CATCH2=ON.")
endif()

# ---- CLI smoke tests (framework-agnostic) ----

# Provide a simple smoke test to make sure that the CLI works and can display a --help message
add_test(NAME cli.has_help COMMAND intro --help)

# CMake-script regression tests for cmake/Sanitizers.cmake (issue #141).
add_test(
  NAME cmake.sanitizers.apple_excludes_leak
  COMMAND ${CMAKE_COMMAND} -P
          ${CMAKE_CURRENT_SOURCE_DIR}/cmake/test_sanitizers_apple_excludes_leak.cmake)
add_test(
  NAME cmake.sanitizers.non_apple_includes_leak
  COMMAND ${CMAKE_COMMAND} -P
          ${CMAKE_CURRENT_SOURCE_DIR}/cmake/test_sanitizers_non_apple_includes_leak.cmake)

# Provide a test to verify that the version being reported from the application
# matches the version given to CMake. This will be important once you package
# your program. Real world shows that this is the kind of simple mistake that is easy
# to make, but also easy to test for.
add_test(NAME cli.version_matches COMMAND intro --version)
set_tests_properties(cli.version_matches PROPERTIES PASS_REGULAR_EXPRESSION "${PROJECT_VERSION}")

# ---- Helper: build a test executable wired to the project's targets. ----
function(_add_framework_test_executable name source)
  add_executable(${name} ${source})
  target_link_libraries(${name}
    PRIVATE myproject::warnings
            myproject::options
            myproject::sample_library
            ${ARGN})
  configure_linker(${name})
endfunction()

# ---- Google Test (default) ----
if(ENABLE_GTEST)
  include(GoogleTest)

  _add_framework_test_executable(tests_gtest tests_gtest.cpp GTest::gtest_main)
  gtest_discover_tests(tests_gtest TEST_PREFIX "gtest.unittests." DISCOVERY_MODE PRE_TEST)

  _add_framework_test_executable(constexpr_tests_gtest constexpr_tests_gtest.cpp GTest::gtest_main)
  gtest_discover_tests(constexpr_tests_gtest TEST_PREFIX "gtest.constexpr." DISCOVERY_MODE PRE_TEST)

  # Same source compiled with RUNTIME_STATIC_ASSERT so static_asserts become
  # runtime EXPECT_TRUEs — useful when debugging a constexpr regression.
  _add_framework_test_executable(relaxed_constexpr_tests_gtest constexpr_tests_gtest.cpp GTest::gtest_main)
  target_compile_definitions(relaxed_constexpr_tests_gtest PRIVATE RUNTIME_STATIC_ASSERT)
  gtest_discover_tests(relaxed_constexpr_tests_gtest TEST_PREFIX "gtest.relaxed_constexpr." DISCOVERY_MODE PRE_TEST)
endif()

# ---- Catch2 (optional) ----
if(ENABLE_CATCH2)
  include(${Catch2_SOURCE_DIR}/extras/Catch.cmake)

  _add_framework_test_executable(tests_catch2 tests_catch2.cpp Catch2::Catch2WithMain)
  catch_discover_tests(
    tests_catch2
    TEST_PREFIX
    "catch2.unittests."
    REPORTER
    XML
    OUTPUT_DIR
    .
    OUTPUT_PREFIX
    "catch2.unittests."
    OUTPUT_SUFFIX
    .xml)

  _add_framework_test_executable(constexpr_tests_catch2 constexpr_tests_catch2.cpp Catch2::Catch2WithMain)
  catch_discover_tests(
    constexpr_tests_catch2
    TEST_PREFIX
    "catch2.constexpr."
    REPORTER
    XML
    OUTPUT_DIR
    .
    OUTPUT_PREFIX
    "catch2.constexpr."
    OUTPUT_SUFFIX
    .xml)

  # Same source with CATCH_CONFIG_RUNTIME_STATIC_REQUIRE so STATIC_REQUIRE
  # checks fire at runtime — useful when debugging a constexpr regression.
  _add_framework_test_executable(relaxed_constexpr_tests_catch2 constexpr_tests_catch2.cpp Catch2::Catch2WithMain)
  target_compile_definitions(relaxed_constexpr_tests_catch2 PRIVATE -DCATCH_CONFIG_RUNTIME_STATIC_REQUIRE)
  catch_discover_tests(
    relaxed_constexpr_tests_catch2
    TEST_PREFIX
    "catch2.relaxed_constexpr."
    REPORTER
    XML
    OUTPUT_DIR
    .
    OUTPUT_PREFIX
    "catch2.relaxed_constexpr."
    OUTPUT_SUFFIX
    .xml)
endif()
