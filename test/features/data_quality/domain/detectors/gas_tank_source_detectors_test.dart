import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/gas_mod_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/source_conflict_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  String id = 't1',
  double o2 = 21.0,
  int order = 0,
  double? volume = 12,
}) => domain.DiveTank(
  id: id,
  volume: volume,
  gasMix: domain.GasMix(o2: o2, he: 0),
  order: order,
);

GasSwitch sw({
  required String id,
  required int t,
  required String tankId,
  double? depth,
}) => GasSwitch(
  id: id,
  diveId: 'd1',
  timestamp: t,
  tankId: tankId,
  depth: depth,
  createdAt: DateTime.utc(2026, 7, 1),
);

void main() {
  final entry = DateTime.utc(2026, 7, 1, 10);

  group('GasModDetector', () {
    const det = GasModDetector();

    test('EAN50 held at 35 m sustains ppO2 2.25 -> critical', () {
      // ppO2 = 0.50 * (35/10 + 1) = 0.50 * 4.5 = 2.25 >= 1.8.
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 50)]),
        samples: flatProfile(depth: 35),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.params['peakPpO2'], closeTo(2.25, 1e-9));
    });

    test('air at 30 m is clean (ppO2 0.84)', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 21)]),
        samples: flatProfile(depth: 30),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('switch to EAN50 recorded at 30 m exceeds its 22 m MOD', () {
      // MOD(1.6, 0.50) = (1.6/0.5 - 1) * 10 = 22 m; 30 > 22 + 1.
      final tanks = [
        tank(id: 'back', o2: 21),
        tank(id: 'deco', o2: 50, order: 1),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        samples: flatProfile(depth: 20), // shallow profile: no ppO2 run
        gasSwitches: [sw(id: 'gs1', t: 1200, tankId: 'deco', depth: 30)],
      );
      final out = det.detect(ctx);
      final modFinding = out.singleWhere(
        (f) => f.params.containsKey('modMeters'),
      );
      expect(modFinding.params['modMeters'], closeTo(22.0, 1e-9));
      expect(modFinding.params['switchDepth'], 30);
    });

    test('CCR dives are skipped entirely', () {
      final dive = makeTestDive(tanks: [tank(o2: 50)]);
      final ccrDive = dive.copyWith(diveMode: DiveMode.ccr);
      final ctx = makeContext(dive: ccrDive, samples: flatProfile(depth: 35));
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('TankAssignmentDetector', () {
    const det = TankAssignmentDetector();

    test('drop concentrated while tank inactive is flagged', () {
      // Switch to deco at t=1200. Back tank drops 30 bar AFTER 1200 (100%
      // inactive drop > 70%, total 30 > 20).
      final tanks = [tank(id: 'back'), tank(id: 'deco', o2: 50, order: 1)];
      final backSeries = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 1200, bar: 200),
        const QualityPressureSample(t: 1800, bar: 185),
        const QualityPressureSample(t: 2400, bar: 170),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        pressures: {'back': backSeries},
        gasSwitches: [sw(id: 'gs1', t: 1200, tankId: 'deco')],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['tankId'], 'back');
      expect(out.single.params['inactiveDropBar'], closeTo(30, 1e-9));
    });

    test('twin series on two tanks flags a double-assigned transmitter', () {
      final series = [
        for (var t = 0; t <= 1200; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a'),
            tank(id: 'b', order: 1),
          ],
        ),
        pressures: {'a': series, 'b': series},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['meanDiffBar'], 0.0);
    });

    test('single-tank dives are skipped', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]),
        pressures: {
          't1': [
            const QualityPressureSample(t: 0, bar: 200),
            const QualityPressureSample(t: 2400, bar: 60),
          ],
        },
      );
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('SourceConflictDetector', () {
    const det = SourceConflictDetector();

    DiveDataSource source({
      required String id,
      bool primary = false,
      double? maxDepth,
      int? duration,
      double? waterTemp,
    }) => DiveDataSource(
      id: id,
      diveId: 'd1',
      isPrimary: primary,
      maxDepth: maxDepth,
      duration: duration,
      waterTemp: waterTemp,
      importedAt: entry,
      createdAt: entry,
    );

    test('two sources 40 vs 41 m agree within tolerance', () {
      // tol = max(2, 40 * 0.05) = 2; diff 1 <= 2.
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, maxDepth: 40),
          source(id: 's', maxDepth: 41),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('30 vs 36 m conflict flags a warning with no salinity hint', () {
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, maxDepth: 30),
          source(id: 's', maxDepth: 36),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['salinitySettingSuspected'], false);
      expect(out.single.params['depthRatio'], closeTo(1.2, 1e-9));
    });

    test('duration and temperature disagreements are info findings', () {
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, duration: 2400, waterTemp: 20),
          source(id: 's', duration: 3000, waterTemp: 26),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(2));
      expect(out.map((f) => f.severity).toSet(), {QualitySeverity.info});
    });
  });
}
