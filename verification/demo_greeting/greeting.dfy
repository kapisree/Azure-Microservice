// Proves: REQ-200
// REQ-200 verified: output starts with "Hello, ", ends with "!", length == 8 + |name|.

method Greet(name: string) returns (s: string)
  requires |name| > 0
  ensures |s| == 8 + |name|
  ensures s[..7] == "Hello, "
  ensures s[|s| - 1] == '!'
{
  s := "Hello, " + name + "!";
}
