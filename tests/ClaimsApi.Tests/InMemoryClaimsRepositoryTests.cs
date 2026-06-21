using Xunit;

namespace ClaimsApi.Tests;

public class InMemoryClaimsRepositoryTests
{
    [Fact]
    public void GetAll_ReturnsAllFiveSeededClaims()
    {
        var repository = new InMemoryClaimsRepository();

        var claims = repository.GetAll();

        Assert.Equal(5, claims.Count);
    }

    [Fact]
    public void GetById_WithKnownSeedId_ReturnsExpectedClaim()
    {
        var repository = new InMemoryClaimsRepository();
        var id = Guid.Parse("3fa85f64-5717-4562-b3fc-2c963f66afa6");

        var claim = repository.GetById(id);

        Assert.NotNull(claim);
        Assert.Equal(id, claim!.ClaimId);
        Assert.Equal(ClaimStatus.Submitted, claim.Status);
    }

    [Fact]
    public void GetById_WithUnknownId_ReturnsNull()
    {
        var repository = new InMemoryClaimsRepository();

        var claim = repository.GetById(Guid.NewGuid());

        Assert.Null(claim);
    }
}
