using System.Text.Json.Serialization;

namespace Orbital.Models;

public class Metric
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("label")]
    public string Label { get; set; } = "";

    [JsonPropertyName("shortLabel")]
    public string ShortLabel { get; set; } = "";

    [JsonPropertyName("icon")]
    public string Icon { get; set; } = "";

    [JsonPropertyName("format")]
    public string Format { get; set; } = "";

    [JsonPropertyName("source")]
    public string Source { get; set; } = "";

    [JsonPropertyName("enabledByDefault")]
    public bool? EnabledByDefault { get; set; }
}
