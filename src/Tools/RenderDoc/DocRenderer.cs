// Render a Markdown spec/plan file to a styled HTML page using Claude.
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace RenderDoc;

public class DocRenderer
{
    public const string Model = "claude-sonnet-4-6";

    private readonly DirectoryInfo _root;

    public FileInfo SkillPath { get; }
    public FileInfo TemplatePath { get; }
    public DirectoryInfo OutputDir { get; set; }
    public Func<string, string, JsonObject> CallSonnet { get; set; }

    public static DirectoryInfo FindRepoRoot(DirectoryInfo? start = null)
    {
        var dir = start ?? new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CLAUDE.md")))
        {
            dir = dir.Parent;
        }
        return dir ?? throw new InvalidOperationException("repo root not found");
    }

    public DocRenderer(DirectoryInfo root)
    {
        _root = root;
        SkillPath = new FileInfo(Path.Combine(root.FullName, ".claude", "skills", "doc-render", "SKILL.md"));
        TemplatePath = new FileInfo(Path.Combine(root.FullName, "scripts", "render_template.html"));
        OutputDir = new DirectoryInfo(Path.Combine(root.FullName, "docs", "dashboard"));
        CallSonnet = HttpCallSonnet.Call;
    }

    private string SkillBody()
    {
        var text = File.ReadAllText(SkillPath.FullName);
        return Regex.Replace(text, @"\A---\n.*?\n---\n", "", RegexOptions.Singleline).Trim();
    }

    private string Slug(FileInfo p)
    {
        var full = p.FullName;
        var rootFull = _root.FullName;
        var rel = full.StartsWith(rootFull) ? Path.GetRelativePath(rootFull, full) : full;
        var withDashes = rel.Replace(Path.DirectorySeparatorChar, '-').Replace('/', '-');
        var lastDot = withDashes.LastIndexOf('.');
        return lastDot >= 0 ? withDashes[..lastDot] : withDashes;
    }

    public FileInfo? Render(FileInfo source)
    {
        if (!source.Exists) return null;

        var md = File.ReadAllText(source.FullName);
        var template = File.ReadAllText(TemplatePath.FullName);

        var userPrompt = JsonSerializer.Serialize(new
        {
            source_path = source.FullName,
            markdown = md,
            template,
        });
        var result = CallSonnet(SkillBody(), userPrompt);

        var outPath = new FileInfo(Path.Combine(OutputDir.FullName, $"{Slug(source)}.html"));
        outPath.Directory!.Create();
        var tmpPath = Path.ChangeExtension(outPath.FullName, ".html.tmp");
        File.WriteAllText(tmpPath, result["html"]!.GetValue<string>());
        File.Move(tmpPath, outPath.FullName, overwrite: true);

        return outPath;
    }
}
