// Generate a static pipeline dashboard from git state and doc traceability.
using System.Diagnostics;
using System.Text.RegularExpressions;

namespace RenderDashboard;

public record VerificationInfo(string File, string Path);

public class TaskEntry
{
    public string Plan { get; init; } = "";
    public List<string> SourceFiles { get; } = new();
    public List<string> TestFiles { get; } = new();
}

public class ReqEntry
{
    public string Source { get; init; } = "unknown";
    public Dictionary<string, TaskEntry> Tasks { get; } = new();
    public List<string> Warnings { get; } = new();
    public VerificationInfo? Verification { get; set; }
}

public static class Dashboard
{
    private static readonly Regex ImplementsPattern = new(@"Implements:\s*((?:(?:REQ|TASK)-\d{3}(?:,\s*)?)+)");
    private static readonly Regex TaskRefPattern = new(@"#\s*Task:\s*(TASK-\d{3})");
    private static readonly Regex CoversPattern = new(@"#\s*Covers:\s*((?:(?:REQ|TASK)-\d{3}(?:,\s*)?)+)");
    private static readonly Regex ProvesPattern = new(@"//\s*Proves:\s*((?:REQ-\d{3}(?:,\s*)?)+)");
    private static readonly string[] SourceExtensions = { ".py", ".ts", ".tsx", ".js", ".jsx", ".go", ".cs" };

    public static List<string> ParseRequirementIds(FileInfo specPath)
    {
        var text = File.ReadAllText(specPath.FullName);
        return Regex.Matches(text, @"REQ-\d{3}").Select(m => m.Value).Distinct().OrderBy(x => x).ToList();
    }

    public static Dictionary<string, List<string>> ParseTaskReferences(FileInfo planPath)
    {
        var text = File.ReadAllText(planPath.FullName);
        var refs = new Dictionary<string, List<string>>();
        string? currentTask = null;
        foreach (var line in text.Split('\n'))
        {
            var taskMatch = Regex.Match(line, @"(TASK-\d{3})");
            if (taskMatch.Success && line.TrimStart().StartsWith("#"))
            {
                currentTask = taskMatch.Groups[1].Value;
                refs[currentTask] = new List<string>();
            }
            var implMatch = ImplementsPattern.Match(line);
            if (implMatch.Success && currentTask != null)
            {
                var ids = Regex.Matches(implMatch.Groups[1].Value, @"(?:REQ|TASK)-\d{3}").Select(m => m.Value);
                refs[currentTask] = ids.Where(i => i.StartsWith("REQ")).ToList();
            }
        }
        return refs;
    }

    public static Dictionary<string, string> ParseSourceReferences(DirectoryInfo srcDir)
    {
        var refs = new Dictionary<string, string>();
        if (!srcDir.Exists) return refs;
        foreach (var f in srcDir.GetFiles("*", SearchOption.AllDirectories))
        {
            if (!SourceExtensions.Contains(f.Extension)) continue;
            string[] firstLines;
            try { firstLines = File.ReadAllLines(f.FullName).Take(5).ToArray(); }
            catch (IOException) { continue; }
            foreach (var line in firstLines)
            {
                var m = TaskRefPattern.Match(line);
                if (m.Success)
                {
                    refs[Path.GetRelativePath(srcDir.Parent!.FullName, f.FullName)] = m.Groups[1].Value;
                    break;
                }
            }
        }
        return refs;
    }

    public static Dictionary<string, List<string>> ParseTestReferences(DirectoryInfo testsDir)
    {
        var refs = new Dictionary<string, List<string>>();
        if (!testsDir.Exists) return refs;
        foreach (var f in testsDir.GetFiles("*", SearchOption.AllDirectories))
        {
            if (!f.Name.StartsWith("test_") && !f.Name.EndsWith("Tests.cs")) continue;
            string[] firstLines;
            try { firstLines = File.ReadAllLines(f.FullName).Take(5).ToArray(); }
            catch (IOException) { continue; }
            foreach (var line in firstLines)
            {
                var m = CoversPattern.Match(line);
                if (m.Success)
                {
                    var ids = Regex.Matches(m.Groups[1].Value, @"(?:REQ|TASK)-\d{3}").Select(x => x.Value).ToList();
                    refs[Path.GetRelativePath(testsDir.Parent!.FullName, f.FullName)] = ids;
                    break;
                }
            }
        }
        return refs;
    }

