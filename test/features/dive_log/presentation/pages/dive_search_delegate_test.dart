import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveSummary _summary(int i) => DiveSummary(
  id: 'd$i',
  diveNumber: i,
  name: 'Dive $i',
  dateTime: DateTime(2026, 1, 1).add(Duration(days: i)),
  maxDepth: 20.0 + i,
  bottomTime: const Duration(minutes: 40),
  waterTemp: 25,
  rating: 3,
  siteName: 'Blue Hole $i',
  sortTimestamp: DateTime(
    2026,
    1,
    1,
  ).add(Duration(days: i)).millisecondsSinceEpoch,
);

/// Opens [DiveSearchDelegate] via `showSearch` and types [query], with the
/// search provider overridden to return [results] regardless of the term.
Future<void> _openSearch(
  WidgetTester tester,
  List<DiveSummary> results, {
  String query = 'blue',
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveSearchProvider.overrideWith((ref, q) async => results),
      ].cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSearch(
                  context: context,
                  delegate: DiveSearchDelegate(ref),
                ),
                child: const Text('open-search'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open-search'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders matching dives as tiles without a limit notice', (
    tester,
  ) async {
    await _openSearch(tester, [_summary(1), _summary(2), _summary(3)]);

    expect(find.byType(DiveListTile), findsNWidgets(3));
    expect(find.textContaining('Showing the first'), findsNothing);
  });

  testWidgets('shows the limit notice when the result bound is hit', (
    tester,
  ) async {
    final results = List.generate(
      DiveRepository.searchResultLimit,
      (i) => _summary(i),
    );
    await _openSearch(tester, results);

    // The notice lives past the fold; force the results list to build it by
    // scrolling the ListView's own Scrollable (not the search bar's).
    await tester.scrollUntilVisible(
      find.textContaining('Showing the first'),
      400,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('Showing the first'), findsOneWidget);
  });
}
