namespace ClaimsApi;

public record Claim(Guid ClaimId, ClaimStatus Status, DateTimeOffset LastUpdated);
