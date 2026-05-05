// A minimal gmock demo. It defines an interface, mocks it, and uses
// EXPECT_CALL to verify how a function-under-test interacts with the
// dependency. No production code is touched — the interface here exists
// purely to demonstrate the mocking pattern.

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <string>
#include <string_view>


// An interface a real piece of code might depend on (e.g. a logger or
// output sink).
class MessageSink
{
public:
  virtual ~MessageSink() = default;
  virtual void write(std::string_view message) = 0;
  virtual int flush() = 0;
};


// gmock generates the implementation from the MOCK_METHOD macros.
class MockMessageSink : public MessageSink
{
public:
  MOCK_METHOD(void, write, (std::string_view message), (override));
  MOCK_METHOD(int, flush, (), (override));
};


// Function under test — depends on MessageSink.
inline void greet(MessageSink &sink, std::string_view name)
{
  sink.write("Hello, ");
  sink.write(name);
  sink.flush();
}


using ::testing::_;
using ::testing::Eq;
using ::testing::InSequence;
using ::testing::Return;


TEST(GreetTest, WritesGreetingThenName)
{
  MockMessageSink sink;
  InSequence seq;// expect the calls in this exact order

  EXPECT_CALL(sink, write(Eq("Hello, ")));
  EXPECT_CALL(sink, write(Eq("Alice")));
  EXPECT_CALL(sink, flush()).WillOnce(Return(0));

  greet(sink, "Alice");
}


TEST(GreetTest, FlushReturnIsObservable)
{
  MockMessageSink sink;
  EXPECT_CALL(sink, write(_)).Times(2);// don't care about content
  EXPECT_CALL(sink, flush()).WillOnce(Return(42));

  greet(sink, "Bob");
  // gmock auto-verifies all EXPECT_CALLs at teardown — nothing to assert.
}
