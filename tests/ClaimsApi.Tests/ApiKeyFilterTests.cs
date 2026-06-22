using System.Net;
using System.Text.Json;
using Xunit;

namespace ClaimsApi.Tests;

public class ApiKeyFilterTests
{
    [Fact]
    public async Task GetClaims_WithValidKey_ReturnsOk()
    {
        using var factory = new ClaimsApiTestFactory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Api-Key", ClaimsApiTestFactory.TestApiKey);

        var response = await client.GetAsync("/claims");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetClaim_WithValidKeyAndKnownId_ReturnsOk()
    {
        using var factory = new ClaimsApiTestFactory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Api-Key", ClaimsApiTestFactory.TestApiKey);

        var response = await client.GetAsync("/claims/3fa85f64-5717-4562-b3fc-2c963f66afa6");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetClaims_WithMissingKey_ReturnsUnauthorizedProblemDetails()
    {
        using var factory = new ClaimsApiTestFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/claims");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Contains(response.Headers.WwwAuthenticate, h => h.Scheme == "ApiKey");
        var json = await response.Content.ReadAsStringAsync();
        var problem = JsonSerializer.Deserialize<JsonElement>(json);
        Assert.Equal("Missing or invalid API key.", problem.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task GetClaims_WithWrongKey_ReturnsSameUnauthorizedBodyAsMissingKey()
    {
        using var missingFactory = new ClaimsApiTestFactory();
        using var missingClient = missingFactory.CreateClient();
        var missingResponse = await missingClient.GetAsync("/claims");
        var missingBody = await missingResponse.Content.ReadAsStringAsync();

        using var wrongFactory = new ClaimsApiTestFactory();
        using var wrongClient = wrongFactory.CreateClient();
        wrongClient.DefaultRequestHeaders.Add("X-Api-Key", "definitely-not-the-key");
        var wrongResponse = await wrongClient.GetAsync("/claims");
        var wrongBody = await wrongResponse.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Unauthorized, wrongResponse.StatusCode);
        Assert.Equal(missingBody, wrongBody);
    }

    [Fact]
    public async Task GetClaim_WithInvalidGuidAndMissingKey_ReturnsUnauthorizedNotBadRequest()
    {
        using var factory = new ClaimsApiTestFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/claims/not-a-guid");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetHealth_WithNoKey_StillReturnsOk()
    {
        using var factory = new ClaimsApiTestFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public void Authorize_WithEmptyPresentedAndEmptyConfigured_MustNotAuthorize()
    {
        // SEC-006: CryptographicOperations.FixedTimeEquals treats two
        // zero-length spans as equal, so an empty configured key (the
        // appsettings.json production default) combined with a present
        // but empty X-Api-Key header must not authorize the caller.
        Assert.False(ApiKeyFilter.Authorize(string.Empty, string.Empty));
    }

    [Fact]
    public async Task GetClaims_WithEmptyConfiguredKeyAndEmptyPresentedKey_ReturnsUnauthorized()
    {
        using var factory = new ClaimsApiTestFactory(apiKeyValue: string.Empty);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Api-Key", string.Empty);

        var response = await client.GetAsync("/claims");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
