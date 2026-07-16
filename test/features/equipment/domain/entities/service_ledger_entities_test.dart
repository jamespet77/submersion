import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind({List<EquipmentType> types = const [EquipmentType.tank]}) =>
      ServiceKind(
        id: 'hydro',
        name: 'Hydrostatic test',
        applicableTypes: types,
        defaultIntervalDays: 1825,
        autoAttach: true,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      );

  test('appliesTo matches listed types; empty list matches all', () {
    expect(kind().appliesTo(EquipmentType.tank), isTrue);
    expect(kind().appliesTo(EquipmentType.regulator), isFalse);
    expect(kind(types: const []).appliesTo(EquipmentType.fins), isTrue);
  });

  test('copyWith preserves unset fields', () {
    final s = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'hydro',
      createdAt: t0,
      updatedAt: t0,
    );
    final s2 = s.copyWith(intervalDays: 365);
    expect(s2.intervalDays, 365);
    expect(s2.equipmentId, 'e1');
    expect(s.intervalDays, null); // immutability
  });

  test('ServiceClockStatus.daysUntilDue is negative when overdue', () {
    final status = ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'e1',
        serviceKindId: 'hydro',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: kind(),
      anchor: t0,
      dueDate: DateTime(2026, 1, 10),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 1, 15),
    );
    expect(status.daysUntilDue, -5);
  });
}
