using System.Text.Json;

namespace Orbital.Services;

/// <summary>
/// Fetches pre-computed telemetry from the Orbital API.
/// Replaces direct AROW + Horizons calls when telemetryEndpoint is configured.
/// </summary>
public class TelemetryAPIFetcher
{
    public class TelemetryData
    {
        public double Altitude { get; set; }
        public double DistanceToMoon { get; set; }
        public double Speed { get; set; }
        public bool IsLive { get; set; }
        public string? Phase { get; set; }
    }

    private string _endpointUrl;

    private static readonly HttpClient _httpClient = new()
    {
        Timeout = TimeSpan.FromSeconds(15),
        DefaultRequestHeaders =
        {
            { "Cache-Control", "no-cache" },
            { "Pragma", "no-cache" }
        }
    };

    public TelemetryAPIFetcher(string endpointUrl)
    {
        _endpointUrl = endpointUrl;
    }

    public void Reconfigure(string endpointUrl)
    {
        _endpointUrl = endpointUrl;
    }

    public async Task<TelemetryData?> FetchAsync()
    {
        try
        {
            var cacheBust = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var separator = _endpointUrl.Contains('?') ? "&" : "?";
            var url = $"{_endpointUrl}{separator}_={cacheBust}";

            var response = await _httpClient.GetAsync(url);
            if (!response.IsSuccessStatusCode)
                return null;

            var json = await response.Content.ReadAsStringAsync();
            return Parse(json);
        }
        catch
        {
            return null;
        }
    }

    private static TelemetryData? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            return new TelemetryData
            {
                Altitude = root.TryGetProperty("altitude", out var alt) ? alt.GetDouble() : 0,
                DistanceToMoon = root.TryGetProperty("distanceToMoon", out var moon) ? moon.GetDouble() : 0,
                Speed = root.TryGetProperty("speed", out var spd) ? spd.GetDouble() : 0,
                IsLive = root.TryGetProperty("isLive", out var live) && live.GetBoolean(),
                Phase = root.TryGetProperty("phase", out var phase) ? phase.GetString() : null,
            };
        }
        catch
        {
            return null;
        }
    }
}
