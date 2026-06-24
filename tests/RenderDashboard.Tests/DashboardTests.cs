// Covers: REQ-001, REQ-002
using RenderDashboard;

namespace RenderDashboard.Tests;

public class DashboardTests : IDisposable
{
    private readonly DirectoryInfo _root;

    public DashboardTests()
    {
        _root = new DirectoryInfo(Path.Combine(Path.GetTempPath(), "dashboard-tests-" + Guid.NewGuid()));
        var specs = Directory.CreateDirectory(Path.Combine(_root.FullName, "docs", "specs"));
        File.WriteAllText(Path.Combine(specs.FullName, "design.md"),
            "---\ntype: spec\nphase: SPEC\nstatus: approved\n---\n" +
            "# Design Spec\n\n" +
            "### REQ-001: User can log in\n" +
            "Users must be able to authenticate.\n\n" +
            "### REQ-002: User can view dashboard\n" +
            "Authenticated users see their dashboard.\n");

        var plans = Directory.CreateDirectory(Path.Combine(_root.FullName, "docs", "plans"));
        File.WriteAllText(Path.Combine(plans.FullName, "plan-1.md"),
            "---\ntype: plan\nphase: PLAN\nstatus: approved\n---\n" +
            "# Plan 1: Auth\n\n" +
            "### TASK-001: Implement login endpoint\n" +
            "Implements: REQ-001\n\n" +
            "### TASK-002: Build dashboard page\n" +
            "Implements: REQ-002\n");

        var src = Directory.CreateDirectory(Path.Combine(_root.FullName, "src"));
        File.WriteAllText(Path.Combine(src.FullName, "auth.py"), "# Task: TASK-001\ndef login(): pass\n");
        File.WriteAllText(Path.Combine(src.FullName, "dashboard.py"), "# Task: TASK-002\ndef render(): pass\n");

        var tests = Directory.CreateDirectory(Path.Combine(_root.FullName, "tests"));
        File.WriteAllText(Path.Combine(tests.FullName, "test_auth.py"), "# Covers: TASK-001\ndef test_login(): pass\n");

        Directory.CreateDirectory(Path.Combine(_root.FullName, "docs", "dashboard"));
    }

    public void Dispose() => _root.Delete(recursive: true);

    [Fact]
    public void ParseIdsFromSpec()
    {
        var ids = Dashboard.ParseRequirementIds(new FileInfo(Path.Combine(_root.FullName, "docs", "specs", "design.md")));
        Assert.Contains("REQ-001", ids);
        Assert.Contains("REQ-002", ids);
    }

    [Fact]
    public void ParseTaskImplements()
    {
        var refs = Dashboard.ParseTaskReferences(new FileInfo(Path.Combine(_root.FullName, "docs", "plans", "plan-1.md")));
        Assert.Equal(new[] { "REQ-001" }, refs["TASK-001"]);
        Assert.Equal(new[] { "REQ-002" }, refs["TASK-002"]);
    }

    [Fact]
    public void ParseSourceTaskRefs()
    {
        var refs = Dashboard.ParseSourceReferences(new DirectoryInfo(Path.Combine(_root.FullName, "src")));
        Assert.Contains(refs.Keys, k => k.Contains("auth.py"));
    }

    [Fact]
    public void BuildTraceabilityMatrix()
    {
        var matrix = Dashboard.BuildTraceability(_root);
        Assert.Contains("REQ-001", matrix.Keys);
        Assert.Contains("TASK-001", matrix["REQ-001"].Tasks.Keys);
    }

    [Fact]
    public void ParseDafnyProves()
    {
        var verif = Directory.CreateDirectory(Path.Combine(_root.FullName, "verification"));
        File.WriteAllText(Path.Combine(verif.FullName, "auth.dfy"),
            "// verification/auth.dfy\n// Proves: REQ-001\npredicate ValidToken(token: string) { |token| >= 32 }\n");

        var status = Dashboard.ParseVerificationStatus(verif);
        Assert.Contains("REQ-001", status.Keys);
        Assert.Equal("auth.dfy", status["REQ-001"].File);
    }

    [Fact]
    public void TraceabilityIncludesVerification()
    {
        var verif = Directory.CreateDirectory(Path.Combine(_root.FullName, "verification"));
        File.WriteAllText(Path.Combine(verif.FullName, "auth.dfy"),
            "// verification/auth.dfy\n// Proves: REQ-001\npredicate ValidToken(token: string) { |token| >= 32 }\n");

        var matrix = Dashboard.BuildTraceability(_root);
        Assert.Contains("REQ-001", matrix.Keys);
        Assert.NotNull(matrix["REQ-001"].Verification);
        Assert.Equal("auth.dfy", matrix["REQ-001"].Verification!.File);
        Assert.Null(matrix["REQ-002"].Verification);
    }
}
