/// Air-break policy for long oxygen stops: after [o2Seconds] on a pure-O2
/// stop gas, breathe the break gas for [breakSeconds], then repeat.
class AirBreakPolicy {
  const AirBreakPolicy({this.o2Seconds = 20 * 60, this.breakSeconds = 5 * 60});

  final int o2Seconds;
  final int breakSeconds;
}

/// How a decompression schedule is generated, independent of the tissue
/// model. Defaults reproduce the engine's legacy behavior.
class SchedulePolicy {
  const SchedulePolicy({
    this.stopIncrement = 3.0,
    this.lastStopDepth = 3.0,
    this.ascentRate = 9.0,
    this.gasSwitchStopSeconds = 0,
    this.airBreaks,
  });

  /// Deco stop depth increment in meters.
  final double stopIncrement;

  /// Shallowest deco stop depth in meters (3 or 6).
  final double lastStopDepth;

  /// Ascent rate in meters per minute.
  final double ascentRate;

  /// Minimum time in seconds to hold at a stop where the breathed gas
  /// changes (0 = no minimum).
  final int gasSwitchStopSeconds;

  /// Optional O2 air-break policy; null = no air breaks.
  final AirBreakPolicy? airBreaks;
}
