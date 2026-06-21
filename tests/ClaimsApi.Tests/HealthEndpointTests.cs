using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace ClaimsApi.Tests;

public class HealthEndpointTests
{
    [Fact]
    public async Task GetHealth_ReturnsOkWithHealthyStatus()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<HealthResponse>();
        Assert.NotNull(body);
        Assert.Equal("healthy", body!.Status);
    }

    private sealed class HealthResponse
    {
        public string? Status { get; set; }
    }
}
