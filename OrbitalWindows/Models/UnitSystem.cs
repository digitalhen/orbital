using System.Globalization;

namespace Orbital.Models;

public enum UnitSystem
{
    Metric,
    Imperial
}

public static class UnitSystemExtensions
{
    public static string Label(this UnitSystem units) => units switch
    {
        UnitSystem.Metric => "Metric (km, km/h)",
        UnitSystem.Imperial => "Imperial (mi, mph)",
        _ => "Metric (km, km/h)"
    };

    private static string Formatted(double value)
    {
        return value.ToString("N0", CultureInfo.InvariantCulture);
    }

    private static string Formatted1(double value)
    {
        return value.ToString("N1", CultureInfo.InvariantCulture);
    }

    public static string FormatDistance(this UnitSystem units, double km)
    {
        return units switch
        {
            UnitSystem.Metric => km >= 1000 ? $"{Formatted(km)} km" : $"{Formatted1(km)} km",
            UnitSystem.Imperial => FormatImperialDistance(km),
            _ => $"{Formatted(km)} km"
        };
    }

    private static string FormatImperialDistance(double km)
    {
        var mi = km * 0.621371;
        return mi >= 1000 ? $"{Formatted(mi)} mi" : $"{Formatted1(mi)} mi";
    }

    public static string FormatSpeed(this UnitSystem units, double kms)
    {
        return units switch
        {
            UnitSystem.Metric => $"{Formatted(kms * 3600)} km/h",
            UnitSystem.Imperial => $"{Formatted(kms * 3600 * 0.621371)} mph",
            _ => $"{Formatted(kms * 3600)} km/h"
        };
    }

    public static string FormatDistanceCompact(this UnitSystem units, double km)
    {
        var d = Math.Max(0, km);
        return units switch
        {
            UnitSystem.Metric => d >= 1000 ? $"{Formatted(d)} km" : $"{Formatted1(d)} km",
            UnitSystem.Imperial => FormatImperialDistanceCompact(d),
            _ => $"{Formatted(d)} km"
        };
    }

    private static string FormatImperialDistanceCompact(double km)
    {
        var mi = km * 0.621371;
        return mi >= 1000 ? $"{Formatted(mi)} mi" : $"{Formatted1(mi)} mi";
    }

    public static string FormatSpeedCompact(this UnitSystem units, double kms)
    {
        return units switch
        {
            UnitSystem.Metric => $"{Formatted(kms * 3600)} km/h",
            UnitSystem.Imperial => $"{Formatted(kms * 3600 * 0.621371)} mph",
            _ => $"{Formatted(kms * 3600)} km/h"
        };
    }
}
