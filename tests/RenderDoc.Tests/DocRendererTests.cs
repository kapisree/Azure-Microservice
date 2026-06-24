using System.Text.Json.Nodes;
using RenderDoc;

namespace RenderDoc.Tests;

public class DocRendererTests : IDisposable
{
    private const string SampleMd = """
        ---
        type: capability_spec
        phase: SPEC
        ---

        # Auth Capability

        ## Acceptance Criteria
        - AC-1: Authenticate with Auth0 (vendor lock-in risk)
        - AC-2: assumed availability of refresh tokens
        """;

    private readonly DirectoryInfo _tmp;

    public DocRendererTests()
    {
        _tmp = new DirectoryInfo(Path.Combine(Path.GetTempPath(), "render-doc-tests-" + Guid.NewGuid()));
        _tmp.Create();
    }

    public void Dispose() => _tmp.Delete(recursive: true);

    [Fact]
    public void RenderWritesHtml()
    {
        var src = new FileInfo(Path.Combine(_tmp.FullName, "spec.md"));
        File.WriteAllText(src.FullName, SampleMd);
        var dashboard = new DirectoryInfo(Path.Combine(_tmp.FullName, "dashboard"));
        dashboard.Create();

        var renderer = new DocRenderer(DocRenderer.FindRepoRoot())
        {
            OutputDir = dashboard,
            CallSonnet = (_, _) =>
            {
                var result = new JsonObject
                {
                    ["html"] = "<!doctype html><html><body><h1>Auth</h1></body></html>",
                    ["flags"] = new JsonObject { ["risks"] = 1, ["assumptions"] = 1, ["decisions"] = 0 },
                    ["title"] = "Auth Capability",
                    ["type"] = "capability_spec",
                };
                return result;
            },
        };

        var outFile = renderer.Render(src);
        Assert.NotNull(outFile);
        Assert.True(outFile!.Exists);
        Assert.StartsWith("<!doctype html>", File.ReadAllText(outFile.FullName));
    }

    [Fact]
    public void RenderSkipsMissingSource()
    {
        var src = new FileInfo(Path.Combine(_tmp.FullName, "missing.md"));
        var dashboard = new DirectoryInfo(Path.Combine(_tmp.FullName, "dashboard"));
        dashboard.Create();

        var called = false;
        var renderer = new DocRenderer(DocRenderer.FindRepoRoot())
        {
            OutputDir = dashboard,
            CallSonnet = (_, _) => { called = true; return new JsonObject(); },
        };

        Assert.Null(renderer.Render(src));
        Assert.False(called);
    }
}
