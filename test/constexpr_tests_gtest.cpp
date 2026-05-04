#include <gtest/gtest.h>

#include <myproject/sample_library.hpp>

// By default each check is a compile-time static_assert. Define
// RUNTIME_STATIC_ASSERT (the relaxed_constexpr_tests_gtest target does this)
// to convert them into runtime EXPECT_TRUE checks for debugging.
#ifdef RUNTIME_STATIC_ASSERT
#  define STATIC_CHECK(expr) EXPECT_TRUE(expr)
#else
#  define STATIC_CHECK(expr) static_assert(expr, #expr)
#endif


TEST(Factorial, IsComputedAtCompileTime)
{
  STATIC_CHECK(factorial_constexpr(0) == 1);
  STATIC_CHECK(factorial_constexpr(1) == 1);
  STATIC_CHECK(factorial_constexpr(2) == 2);
  STATIC_CHECK(factorial_constexpr(3) == 6);
  STATIC_CHECK(factorial_constexpr(10) == 3628800);
}
