using System.Diagnostics;
using System.Text.RegularExpressions;

namespace RenderDoc.Tests;

public class RenderDocShellTests
{
    private static readonly string Root = DocRenderer.FindRepoRoot().FullName;

    private static string ToBashPath(string path)
    {
        var match = Regex.Match(path, @"^([A-Za-z]):[\\/](.*)$");
        if (!match.Success) return path.Replace('\\', '/');
        var drive = match.Groups[1].Value.ToLowerInvariant();
        var rest = match.Groups[2].Value.Replace('\\', '/');
        return $"/mnt/{drive}/{rest}";
    }

    private static (int ExitCode, string Stdout, string Stderr) RunScript(params string[] args)
    {
        var psi = new ProcessStartInfo("bash")
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        psi.ArgumentList.Add(ToBashPath(Path.Combine(Root, "scripts", "render-doc.sh")));
        foreach (var a in args) psi.ArgumentList.Add(ToBashPath(a));
        using var proc = Process.Start(psi)!;
        var stdout = proc.StandardOutput.ReadToEnd();
        var stderr = proc.StandardError.ReadToEnd();
        proc.WaitForExit();
        return (proc.ExitCode, stdout, stderr);
    }

    [Fact]
    public void RenderDocShExistsAndRuns()
    {
        Assert.True(File.Exists(Path.Combine(Root, "scripts", "render-doc.sh")));
        var (exitCode, _, _) = RunScript();
        Assert.Equal(0, exitCode);
    }

    [Fact]
    public void RenderDocShSkipsNonexistentFile()
    {
        var missing = Path.Combine(Path.GetTempPath(), "render-doc-nope-" + Guid.NewGuid() + ".md");
        var (exitCode, _, _) = RunScript(missing);
        Assert.Equal(0, exitCode);
    }
}
