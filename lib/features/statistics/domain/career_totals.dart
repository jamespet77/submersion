/// Combined "career" lifetime totals: app-logged dives plus a per-diver
/// manually-entered offset of dives/time accumulated before the diver started
/// using Submersion (issue #331). Pure value object (no I/O) so the combine
/// logic is unit-testable in isolation.
class CareerTotals {
  final int loggedDives;
  final int loggedTimeSeconds;
  final int priorDives;
  final int priorTimeSeconds;

  /// The date to show as "Diving since". Non-null only when the diver entered
  /// a value (then reconciled to be no later than their first logged dive).
  final DateTime? divingSinceResolved;

  const CareerTotals._({
    required this.loggedDives,
    required this.loggedTimeSeconds,
    required this.priorDives,
    required this.priorTimeSeconds,
    required this.divingSinceResolved,
  });

  factory CareerTotals.from({
    required int loggedDives,
    required int loggedTimeSeconds,
    DateTime? firstLoggedDive,
    int? priorDives,
    int? priorTimeSeconds,
    DateTime? divingSince,
  }) {
    final pDives = (priorDives == null || priorDives < 0) ? 0 : priorDives;
    final pTime = (priorTimeSeconds == null || priorTimeSeconds < 0)
        ? 0
        : priorTimeSeconds;

    DateTime? resolved;
    if (divingSince != null) {
      resolved =
          (firstLoggedDive != null && firstLoggedDive.isBefore(divingSince))
          ? firstLoggedDive
          : divingSince;
    }

    return CareerTotals._(
      loggedDives: loggedDives,
      loggedTimeSeconds: loggedTimeSeconds,
      priorDives: pDives,
      priorTimeSeconds: pTime,
      divingSinceResolved: resolved,
    );
  }

  int get combinedDives => loggedDives + priorDives;
  int get combinedTimeSeconds => loggedTimeSeconds + priorTimeSeconds;

  bool get hasPriorDives => priorDives > 0;
  bool get hasPriorTime => priorTimeSeconds > 0;
  bool get hasPriorExperience =>
      hasPriorDives || hasPriorTime || divingSinceResolved != null;

  int get loggedHours => loggedTimeSeconds ~/ 3600;
  int get priorHours => priorTimeSeconds ~/ 3600;

  /// "Xh Ym" formatting of the combined time, matching DiveStatistics.
  String get combinedTimeFormatted {
    final d = Duration(seconds: combinedTimeSeconds);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}
