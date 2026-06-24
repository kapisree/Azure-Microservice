using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace RenderDoc;

public static class HttpCallSonnet
{
    private static readonly HttpClient Client = new();

    public static JsonObject Call(string system, string user)
    {
        var apiKey = Environment.GetEnvironmentVariable("ANTHROPIC_API_KEY")
            ?? throw new InvalidOperationException("ANTHROPIC_API_KEY is not set");

        var body = new JsonObject
        {
            ["model"] = DocRenderer.Model,
            ["max_tokens"] = 8000,
            ["system"] = new JsonArray
            {
                new JsonObject
                {
                    ["type"] = "text",
                    ["text"] = system,
                    ["cache_control"] = new JsonObject { ["type"] = "ephemeral" },
                },
            },
            ["messages"] = new JsonArray
            {
                new JsonObject { ["role"] = "user", ["content"] = user },
            },
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.anthropic.com/v1/messages");
        request.Headers.Add("x-api-key", apiKey);
        request.Headers.Add("anthropic-version", "2023-06-01");
        request.Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json");

        using var response = Client.Send(request);
        response.EnsureSuccessStatusCode();
        using var stream = response.Content.ReadAsStream();
        var responseJson = JsonNode.Parse(stream)!.AsObject();
        var text = responseJson["content"]![0]!["text"]!.GetValue<string>();

        var match = Regex.Match(text, @"\{.*\}", RegexOptions.Singleline);
        return JsonNode.Parse(match.Value)!.AsObject();
    }
}
