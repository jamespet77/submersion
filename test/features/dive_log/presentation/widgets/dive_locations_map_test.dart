import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, height: 300, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders entry, exit, site markers and a track line', (
    tester,
  ) async {
    await _pump(
      tester,
      const DiveLocationsMap(
        entry: GeoPoint(12.34567, 98.76543),
        exit: GeoPoint(12.34612, 98.76489),
        site: GeoPoint(12.34000, 98.76000),
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });

  testWidgets('entry-only: no track line, no exit/site markers', (
    tester,
  ) async {
    await _pump(
      tester,
      const DiveLocationsMap(entry: GeoPoint(12.34567, 98.76543)),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsNothing);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsNothing);
  });

  testWidgets('renders nothing when no points are provided', (tester) async {
    await _pump(tester, const DiveLocationsMap());
    expect(find.byType(FlutterMap), findsNothing);
  });
}
