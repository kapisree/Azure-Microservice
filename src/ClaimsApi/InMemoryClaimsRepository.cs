namespace ClaimsApi;

public class InMemoryClaimsRepository : IClaimsRepository
{
    private readonly List<Claim> _claims = new()
    {
        new Claim(Guid.Parse("3fa85f64-5717-4562-b3fc-2c963f66afa6"), ClaimStatus.Submitted, DateTimeOffset.UtcNow),
        new Claim(Guid.Parse("7c9e6679-7425-40de-944b-e07fc1f90ae7"), ClaimStatus.UnderReview, DateTimeOffset.UtcNow),
        new Claim(Guid.Parse("f47ac10b-58cc-4372-a567-0e02b2c3d479"), ClaimStatus.Approved, DateTimeOffset.UtcNow),
        new Claim(Guid.Parse("9b2e815c-5a91-4d5c-8b16-13b8b1b3c3a1"), ClaimStatus.Denied, DateTimeOffset.UtcNow),
        new Claim(Guid.Parse("d290f1ee-6c54-4b01-90e6-d701748f0851"), ClaimStatus.Paid, DateTimeOffset.UtcNow)
    };

    public Claim? GetById(Guid claimId) => _claims.SingleOrDefault(c => c.ClaimId == claimId);

    public IReadOnlyList<Claim> GetAll() => _claims;
}
