import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

void main() {
  const suitItem = EquipmentItem(
    id: 'suit',
    name: '5mm Suit',
    type: EquipmentType.wetsuit,
  );

  final entry = DiverWeightEntry(
    id: 'w1',
    diverId: 'diver-1',
    measuredAt: DateTime(2026, 6, 1),
    weightKg: 80,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  final observations = [
    for (var i = 0; i < 12; i++)
      WeightObservation(
        diveId: 'd$i',
        diveDateTime: DateTime(2026, 6, 1).subtract(Duration(days: i)),
        waterType: WaterType.salt,
        carriedKg: 8.0,
        equipmentIds: const ['suit'],
        tanks: const [
          ObservedTank(
            presetName: 'al80',
            volumeL: 11.1,
            workingPressureBar: 207,
            material: TankMaterial.aluminum,
          ),
        ],
        feedback: 'correct',
      ),
  ];

  testWidgets('shows a live prediction and persists it on accept', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final overrides = [
      ...base,
      weightObservationsProvider.overrideWith((ref) async => observations),
      allEquipmentProvider.overrideWith((ref) async => const [suitItem]),
      latestDiverWeightProvider.overrideWith((ref) async => entry),
    ];

    await tester.pumpWidget(
      testApp(overrides: overrides, child: const PlanGearWeightsSection()),
    );
    await tester.pumpAndSettle();

    // Seed the plan state through the real notifier.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGearWeightsSection)),
    );
    container.read(divePlanNotifierProvider.notifier)
      ..addTank(
        const DiveTank(
          id: 't1',
          volume: 11.1,
          workingPressure: 207,
          material: TankMaterial.aluminum,
          presetName: 'al80',
        ),
      )
      ..setEquipmentIds(['suit']);
    await tester.pumpAndSettle();

    expect(find.textContaining('Predicted:'), findsOneWidget);
    expect(find.text('5mm Suit'), findsOneWidget);

    await tester.tap(find.text('Use as planned weight'));
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.plannedWeightKg, isNotNull);
    expect(state.plannedWeightKg, greaterThan(4.0));
    expect(find.textContaining('Planned:'), findsOneWidget);
  });

  testWidgets('shows the empty invitation without gear', (tester) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          weightObservationsProvider.overrideWith((ref) async => const []),
          allEquipmentProvider.overrideWith((ref) async => const []),
          latestDiverWeightProvider.overrideWith((ref) async => null),
        ],
        child: const PlanGearWeightsSection(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add gear to predict your weighting'), findsOneWidget);
  });
}
