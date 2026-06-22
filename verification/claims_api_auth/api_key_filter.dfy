// Proves: REQ-309
// REQ-309 verified: auth (Authorize predicate) takes precedence over
// route-level validation (claimId GUID parsing) — a request with a
// missing/wrong key and an invalid claimId always returns Unauthorized,
// never BadRequest. Also verified (SEC-006 fix): an empty configured key
// can never be satisfied by any presented value, including an empty one
// — closes the fail-open case where presented == configured == "".

datatype Response = Unauthorized | BadRequest | Authorized

predicate Authorize(presented: string, configured: string)
{
  |configured| > 0 && |presented| > 0 && presented == configured
}

lemma EmptyConfiguredNeverAuthorizes(presented: string, configured: string)
  requires configured == ""
  ensures !Authorize(presented, configured)
{
}

method HandleRequest(presented: string, configured: string, claimIdIsValidGuid: bool) returns (r: Response)
  ensures !Authorize(presented, configured) ==> r == Unauthorized
  ensures Authorize(presented, configured) && !claimIdIsValidGuid ==> r == BadRequest
  ensures Authorize(presented, configured) && claimIdIsValidGuid ==> r == Authorized
{
  if !Authorize(presented, configured) {
    r := Unauthorized;
  } else if !claimIdIsValidGuid {
    r := BadRequest;
  } else {
    r := Authorized;
  }
}
