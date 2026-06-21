namespace ClaimsApi;

public interface IClaimsRepository
{
    Claim? GetById(Guid claimId);
    IReadOnlyList<Claim> GetAll();
}
