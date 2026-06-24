// Implements: REQ-200, REQ-201, REQ-202 (docs/specs/2026-05-28-demo-greeting-design.md)
namespace DemoGreeting;

public static class Greeting
{
    public static string Greet(string name)
    {
        if (name == "")
        {
            throw new ArgumentException("name must be non-empty");
        }
        return $"Hello, {name}!";
    }
}
