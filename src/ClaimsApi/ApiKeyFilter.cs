using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace ClaimsApi;

public class ApiKeySettings
{
    public string Value { get; set; } = string.Empty;
}

public class ApiKeyFilter : IEndpointFilter
{
    private readonly IOptions<ApiKeySettings> _settings;

    public ApiKeyFilter(IOptions<ApiKeySettings> settings)
    {
        _settings = settings;
    }

    public static bool Authorize(string? presented, string configured)
    {
        if (string.IsNullOrEmpty(presented) || string.IsNullOrEmpty(configured))
        {
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(presented),
            Encoding.UTF8.GetBytes(configured));
    }

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var presented = context.HttpContext.Request.Headers["X-Api-Key"].FirstOrDefault();
        var configured = _settings.Value.Value;

        if (!Authorize(presented, configured))
        {
            var result = Results.Problem(statusCode: StatusCodes.Status401Unauthorized, detail: "Missing or invalid API key.");
            context.HttpContext.Response.Headers.WWWAuthenticate = "ApiKey realm=\"claims-api\"";
            return result;
        }

        return await next(context);
    }
}
