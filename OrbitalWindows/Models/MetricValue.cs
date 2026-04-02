namespace Orbital.Models;

public abstract class MetricValue
{
    public abstract string Format(string type, UnitSystem units);
    public abstract string FormatDetail(string type, UnitSystem units);

    public static string FormatDuration(double totalSeconds)
    {
        var total = (int)totalSeconds;
        var d = total / 86400;
        var h = (total % 86400) / 3600;
        var m = (total % 3600) / 60;
        var s = total % 60;
        if (d > 0)
            return $"{d}d {h:D2}h {m:D2}m {s:D2}s";
        return $"{h:D2}h {m:D2}m {s:D2}s";
    }
}

public class NumberValue(double value) : MetricValue
{
    public double Value { get; } = value;

    public override string Format(string type, UnitSystem units) => type switch
    {
        "distance" => units.FormatDistanceCompact(Value),
        "speed" => units.FormatSpeedCompact(Value),
        _ => units.FormatDistanceCompact(Value),
    };

    public override string FormatDetail(string type, UnitSystem units) => type switch
    {
        "distance" => units.FormatDistance(Value),
        "speed" => units.FormatSpeed(Value),
        _ => units.FormatDistance(Value),
    };
}

public class TextValue(string text) : MetricValue
{
    public string Text { get; } = text;
    public override string Format(string type, UnitSystem units) => Text;
    public override string FormatDetail(string type, UnitSystem units) => Text;
}

public class DurationValue(double seconds) : MetricValue
{
    public double Seconds { get; } = seconds;
    public override string Format(string type, UnitSystem units) => FormatDuration(Seconds);
    public override string FormatDetail(string type, UnitSystem units) => FormatDuration(Seconds);
}
