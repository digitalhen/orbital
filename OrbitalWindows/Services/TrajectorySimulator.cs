using Orbital.Models;

namespace Orbital.Services;

public class TrajectorySimulator
{
    private readonly DateTime _launchDate;
    private readonly double _earthRadius;
    private readonly double _moonRadius;
    private readonly List<Waypoint> _waypoints;
    private readonly List<Phase> _phases;

    public TrajectorySimulator(MissionConfig config)
    {
        _launchDate = config.LaunchDate ?? DateTime.UtcNow;
        _earthRadius = config.TrajectoryInfo.EarthRadius;
        _moonRadius = config.TrajectoryInfo.MoonRadius;
        _waypoints = config.TrajectoryInfo.Waypoints;
        _phases = config.Phases;
    }

    public MissionData GetData(DateTime date)
    {
        var met = (date - _launchDate).TotalSeconds;
        return GetData(met);
    }

    public MissionData GetData(double met)
    {
        var data = new MissionData
        {
            MissionElapsedTime = Math.Max(0, met)
        };

        if (_waypoints.Count == 0) return data;

        if (met <= _waypoints[0].Met)
        {
            var wp = _waypoints[0];
            data.DistanceFromEarth = Math.Max(0, wp.DistanceFromEarth - _earthRadius);
            data.DistanceFromMoon = Math.Max(0, wp.DistanceFromMoon - _moonRadius);
            data.Speed = wp.Speed;
            data.Phase = ResolvePhase(wp.Phase);
            return data;
        }

        if (met >= _waypoints[^1].Met)
        {
            var wp = _waypoints[^1];
            data.DistanceFromEarth = Math.Max(0, wp.DistanceFromEarth - _earthRadius);
            data.DistanceFromMoon = Math.Max(0, wp.DistanceFromMoon - _moonRadius);
            data.Speed = wp.Speed;
            data.Phase = ResolvePhase(wp.Phase);
            return data;
        }

        var lowerIndex = 0;
        for (var i = 0; i < _waypoints.Count - 1; i++)
        {
            if (met >= _waypoints[i].Met && met < _waypoints[i + 1].Met)
            {
                lowerIndex = i;
                break;
            }
        }

        var wp0 = _waypoints[lowerIndex];
        var wp1 = _waypoints[lowerIndex + 1];
        var dt = wp1.Met - wp0.Met;
        var t = (met - wp0.Met) / dt;
        var s = Smoothstep(t);

        data.DistanceFromEarth = Math.Max(0, Lerp(wp0.DistanceFromEarth, wp1.DistanceFromEarth, s) - _earthRadius);
        data.DistanceFromMoon = Math.Max(0, Lerp(wp0.DistanceFromMoon, wp1.DistanceFromMoon, s) - _moonRadius);
        data.Speed = Lerp(wp0.Speed, wp1.Speed, s);
        data.Phase = ResolvePhase(t < 0.5 ? wp0.Phase : wp1.Phase);

        return data;
    }

    private MissionPhaseInfo ResolvePhase(string id)
    {
        var p = _phases.FirstOrDefault(p => p.Id == id);
        if (p != null)
            return new MissionPhaseInfo { Id = p.Id, Name = p.Name, Description = p.Description, Icon = p.Icon };
        return new MissionPhaseInfo { Id = id, Name = id, Description = "", Icon = "questionmark.circle" };
    }

    private static double Lerp(double a, double b, double t) => a + (b - a) * t;

    private static double Smoothstep(double t)
    {
        var c = Math.Clamp(t, 0, 1);
        return c * c * (3 - 2 * c);
    }
}
