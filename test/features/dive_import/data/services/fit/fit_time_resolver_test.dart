import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_time_resolver.dart';

void main() {
  // Malta dive: session.startTime is 08:51:10 UTC; the activity message's
  // local_timestamp shows 10:51:10 (UTC+2). The displayed wall-clock must be
  // 10:51:10, stored as a UTC-flagged DateTime (wall-clock-as-UTC convention).
  final utcStart = DateTime.utc(2025, 10, 13, 8, 51, 10).millisecondsSinceEpoch;
  final utcAct = DateTime.utc(2025, 10, 13, 8, 51, 10).millisecondsSinceEpoch;
  final localAct = DateTime.utc(
    2025,
    10,
    13,
    10,
    51,
    10,
  ).millisecondsSinceEpoch;

  test('applies the activity UTC offset to the session start', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcStart,
      localStartMs: null,
      utcTimestampMs: utcAct,
      localTimestampMs: localAct,
    );
    expect(result, DateTime.utc(2025, 10, 13, 10, 51, 10));
    expect(result.isUtc, isTrue);
  });

  test('falls back to the raw start when no local_timestamp is present', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcStart,
      localStartMs: null,
      utcTimestampMs: null,
      localTimestampMs: null,
    );
    expect(result, DateTime.utc(2025, 10, 13, 8, 51, 10));
  });
}
