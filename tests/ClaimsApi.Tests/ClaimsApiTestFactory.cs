using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace ClaimsApi.Tests;

public class ClaimsApiTestFactory : WebApplicationFactory<Program>
{
    public const string TestApiKey = "xunit-test-api-key";

    protected override void ConfigureWebHost(Microsoft.AspNetCore.Hosting.IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, config) =>
            config.AddInMemoryCollection(new[]
            {
                new KeyValuePair<string, string?>("ApiKey:Value", TestApiKey)
            }));
    }
}
