import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  EquipmentAttribute thickness(String valueText) => EquipmentAttribute.curated(
    equipmentId: 'e1',
    key: EquipmentAttrKeys.thicknessMm,
    valueText: valueText,
    valueNum: parsePrimaryThickness(valueText),
  );

  final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.thicknessMm);

  test('thickness value appends the unit exactly once', () {
    // Multi-panel designation with no unit -> single " mm".
    expect(
      formatAttributeValue(thickness('5/4/3'), def, units, l10n),
      '5/4/3 mm',
    );
    // Bare number -> single " mm".
    expect(formatAttributeValue(thickness('5'), def, units, l10n), '5 mm');
  });

  test('legacy value that already carries the unit is not doubled', () {
    // The v115 migration preserves "6mm" verbatim in valueText; the formatter
    // must not render "6mm mm".
    expect(formatAttributeValue(thickness('6mm'), def, units, l10n), '6 mm');
    expect(formatAttributeValue(thickness('6 mm'), def, units, l10n), '6 mm');
    expect(
      formatAttributeValue(thickness('8/7/6mm'), def, units, l10n),
      '8/7/6 mm',
    );
  });

  test('number attribute renders value with its unit symbol', () {
    final buoyancy = EquipmentAttribute.curated(
      equipmentId: 'e1',
      key: EquipmentAttrKeys.buoyancyKg,
      valueNum: 2.5,
    );
    final buoyancyDef = EquipmentAttributeCatalog.defFor(
      EquipmentAttrKeys.buoyancyKg,
    );
    expect(formatAttributeValue(buoyancy, buoyancyDef, units, l10n), '2.5 kg');
  });
}