    public static Dictionary<string, VerificationInfo> ParseVerificationStatus(DirectoryInfo verifDir)
    {
        var status = new Dictionary<string, VerificationInfo>();
        if (!verifDir.Exists) return status;
        foreach (var f in verifDir.GetFiles("*.dfy"))
        {
            string[] firstLines;
            try { firstLines = File.ReadAllLines(f.FullName).Take(5).ToArray(); }
            catch (IOException) { continue; }
            foreach (var line in firstLines)
            {
                var m = ProvesPattern.Match(line);
                if (m.Success)
                {
                    foreach (var reqId in Regex.Matches(m.Groups[1].Value, @"REQ-\d{3}").Select(x => x.Value))
                    {
                        status[reqId] = new VerificationInfo(f.Name, f.FullName);
                    }
                    break;
                }
            }
        }
        return status;
    }

    public static Dictionary<string, ReqEntry> BuildTraceability(DirectoryInfo projectRoot)
    {
        var matrix = new Dictionary<string, ReqEntry>();
        var specsDir = new DirectoryInfo(Path.Combine(projectRoot.FullName, "docs", "specs"));
        if (specsDir.Exists)
        {
            foreach (var spec in specsDir.GetFiles("*.md"))
            {
                foreach (var reqId in ParseRequirementIds(spec))
                {
                    matrix[reqId] = new ReqEntry { Source = spec.Name };
                }
            }
        }

        var plansDir = new DirectoryInfo(Path.Combine(projectRoot.FullName, "docs", "plans"));
        if (plansDir.Exists)
        {
            foreach (var plan in plansDir.GetFiles("*.md"))
            {
                foreach (var (taskId, reqIds) in ParseTaskReferences(plan))
                {
                    foreach (var reqId in reqIds)
                    {
                        if (!matrix.ContainsKey(reqId))
                        {
                            matrix[reqId] = new ReqEntry { Source = "unknown" };
                        }
                        matrix[reqId].Tasks[taskId] = new TaskEntry { Plan = plan.Name };
                    }
                }
            }
        }

        var srcRefs = ParseSourceReferences(new DirectoryInfo(Path.Combine(projectRoot.FullName, "src")));
        foreach (var (filePath, taskId) in srcRefs)
        {
            foreach (var data in matrix.Values)
            {
                if (data.Tasks.TryGetValue(taskId, out var taskData))
                {
                    taskData.SourceFiles.Add(filePath);
                }
            }
        }

        var testRefs = ParseTestReferences(new DirectoryInfo(Path.Combine(projectRoot.FullName, "tests")));
        foreach (var (filePath, coveredIds) in testRefs)
        {
            foreach (var covId in coveredIds)
            {
                if (covId.StartsWith("TASK"))
                {
                    foreach (var data in matrix.Values)
                    {
                        if (data.Tasks.TryGetValue(covId, out var taskData))
                        {
                            taskData.TestFiles.Add(filePath);
                        }
                    }
                }
                else if (covId.StartsWith("REQ") && matrix.TryGetValue(covId, out var reqData))
                {
                    foreach (var taskData in reqData.Tasks.Values)
                    {
                        taskData.TestFiles.Add(filePath);
                    }
                }
            }
        }

        var verifStatus = ParseVerificationStatus(new DirectoryInfo(Path.Combine(projectRoot.FullName, "verification")));
        foreach (var (reqId, data) in matrix)
        {
            data.Verification = verifStatus.TryGetValue(reqId, out var v) ? v : null;
        }

        foreach (var (reqId, data) in matrix)
        {
            if (data.Tasks.Count == 0)
            {
                data.Warnings.Add($"{reqId} has no implementing tasks");
            }
            foreach (var (taskId, taskData) in data.Tasks)
            {
                if (taskData.SourceFiles.Count == 0)
                {
                    data.Warnings.Add($"{taskId} has no source files referencing it");
                }
                if (taskData.TestFiles.Count == 0)
                {
                    data.Warnings.Add($"{taskId} has no test coverage");
                }
            }
        }

        return matrix;
    }

    public static Dictionary<string, string> GetBranchPhases()
    {
        var phases = new Dictionary<string, string> { ["spec"] = "pending", ["plan"] = "pending", ["validate"] = "pending" };
        string branches, merged;
        try
        {
            branches = RunGit("branch", "-a", "--list");
            merged = RunGit("branch", "--merged", "main", "--list");
        }
        catch (Exception)
        {
            return phases;
        }
        var branchList = branches.Split('\n').Select(b => b.Trim().TrimStart('*', ' ')).ToList();
        var mergedList = merged.Split('\n').Select(b => b.Trim().TrimStart('*', ' ')).ToList();
        foreach (var phase in phases.Keys.ToList())
        {
            var branchName = $"phase/{phase}";
            if (mergedList.Contains(branchName))
            {
                phases[phase] = "complete";
            }
            else if (branchList.Contains(branchName))
            {
                phases[phase] = "active";
            }
        }
        return phases;
    }

