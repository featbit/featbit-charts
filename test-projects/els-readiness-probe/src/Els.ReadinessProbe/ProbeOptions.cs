using System.ComponentModel.DataAnnotations;

namespace Els.ReadinessProbe;

public sealed class ProbeOptions
{
    public bool Enabled { get; set; }

    [Range(0.1, 3600)]
    public double IntervalSeconds { get; set; } = 10;

    [Range(1, 10000)]
    public int RecentFailureLimit { get; set; } = 100;
}
