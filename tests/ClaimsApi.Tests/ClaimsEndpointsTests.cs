using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace ClaimsApi.Tests;

public class ClaimsEndpointsTests
{
    [Fact]
    public async Task GetClaim_WithNonGuidId_ReturnsBadRequestProblemDetails()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/claims/not-a-guid");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadAsStringAsync();
        var problem = JsonSerializer.Deserialize<JsonElement>(json);
        Assert.Contains("valid GUID", problem.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task GetClaim_WithUnknownId_ReturnsNotFoundProblemDetails()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync($"/claims/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var json = await response.Content.ReadAsStringAsync();
        var problem = JsonSerializer.Deserialize<JsonElement>(json);
        Assert.Contains("no claim", problem.GetProperty("detail").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task GetClaims_ReturnsOkWithAllFiveSeededClaims()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/claims");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await response.Content.ReadAsStringAsync();
        var body = JsonSerializer.Deserialize<JsonElement>(json);
        Assert.Equal(JsonValueKind.Array, body.ValueKind);
        Assert.Equal(5, body.GetArrayLength());
        var first = body[0];
        Assert.True(first.TryGetProperty("claimId", out _));
        Assert.True(first.TryGetProperty("status", out _));
        Assert.True(first.TryGetProperty("lastUpdated", out _));
    }

    [Fact]
    public async Task GetClaim_WithKnownSeedId_ReturnsOkWithClaimBody()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/claims/3fa85f64-5717-4562-b3fc-2c963f66afa6");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await response.Content.ReadAsStringAsync();
        var body = JsonSerializer.Deserialize<JsonElement>(json);
        Assert.Equal("3fa85f64-5717-4562-b3fc-2c963f66afa6", body.GetProperty("claimId").GetString());
        Assert.Equal("Submitted", body.GetProperty("status").GetString());
        Assert.True(body.TryGetProperty("lastUpdated", out _));
    }
}
