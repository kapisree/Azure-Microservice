// verification/example.dfy
// Proves: REQ-000
//
// Example: a token-based authentication contract model.
// This proof verifies that Authenticate() returns the correct result
// for all possible inputs — not just test cases.
//
// To verify: dafny verify verification/example.dfy

// Precondition: what makes a token valid
predicate ValidToken(token: string)
{
  |token| >= 32 && forall i :: 0 <= i < |token| ==>
    ('A' <= token[i] <= 'Z') || ('a' <= token[i] <= 'z') || ('0' <= token[i] <= '9')
}

// Result type
datatype AuthResult =
  | Authenticated(userId: string)
  | Rejected(statusCode: int)

// External dependency: modeled with a contract, not implemented.
// We assume LookupUser returns a non-empty userId for valid tokens.
// If this assumption is wrong, the runtime contract catches it.
method {:extern} {:axiom} LookupUser(token: string) returns (userId: string)
  requires ValidToken(token)
  ensures |userId| > 0

// The contract we're proving:
// - Valid token → Authenticated with non-empty userId
// - Invalid token → Rejected with 401
method Authenticate(token: string) returns (result: AuthResult)
  ensures ValidToken(token) ==> result.Authenticated? && |result.userId| > 0
  ensures !ValidToken(token) ==> result.Rejected? && result.statusCode == 401
{
  if ValidToken(token) {
    var userId := LookupUser(token);
    result := Authenticated(userId);
  } else {
    result := Rejected(401);
  }
}

// Lemma example: prove that empty tokens are always invalid.
// This is a helper fact that could support more complex proofs.
lemma EmptyTokenInvalid()
  ensures !ValidToken("")
{
  // Dafny proves this automatically from the |token| >= 32 predicate
}

// Lemma with decreases: prove a property about token prefixes.
// Demonstrates termination metrics for recursive proofs.
lemma AllCharsAlphanumeric(token: string, i: int)
  requires ValidToken(token)
  requires 0 <= i < |token|
  ensures ('A' <= token[i] <= 'Z') || ('a' <= token[i] <= 'z') || ('0' <= token[i] <= '9')
  decreases |token| - i
{
  // Follows directly from ValidToken predicate — Dafny verifies automatically
}
