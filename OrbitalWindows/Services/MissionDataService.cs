using System.Text.Json;
using Orbital.Models;

namespace Orbital.Services;

public class MissionDataService
{
    private readonly MissionConfigService _configService;
    private TrajectorySimulator _simulator;
    private TelemetryAPIFetcher? _telemetryFetcher;

    private System.Timers.Timer? _updateTimer;
    private System.Timers.Timer? _telemetryTimer;

    public MissionData Data { get; private set; } = new();
    public List<Metric> Metrics { get; private set; } = [];
    public HashSet<string> EnabledMetricIDs { get; private set; } = [];
    public UnitSystem Units { get; set; } = UnitSystem.Imperial;
    public bool IsLive { get; private set; }
    public DateTime? LastTelemetryUpdate { get; private set; }

    private double? _liveAltitude;
    private double? _liveMoonDist;
    private double? _liveSpeed;

    public event Action? DataChanged;
    public event Action? MetricsChanged;

    private static readonly string SettingsFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Orbital", "settings.json");

    public MissionDataService()
    {
        _configService = new MissionConfigService();
        var config = _configService.Config;

        _simulator = new TrajectorySimulator(config);
        if (config.DataSourcesInfo.TelemetryEndpoint is string endpoint)
            _telemetryFetcher = new TelemetryAPIFetcher(endpoint);
        Metrics = config.Metrics;

        LoadSettings(config);
        ApplyConfig(config);

        _configService.ConfigUpdated += OnConfigUpdate;
        StartUpdating();
        StartTelemetryPolling(config);
        _configService.StartPeriodicRefresh();
    }

    private void LoadSettings(MissionConfig config)
    {
        try
        {
            if (File.Exists(SettingsFile))
            {
                var json = File.ReadAllText(SettingsFile);
                var settings = JsonSerializer.Deserialize<AppSettings>(json);
                if (settings != null)
                {
                    EnabledMetricIDs = [.. settings.EnabledMetricIDs];
                    if (settings.Units != null)
                        Units = Enum.TryParse<UnitSystem>(settings.Units, true, out var u) ? u : UnitSystem.Imperial;

                    var validIds = config.Metrics.Select(m => m.Id).ToHashSet();
                    if (!EnabledMetricIDs.Any(id => validIds.Contains(id)))
                        EnabledMetricIDs = DefaultEnabledIDs(config.Metrics);

                    return;
                }
            }
        }
        catch { /* ignore */ }

        EnabledMetricIDs = DefaultEnabledIDs(config.Metrics);
    }

    public void SaveSettings()
    {
        try
        {
            var dir = Path.GetDirectoryName(SettingsFile)!;
            Directory.CreateDirectory(dir);
            var settings = new AppSettings
            {
                EnabledMetricIDs = [.. EnabledMetricIDs],
                Units = Units.ToString()
            };
            File.WriteAllText(SettingsFile, JsonSerializer.Serialize(settings));
        }
        catch { /* ignore */ }
    }

    private static HashSet<string> DefaultEnabledIDs(List<Metric> metrics)
    {
        var defaults = metrics.Where(m => m.EnabledByDefault == true).Select(m => m.Id).ToList();
        return defaults.Count > 0
            ? [.. defaults]
            : [.. metrics.Take(3).Select(m => m.Id)];
    }

    private void ApplyConfig(MissionConfig config)
    {
        Data.MissionName = config.MissionInfo.Name;
        Data.MissionSubtitle = config.MissionInfo.Subtitle;
        Data.CrewMembers = config.MissionInfo.Crew.Select(c => $"{c.Name} ({c.Role})").ToList();
        Metrics = config.Metrics;
    }

    private void OnConfigUpdate(MissionConfig config)
    {
        _simulator = new TrajectorySimulator(config);

        if (config.DataSourcesInfo.TelemetryEndpoint is string endpoint)
        {
            if (_telemetryFetcher != null)
                _telemetryFetcher.Reconfigure(endpoint);
            else
                _telemetryFetcher = new TelemetryAPIFetcher(endpoint);
        }
        else
        {
            _telemetryFetcher = null;
        }

        _liveAltitude = null;
        _liveMoonDist = null;
        _liveSpeed = null;

        StartTelemetryPolling(config);
        ApplyConfig(config);
        MetricsChanged?.Invoke();
    }

    public void ToggleMetric(string id)
    {
        if (EnabledMetricIDs.Contains(id))
        {
            if (EnabledMetricIDs.Count > 1)
                EnabledMetricIDs.Remove(id);
        }
        else
        {
            EnabledMetricIDs.Add(id);
        }
        SaveSettings();
        MetricsChanged?.Invoke();
    }

    public bool IsMetricEnabled(string id) => EnabledMetricIDs.Contains(id);

    private void StartUpdating()
    {
        _updateTimer = new System.Timers.Timer(1000);
        _updateTimer.Elapsed += (_, _) => UpdateData();
        _updateTimer.AutoReset = true;
        _updateTimer.Start();
        UpdateData();
    }

    private void UpdateData()
    {
        var simData = _simulator.GetData(DateTime.UtcNow);
        Data.MissionElapsedTime = simData.MissionElapsedTime;
        Data.Phase = simData.Phase;
        Data.DistanceFromEarth = _liveAltitude ?? simData.DistanceFromEarth;
        Data.DistanceFromMoon = _liveMoonDist ?? simData.DistanceFromMoon;
        Data.Speed = _liveSpeed ?? simData.Speed;
        Data.UpdateBuiltInValues();
        DataChanged?.Invoke();
    }

    private void StartTelemetryPolling(MissionConfig config)
    {
        _telemetryTimer?.Stop();
        _telemetryTimer?.Dispose();

        if (_telemetryFetcher == null) return;

        var interval = Math.Max(config.DataSourcesInfo.Telemetry.PollInterval, 10) * 1000;
        _telemetryTimer = new System.Timers.Timer(interval);
        _telemetryTimer.Elapsed += async (_, _) => await FetchTelemetryAsync();
        _telemetryTimer.AutoReset = true;
        _telemetryTimer.Start();

        // Initial fetch
        _ = FetchTelemetryAsync();
    }

    private async Task FetchTelemetryAsync()
    {
        if (_telemetryFetcher == null) return;

        var telemetry = await _telemetryFetcher.FetchAsync();
        if (telemetry == null) return;

        IsLive = telemetry.IsLive;
        LastTelemetryUpdate = DateTime.UtcNow;

        if (telemetry.Altitude > 0)
            _liveAltitude = telemetry.Altitude;
        if (telemetry.DistanceToMoon > 0)
            _liveMoonDist = telemetry.DistanceToMoon;
        if (telemetry.Speed > 0.01)
            _liveSpeed = telemetry.Speed;
    }

    private class AppSettings
    {
        public List<string> EnabledMetricIDs { get; set; } = [];
        public string? Units { get; set; }
    }
}
