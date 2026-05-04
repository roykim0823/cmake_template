#include <gtest/gtest.h>

#include <myproject/sample_library.hpp>


TEST(Factorial, IsComputedAtRuntime)
{
  EXPECT_EQ(factorial(0), 1);
  EXPECT_EQ(factorial(1), 1);
  EXPECT_EQ(factorial(2), 2);
  EXPECT_EQ(factorial(3), 6);
  EXPECT_EQ(factorial(10), 3628800);
}
