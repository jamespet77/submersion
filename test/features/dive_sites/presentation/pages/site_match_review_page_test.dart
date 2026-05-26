import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Seeds review state without running the async matcher (autoInit:false) and
/// sets the protected `state` from inside a subclass to avoid the
/// invalid_use_of_protected_member lint.
class _SeededNotifier extends SiteMatchReviewNotifier {
  _SeededNotifier(Ref ref, SiteMatchReviewState seeded)
    : super(ref, null, autoInit: false) {
    state = seeded;
  }
}

Dive _dive(int number) => Dive(
  id: 'd$number',
  diveNumber: number,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
);

Widget _harness(SiteMatchReviewState seeded) => ProviderScope(
  overrides: [
    siteMatchReviewProvider(
      null,
    ).overrideWith((ref) => _SeededNotifier(ref, seeded)),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SiteMatchReviewPage(),
  ),
);

void main() {
  testWidgets('loading state shows a progress indicator', (tester) async {
    await tester.pumpWidget(_harness(const SiteMatchReviewState()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows the message', (tester) async {
    await tester.pumpWidget(
      _harness(
        const SiteMatchReviewState(isLoading: false, errorMessage: 'Boom'),
      ),
    );
    await tester.pump();
    expect(find.text('Boom'), findsOneWidget);
  });

  testWidgets('empty state shows nothing-to-match', (tester) async {
    await tester.pumpWidget(
      _harness(const SiteMatchReviewState(isLoading: false, entries: [])),
    );
    await tester.pump();
    expect(find.text('Nothing to match.'), findsOneWidget);
  });

  testWidgets('auto-matched row shows summary, site, and expands to actions', (
    tester,
  ) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      entries: [
        DiveMatchEntry(
          dive: _dive(7),
          status: MatchEntryStatus.autoMatched,
          siteId: 's1',
          siteName: 'Blue Hole',
          distanceMeters: 42,
          candidates: const [
            MatchCandidateView(
              id: 's1',
              name: 'Blue Hole',
              isExisting: true,
              distanceMeters: 42,
            ),
            MatchCandidateView(
              id: 'osm_1',
              name: 'Reef',
              isExisting: false,
              distanceMeters: 300,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.textContaining('1 matched'), findsOneWidget);
    expect(find.text('Blue Hole · 42 m'), findsOneWidget);

    // Expand to reveal Unlink + alternative candidates.
    await tester.tap(find.text('Dive #7'));
    await tester.pumpAndSettle();
    expect(find.text('Unlink'), findsOneWidget);
    expect(find.text('Reef'), findsOneWidget);
    expect(find.text('300 m · import'), findsOneWidget);
  });

  testWidgets(
    'tapping Unlink returns an auto-matched row with alternatives to review',
    (tester) async {
      final seeded = SiteMatchReviewState(
        isLoading: false,
        entries: [
          DiveMatchEntry(
            dive: _dive(7),
            status: MatchEntryStatus.autoMatched,
            siteId: 's1',
            siteName: 'Blue Hole',
            distanceMeters: 42,
            candidates: const [
              MatchCandidateView(
                id: 's1',
                name: 'Blue Hole',
                isExisting: true,
                distanceMeters: 42,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_harness(seeded));
      await tester.pump();
      await tester.tap(find.text('Dive #7'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      // Row flips to review (one nearby site retained) and summary updates.
      expect(find.textContaining('1 to review'), findsOneWidget);
      expect(find.text('Blue Hole · 42 m'), findsNothing);
    },
  );

  testWidgets('needs-review row lists candidates with distance and source', (
    tester,
  ) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      entries: [
        DiveMatchEntry(
          dive: _dive(3),
          status: MatchEntryStatus.needsReview,
          candidates: const [
            MatchCandidateView(
              id: 's-a',
              name: 'Site A',
              isExisting: true,
              distanceMeters: 320,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.text('1 nearby sites'), findsOneWidget);
    await tester.tap(find.text('Dive #3'));
    await tester.pumpAndSettle();
    expect(find.text('Site A'), findsOneWidget);
    expect(find.text('320 m · your site'), findsOneWidget);
  });

  testWidgets('no-match row shows no nearby site', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      entries: [
        DiveMatchEntry(dive: _dive(9), status: MatchEntryStatus.noMatch),
      ],
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('No nearby site'), findsOneWidget);
  });

  testWidgets('newly-created bundled match shows the newly-added suffix', (
    tester,
  ) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      entries: [
        DiveMatchEntry(
          dive: _dive(1),
          status: MatchEntryStatus.autoMatched,
          siteId: 'new-1',
          siteName: 'Wreck',
          distanceMeters: 20,
          isNewlyCreated: true,
        ),
      ],
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('Wreck · 20 m · newly added'), findsOneWidget);
  });
}
