using System.Reflection;
using System.Text.Json;
using Orbital.Models;

namespace Orbital.Services;

public class MissionConfigService
{
    private const string ConfigUrl = "https://api.cleartextlabs.com/space/api/v1/mission/active";

    private readonly string _cacheFile;
    private readonly HttpClient _http;
    private System.Timers.Timer? _refreshTimer;

    public MissionConfig Config { get; private set; }
    public event Action<MissionConfig>? ConfigUpdated;
    public event Action<string>? UpdateRequired; // fires with updateURL when client is behind minClientVersion

    public MissionConfigService()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var appDir = Path.Combine(appData, "Orbital");
        Directory.CreateDirectory(appDir);
        _cacheFile = Path.Combine(appDir, "config.json");

        _http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        _http.DefaultRequestHeaders.CacheControl = new System.Net.Http.Headers.CacheControlHeaderValue { NoCache = true };

        // Load priority: disk cache > bundled default
        Config = LoadFromDisk() ?? LoadBundledDefault();

        // Fetch fresh config from remote
        _ = FetchRemoteConfig();
    }

    public void StartPeriodicRefresh()
    {
        var interval = Math.Max(Config.RefreshInterval, 300) * 1000; // ms, minimum 5 min
        _refreshTimer?.Dispose();
        _refreshTimer = new System.Timers.Timer(interval);
        _refreshTimer.Elapsed += async (_, _) => await FetchRemoteConfig();
        _refreshTimer.AutoReset = true;
        _refreshTimer.Start();
    }

    private async Task FetchRemoteConfig()
    {
        try
        {
            var cacheBust = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var url = $"{ConfigUrl}?_={cacheBust}";

            var response = await _http.GetStringAsync(url);
            var remote = JsonSerializer.Deserialize<MissionConfig>(response);
            if (remote == null) return;

            if (remote.ConfigVersion >= Config.ConfigVersion)
            {
                Config = remote;
                SaveToDisk(response);
                ConfigUpdated?.Invoke(remote);
                CheckMinVersion(remote);

                // Update refresh interval
                _refreshTimer?.Dispose();
                StartPeriodicRefresh();
            }
        }
        catch
        {
            // Silently fail - keep cached/bundled config
        }
    }

    private void SaveToDisk(string json)
    {
        try { File.WriteAllText(_cacheFile, json); } catch { /* ignore */ }
    }

    private MissionConfig? LoadFromDisk()
    {
        try
        {
            if (!File.Exists(_cacheFile)) return null;
            var json = File.ReadAllText(_cacheFile);
            return JsonSerializer.Deserialize<MissionConfig>(json);
        }
        catch { return null; }
    }

    private void CheckMinVersion(MissionConfig config)
    {
        if (config.MinClientVersion == null || config.UpdateURL == null) return;

        try
        {
            var minVersion = new Version(config.MinClientVersion);
            var appVersion = Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 0);
            if (appVersion < minVersion)
                UpdateRequired?.Invoke(config.UpdateURL);
        }
        catch { /* ignore parse errors */ }
    }

    public static MissionConfig LoadBundledDefault()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith("default-config.json"))
            ?? throw new InvalidOperationException("Missing default-config.json embedded resource");

        using var stream = assembly.GetManifestResourceStream(resourceName)!;
        using var reader = new StreamReader(stream);
        var json = reader.ReadToEnd();
        return JsonSerializer.Deserialize<MissionConfig>(json)
            ?? throw new InvalidOperationException("Failed to parse default config");
    }
}
