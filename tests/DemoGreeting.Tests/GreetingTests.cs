// Covers: REQ-200, REQ-201, REQ-202
using DemoGreeting;

namespace DemoGreeting.Tests;

public class GreetingTests
{
    [Fact]
    public void GreetWorld()
    {
        Assert.Equal("Hello, World!", Greeting.Greet("World"));
    }

    [Fact]
    public void GreetEmptyThrows()
    {
        Assert.Throws<ArgumentException>(() => Greeting.Greet(""));
    }
}
