using System.Globalization;
using System.Text.Json.Serialization;

namespace Orbital.Models;

public class MissionConfig
{
    [JsonPropertyName("configVersion")]
    public int ConfigVersion { get; set; }

    [JsonPropertyName("refreshInterval")]
    public double RefreshInterval { get; set; }

    [JsonPropertyName("mission")]
    public Mission MissionInfo { get; set; } = new();

    [JsonPropertyName("dataSources")]
    public DataSources DataSourcesInfo { get; set; } = new();

    [JsonPropertyName("metrics")]
    public List<Metric> Metrics { get; set; } = [];

    [JsonPropertyName("phases")]
    public List<Phase> Phases { get; set; } = [];

    [JsonPropertyName("trajectory")]
    public Trajectory TrajectoryInfo { get; set; } = new();

    // Helpers
    [JsonIgnore]
    public DateTime? LaunchDate
    {
        get
        {
            if (DateTime.TryParse(MissionInfo.LaunchDate, null,
                System.Globalization.DateTimeStyles.RoundtripKind, out var dt))
                return dt;
            return null;
        }
    }

    [JsonIgnore] public double EarthRadius => TrajectoryInfo.EarthRadius;
    [JsonIgnore] public double MoonRadius => TrajectoryInfo.MoonRadius;
    [JsonIgnore] public double Mu => TrajectoryInfo.Mu ?? 398_600.4418;
}

public class Mission
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("subtitle")]
    public string Subtitle { get; set; } = "";

    [JsonPropertyName("status")]
    public string Status { get; set; } = "";

    [JsonPropertyName("launchDate")]
    public string LaunchDate { get; set; } = "";

    [JsonPropertyName("missionDuration")]
    public double MissionDuration { get; set; }

    [JsonPropertyName("crew")]
    public List<CrewMember> Crew { get; set; } = [];
}

public class CrewMember
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("role")]
    public string Role { get; set; } = "";
}

public class DataSources
{
    [JsonPropertyName("telemetry")]
    public TelemetrySource Telemetry { get; set; } = new();

    [JsonPropertyName("moonPosition")]
    public MoonPositionSource? MoonPosition { get; set; }

    [JsonPropertyName("telemetryEndpoint")]
    public string? TelemetryEndpoint { get; set; }
}

public class TelemetrySource
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = "";

    [JsonPropertyName("positionParams")]
    public List<string> PositionParams { get; set; } = [];

    [JsonPropertyName("positionUnit")]
    public string PositionUnit { get; set; } = "feet";

    [JsonPropertyName("activityField")]
    public string ActivityField { get; set; } = "MIS";

    [JsonPropertyName("pollInterval")]
    public double PollInterval { get; set; } = 30;
}

public class MoonPositionSource
{
    [JsonPropertyName("horizonsURL")]
    public string? HorizonsUrl { get; set; }

    [JsonPropertyName("refreshInterval")]
    public double? RefreshInterval { get; set; }
}

public class Phase
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("description")]
    public string Description { get; set; } = "";

    [JsonPropertyName("icon")]
    public string Icon { get; set; } = "";
}

public class Trajectory
{
    [JsonPropertyName("earthRadius")]
    public double EarthRadius { get; set; }

    [JsonPropertyName("moonRadius")]
    public double MoonRadius { get; set; }

    [JsonPropertyName("mu")]
    public double? Mu { get; set; }

    [JsonPropertyName("waypoints")]
    public List<Waypoint> Waypoints { get; set; } = [];
}

public class Waypoint
{
    [JsonPropertyName("met")]
    public double Met { get; set; }

    [JsonPropertyName("distanceFromEarth")]
    public double DistanceFromEarth { get; set; }

    [JsonPropertyName("distanceFromMoon")]
    public double DistanceFromMoon { get; set; }

    [JsonPropertyName("speed")]
    public double Speed { get; set; }

    [JsonPropertyName("phase")]
    public string Phase { get; set; } = "";
}