    private static string RunGit(params string[] args)
    {
        var psi = new ProcessStartInfo("git")
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        foreach (var a in args) psi.ArgumentList.Add(a);
        using var proc = Process.Start(psi) ?? throw new InvalidOperationException("git not found");
        var output = proc.StandardOutput.ReadToEnd();
        proc.WaitForExit();
        if (proc.ExitCode != 0) throw new InvalidOperationException("git failed");
        return output;
    }

    public static FileInfo GenerateHtml(Dictionary<string, ReqEntry> matrix, Dictionary<string, string> phases, DirectoryInfo outputDir)
    {
        outputDir.Create();
        var phaseRows = "";
        var statusColors = new Dictionary<string, string> { ["complete"] = "#4caf50", ["active"] = "#ff9800", ["pending"] = "#666" };
        foreach (var (phase, status) in phases)
        {
            var color = statusColors.GetValueOrDefault(status, "#666");
            phaseRows += $"<tr><td>{phase}</td><td style=\"color:{color};font-weight:bold\">{status}</td></tr>\n";
        }

        var traceRows = "";
        var allWarnings = new List<string>();
        foreach (var reqId in matrix.Keys.OrderBy(x => x))
        {
            var data = matrix[reqId];
            var tasks = data.Tasks.Keys.Count > 0 ? string.Join(", ", data.Tasks.Keys.OrderBy(x => x)) : "<em>none</em>";
            var sourceFiles = new SortedSet<string>();
            var testFiles = new SortedSet<string>();
            foreach (var taskData in data.Tasks.Values)
            {
                foreach (var s in taskData.SourceFiles) sourceFiles.Add(s);
                foreach (var t in taskData.TestFiles) testFiles.Add(t);
            }
            var sources = sourceFiles.Count > 0 ? string.Join(", ", sourceFiles) : "<em>none</em>";
            var tests = testFiles.Count > 0 ? string.Join(", ", testFiles) : "<em>none</em>";
            var verif = data.Verification;
            var verifCell = verif != null ? $"{verif.File} ✓" : "<em>TDD only</em>";
            traceRows += $"<tr><td>{reqId}</td><td>{tasks}</td><td>{sources}</td><td>{tests}</td><td>{verifCell}</td></tr>\n";
            allWarnings.AddRange(data.Warnings);
        }

        var warningsHtml = "";
        if (allWarnings.Count > 0)
        {
            warningsHtml = "<h2>Traceability Warnings</h2><ul>\n";
            foreach (var w in allWarnings) warningsHtml += $"<li>{w}</li>\n";
            warningsHtml += "</ul>\n";
        }

        var html = $@"<!doctype html>
<html lang=""en""><head>
<meta charset=""utf-8"">
<meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
<title>SpecFlow Pipeline Dashboard</title>
<style>
:root {{
  --bg:#171614; --surface:#1c1b19; --text:#cdccca;
  --primary:#4f98a3; --border:#393836;
  font-family: -apple-system, BlinkMacSystemFont, ""Inter"", system-ui, sans-serif;
}}
body {{ background: var(--bg); color: var(--text); padding: 2rem; line-height: 1.6; max-width: 100ch; margin: auto; }}
h1 {{ border-bottom: 1px solid var(--border); padding-bottom: .5rem; }}
h2 {{ color: var(--primary); margin-top: 2rem; }}
table {{ width: 100%; border-collapse: collapse; margin: 1rem 0; }}
th, td {{ text-align: left; padding: .5rem; border-bottom: 1px solid var(--border); }}
th {{ color: var(--primary); font-size: .85rem; text-transform: uppercase; letter-spacing: .05em; }}
em {{ color: #888; }}
ul {{ padding-left: 1.5rem; }}
li {{ margin-bottom: .25rem; color: #e8af34; }}
</style>
</head><body>
<h1>Pipeline Dashboard</h1>
<h2>Phase Progress</h2>
<table><tr><th>Phase</th><th>Status</th></tr>
{phaseRows}</table>
<h2>Traceability Matrix</h2>
<table><tr><th>Requirement</th><th>Tasks</th><th>Source Files</th><th>Test Files</th><th>Verification</th></tr>
{traceRows}</table>
{warningsHtml}
<p style=""color:#666;font-size:.8rem;margin-top:3rem"">Generated by SpecFlow v3 dashboard</p>
</body></html>";

        var outPath = new FileInfo(Path.Combine(outputDir.FullName, "index.html"));
        File.WriteAllText(outPath.FullName, html);
        return outPath;
    }
}
