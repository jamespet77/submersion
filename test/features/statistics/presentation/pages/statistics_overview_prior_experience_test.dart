import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveStatistics _stats() => DiveStatistics(
  totalDives: 312,
  totalTimeSeconds: 43 * 3600,
  maxDepth: 30,
  avgMaxDepth: 18,
  totalSites: 5,
  firstDiveDate: DateTime(2020),
);

Diver _diver({int? count, int? seconds, DateTime? since}) => Diver(
  id: 'd1',
  name: 'A',
  priorDiveCount: count,
  priorDiveTimeSeconds: seconds,
  divingSince: since,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(WidgetTester tester, Diver diver) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveStatisticsProvider.overrideWith((ref) async => _stats()),
        currentDiverProvider.overrideWith((ref) async => diver),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatisticsOverviewPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows combined total + breakdown + diving since', (
    tester,
  ) async {
    await _pump(
      tester,
      _diver(count: 1200, seconds: 1150 * 3600, since: DateTime(1990)),
    );
    expect(find.textContaining('1512'), findsWidgets);
    expect(find.textContaining('logged'), findsWidgets);
    expect(find.textContaining('1990'), findsOneWidget);
  });

  testWidgets('no prior experience -> logged-only, no breakdown', (
    tester,
  ) async {
    await _pump(tester, _diver());
    expect(find.text('312'), findsOneWidget);
    expect(find.textContaining('prior'), findsNothing);
    expect(find.textContaining('Diving since'), findsNothing);
  });
}
