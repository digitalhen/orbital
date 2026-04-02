namespace Orbital.Models;

public class MissionPhaseInfo
{
    public string Id { get; set; } = "prelaunch";
    public string Name { get; set; } = "Pre-Launch";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "clock";
}

public class MissionData
{
    public double MissionElapsedTime { get; set; }
    public double DistanceFromEarth { get; set; }  // km altitude (from surface)
    public double DistanceFromMoon { get; set; }    // km
    public double Speed { get; set; }               // km/s
    public MissionPhaseInfo Phase { get; set; } = new();
    public List<string> CrewMembers { get; set; } = [];
    public string MissionName { get; set; } = "";
    public string MissionSubtitle { get; set; } = "";

    public Dictionary<string, MetricValue> Values { get; set; } = new();

    public void UpdateBuiltInValues()
    {
        Values["met"] = new DurationValue(MissionElapsedTime);
        Values["altitude"] = new NumberValue(DistanceFromEarth);
        Values["moonDistance"] = new NumberValue(DistanceFromMoon);
        Values["speed"] = new NumberValue(Speed);
        Values["phase"] = new TextValue(Phase.Name);
    }

    public string FormattedValue(Metric metric, UnitSystem units)
    {
        return Values.TryGetValue(metric.Source, out var value) ? value.Format(metric.Format, units) : "\u2014";
    }

    public string FormattedDetailValue(Metric metric, UnitSystem units)
    {
        return Values.TryGetValue(metric.Source, out var value) ? value.FormatDetail(metric.Format, units) : "\u2014";
    }
}
