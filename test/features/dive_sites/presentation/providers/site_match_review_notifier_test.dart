import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_match_review_notifier_test.mocks.dart';

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository])
GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _dive(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

/// Flush the microtask/event queue so the notifier's async `_init` settles.
Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;

  ProviderContainer makeContainer(List<Dive> eligible) {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    when(
      dives.getDivesNeedingSiteMatch(
        diverId: anyNamed('diverId'),
        limitToIds: anyNamed('limitToIds'),
      ),
    ).thenAnswer((_) async => eligible);
    when(dives.setSite(any, any)).thenAnswer((_) async {});
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const []);
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));

    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(dives),
        siteRepositoryProvider.overrideWithValue(sites),
        diveSiteApiServiceProvider.overrideWithValue(api),
        validatedCurrentDiverIdProvider.overrideWith((ref) => 'diver-1'),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    // Keep the autoDispose provider alive for the test.
    addTearDown(
      container.listen(siteMatchReviewProvider(null), (_, _) {}).close,
    );
    return container;
  }

  test('_init auto-links an existing site and reports it matched', () async {
    final container = makeContainer([_dive('d1', _eastMeters(33))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
      ],
    );

    await _settle();
    final state = container.read(siteMatchReviewProvider(null));

    expect(state.isLoading, false);
    expect(state.matchedCount, 1);
    expect(state.entries.single.siteId, 's1');
    verify(dives.setSite('d1', 's1')).called(1);
  });

  test('_init with no candidates reports no match', () async {
    final container = makeContainer([_dive('d1', const GeoPoint(10, 10))]);

    await _settle();
    final state = container.read(siteMatchReviewProvider(null));

    expect(state.noMatchCount, 1);
    expect(state.entries.single.status, MatchEntryStatus.noMatch);
  });

  test(
    'link applies a chosen candidate and flips the row to matched',
    () async {
      final container = makeContainer([_dive('d1', const GeoPoint(0, 0))]);
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 's-a', name: 'A', location: GeoPoint(0, 0.0030)),
          DiveSite(id: 's-b', name: 'B', location: GeoPoint(0, 0.0034)),
        ],
      );

      await _settle();
      expect(
        container.read(siteMatchReviewProvider(null)).entries.single.status,
        MatchEntryStatus.needsReview,
      );

      await container
          .read(siteMatchReviewProvider(null).notifier)
          .link('d1', 's-b');
      final entry = container
          .read(siteMatchReviewProvider(null))
          .entries
          .single;

      expect(entry.status, MatchEntryStatus.autoMatched);
      expect(entry.siteId, 's-b');
      verify(dives.setSite('d1', 's-b')).called(1);
    },
  );

  test(
    'unlink an auto-matched row with alternatives returns it to review',
    () async {
      final container = makeContainer([_dive('d1', const GeoPoint(0, 0))]);
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          // Within inner -> auto-matched; plus a farther alternative in range.
          DiveSite(id: 's-near', name: 'Near', location: GeoPoint(0, 0.0003)),
          DiveSite(id: 's-far', name: 'Far', location: GeoPoint(0, 0.0030)),
        ],
      );

      await _settle();
      expect(
        container.read(siteMatchReviewProvider(null)).entries.single.status,
        MatchEntryStatus.autoMatched,
      );

      await container.read(siteMatchReviewProvider(null).notifier).unlink('d1');
      final entry = container
          .read(siteMatchReviewProvider(null))
          .entries
          .single;

      expect(entry.status, MatchEntryStatus.needsReview);
      expect(entry.siteId, isNull);
      verify(dives.setSite('d1', null)).called(1);
    },
  );

  test('_init surfaces an error message when matching throws', () async {
    final container = makeContainer(const []);
    when(
      dives.getDivesNeedingSiteMatch(
        diverId: anyNamed('diverId'),
        limitToIds: anyNamed('limitToIds'),
      ),
    ).thenThrow(StateError('boom'));

    await _settle();
    final state = container.read(siteMatchReviewProvider(null));

    expect(state.isLoading, false);
    expect(state.errorMessage, isNotNull);
  });

  test(
    'eligibleImportedDivesProvider returns matchable imported ids',
    () async {
      final container = makeContainer([_dive('d1', _eastMeters(33))]);

      final ids = await container.read(
        eligibleImportedDivesProvider(['d1', 'd2']).future,
      );
      expect(ids, ['d1']);

      final empty = await container.read(
        eligibleImportedDivesProvider(const []).future,
      );
      expect(empty, isEmpty);
    },
  );
}
