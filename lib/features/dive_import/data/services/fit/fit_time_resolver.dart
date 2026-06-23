/// Resolves a dive's local wall-clock start, stored as a UTC-flagged DateTime
/// (the app's "wall-clock-as-UTC" convention: the displayed time must equal the
/// local time at the dive site regardless of the importing device's timezone).
///
/// FIT `record`/`session` timestamps are UTC. The `activity` message carries
/// both `timestamp` (UTC) and `local_timestamp`; their difference is the dive's
/// UTC offset, which we add to the UTC start to recover the local wall-clock.
class FitTimeResolver {
  const FitTimeResolver._();

  static DateTime wallClockStart({
    required int? utcStartMs,
    required int? localStartMs,
    required int? utcTimestampMs,
    required int? localTimestampMs,
  }) {
    final startMs = utcStartMs ?? localStartMs ?? 0;
    var offsetMs = 0;
    if (utcTimestampMs != null && localTimestampMs != null) {
      offsetMs = localTimestampMs - utcTimestampMs;
    }
    final wall = DateTime.fromMillisecondsSinceEpoch(
      startMs + offsetMs,
      isUtc: true,
    );
    // Truncate to whole seconds and keep the UTC flag.
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
  }
}
