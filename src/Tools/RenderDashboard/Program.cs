namespace RenderDashboard;

public static class Program
{
    public static int Main(string[] args)
    {
        var root = Directory.GetCurrentDirectory();
        var output = Path.Combine(root, "docs", "dashboard");

        for (var i = 0; i < args.Length; i++)
        {
            if (args[i] == "--root" && i + 1 < args.Length) root = args[++i];
            else if (args[i] == "--output" && i + 1 < args.Length) output = args[++i];
        }

        var matrix = Dashboard.BuildTraceability(new DirectoryInfo(root));
        var phases = Dashboard.GetBranchPhases();
        var outFile = Dashboard.GenerateHtml(matrix, phases, new DirectoryInfo(output));
        Console.WriteLine($"[dashboard] Generated: {outFile.FullName}");
        if (matrix.Count > 0)
        {
            var totalReqs = matrix.Count;
            var covered = matrix.Values.Count(d => d.Tasks.Count > 0);
            Console.WriteLine($"[dashboard] {covered}/{totalReqs} requirements have implementing tasks");
        }
        return 0;
    }
}
