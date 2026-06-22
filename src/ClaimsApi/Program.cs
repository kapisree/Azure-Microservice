using ClaimsApi;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<IClaimsRepository, InMemoryClaimsRepository>();
builder.Services.Configure<ApiKeySettings>(builder.Configuration.GetSection("ApiKey"));
var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

var claims = app.MapGroup("/claims").AddEndpointFilter<ApiKeyFilter>();

claims.MapGet("", (IClaimsRepository repository) =>
    Results.Ok(repository.GetAll().Select(c => new { claimId = c.ClaimId, status = c.Status.ToString(), lastUpdated = c.LastUpdated })));

claims.MapGet("/{claimId}", (string claimId, IClaimsRepository repository) =>
{
    if (!Guid.TryParse(claimId, out var id))
    {
        return Results.Problem(statusCode: StatusCodes.Status400BadRequest, detail: "The claimId route value is not a valid GUID.");
    }

    var claim = repository.GetById(id);
    if (claim is null)
    {
        return Results.Problem(statusCode: StatusCodes.Status404NotFound, detail: "No claim was found with the specified id.");
    }

    return Results.Ok(new { claimId = claim.ClaimId, status = claim.Status.ToString(), lastUpdated = claim.LastUpdated });
});

app.Run();

public partial class Program { }
