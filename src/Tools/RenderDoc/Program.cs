namespace RenderDoc;

public static class Program
{
    public static int Main(string[] args)
    {
        string? source = null;
        for (var i = 0; i < args.Length; i++)
        {
            if (args[i] == "--source" && i + 1 < args.Length) source = args[++i];
        }
        if (source == null)
        {
            Console.Error.WriteLine("usage: RenderDoc --source <path>");
            return 2;
        }

        var renderer = new DocRenderer(new DirectoryInfo(Directory.GetCurrentDirectory()));
        var outFile = renderer.Render(new FileInfo(source));
        if (outFile != null)
        {
            Console.WriteLine($"[render] {source} -> {outFile.FullName}");
        }
        else
        {
            Console.Error.WriteLine($"[render] source missing: {source}");
        }
        return 0;
    }
}
