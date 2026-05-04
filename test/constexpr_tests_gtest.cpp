#include <gtest/gtest.h>

#include <myproject/sample_library.hpp>


// These checks fire at compile time. If `factorial_constexpr` ever returns
// the wrong value for a constant, the file fails to compile.
TEST(Factorial, IsComputedAtCompileTime)
{
  static_assert(factorial_constexpr(0) == 1);
  static_assert(factorial_constexpr(1) == 1);
  static_assert(factorial_constexpr(2) == 2);
  static_assert(factorial_constexpr(3) == 6);
  static_assert(factorial_constexpr(10) == 3628800);
}
