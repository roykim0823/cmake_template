if(NOT ENABLE_GTEST AND NOT ENABLE_CATCH2)
  message(FATAL_ERROR
    "BUILD_TESTING is on but no test framework is selected. "
    "Set -DENABLE_GTEST=ON and/or -DENABLE_CATCH2=ON.")
endif()

# ---- CLI smoke tests (framework-agnostic) ----

# Smoke test that the CLI displays a --help message.
add_test(NAME cli.has_help COMMAND app --help)

# Verify the version reported by the application matches the CMake version.
add_test(NAME cli.version_matches COMMAND app --version)
set_tests_properties(cli.version_matches PROPERTIES PASS_REGULAR_EXPRESSION "${PROJECT_VERSION}")

# CMake-script regression tests for cmake/Sanitizers.cmake (issue #141).
add_test(
  NAME cmake.sanitizers.apple_excludes_leak
  COMMAND ${CMAKE_COMMAND} -P
          ${CMAKE_CURRENT_SOURCE_DIR}/cmake/test_sanitizers_apple_excludes_leak.cmake)
add_test(
  NAME cmake.sanitizers.non_apple_includes_leak
  COMMAND ${CMAKE_COMMAND} -P
          ${CMAKE_CURRENT_SOURCE_DIR}/cmake/test_sanitizers_non_apple_includes_leak.cmake)

# ---- Helper: build a test executable wired to the project's targets. ----
function(_add_framework_test_executable name source)
  add_executable(${name} ${source})
  target_link_libraries(${name}
    PRIVATE ${PROJECT_NAME}::warnings
            ${PROJECT_NAME}::options
            ${PROJECT_NAME}::sample_library
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

  # gmock demo — uses GTest::gmock_main (which initialises gtest + gmock).
  _add_framework_test_executable(mock_test_gtest mock_test_gtest.cpp GTest::gmock_main)
  gtest_discover_tests(mock_test_gtest TEST_PREFIX "gtest.mock." DISCOVERY_MODE PRE_TEST)
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
endif()
