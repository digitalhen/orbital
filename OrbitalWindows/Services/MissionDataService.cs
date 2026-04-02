using System.Text.Json;
using Orbital.Models;

namespace Orbital.Services;

public class MissionDataService
{
    private readonly MissionConfigService _configService;
    private TrajectorySimulator _simulator;

    private System.Timers.Timer? _updateTimer;

    public MissionData Data { get; private set; } = new();
    public List<Metric> Metrics { get; private set; } = [];
    public HashSet<string> EnabledMetricIDs { get; private set; } = [];
    public UnitSystem Units { get; set; } = UnitSystem.Imperial;

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
        Metrics = config.Metrics;

        LoadSettings(config);
        ApplyConfig(config);

        _configService.ConfigUpdated += OnConfigUpdate;
        StartUpdating();
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
        Data.DistanceFromEarth = simData.DistanceFromEarth;
        Data.DistanceFromMoon = simData.DistanceFromMoon;
        Data.Speed = simData.Speed;
        Data.UpdateBuiltInValues();
        DataChanged?.Invoke();
    }

    private class AppSettings
    {
        public List<string> EnabledMetricIDs { get; set; } = [];
        public string? Units { get; set; }
    }
}
