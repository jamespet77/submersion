import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';

import 'site_matching_service_test.mocks.dart';

// ~0.001 deg longitude at the equator is ~111 m. Build points by metres east.
GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _diveAt(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository])
void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;

  SiteMatchingService service() => SiteMatchingService(
    siteRepository: sites,
    apiService: api,
    diveRepository: dives,
    diverId: 'diver-1',
    thresholds: SiteMatchSensitivity.balanced.thresholds,
  );

  setUp(() {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const []);
    when(dives.setSite(any, any)).thenAnswer((_) async {});
    when(sites.deleteSite(any)).thenAnswer((_) async {});
  });

  test('auto-links an existing site within inner radius', () async {
    const existing = DiveSite(
      id: 's1',
      name: 'Blue Hole',
      location: GeoPoint(0, 0),
    );
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => [existing]);

    final entries = await service().run([_diveAt('d1', _eastMeters(33))]);

    expect(entries.single.status, MatchEntryStatus.autoMatched);
    expect(entries.single.siteId, 's1');
    verify(dives.setSite('d1', 's1')).called(1);
  });

  test('no candidates -> noMatch, no write', () async {
    final entries = await service().run([
      _diveAt('d1', const GeoPoint(10, 10)),
    ]);

    expect(entries.single.status, MatchEntryStatus.noMatch);
    verifyNever(dives.setSite(any, any));
  });

  test(
    'materialises a bundled site once for two dives (batch dedup)',
    () async {
      when(
        api.searchNearby(
          latitude: anyNamed('latitude'),
          longitude: anyNamed('longitude'),
          radiusKm: anyNamed('radiusKm'),
        ),
      ).thenAnswer(
        (_) async => const DiveSiteSearchResult(
          sites: [
            ExternalDiveSite(
              externalId: 'osm_1',
              name: 'Wreck',
              latitude: 0,
              longitude: 0,
              source: 'OpenStreetMap',
            ),
          ],
        ),
      );
      when(sites.createSite(any)).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-site-1');
      });

      final entries = await service().run([
        _diveAt('d1', _eastMeters(22)),
        _diveAt('d2', _eastMeters(33)),
      ]);

      expect(
        entries.every((e) => e.status == MatchEntryStatus.autoMatched),
        true,
      );
      expect(entries.every((e) => e.siteId == 'new-site-1'), true);
      expect(entries.first.isNewlyCreated, true);
      verify(sites.createSite(any)).called(1); // created once, linked twice
      verify(dives.setSite('d1', 'new-site-1')).called(1);
      verify(dives.setSite('d2', 'new-site-1')).called(1);
    },
  );

  test(
    'coincidence guard links existing site instead of creating bundled',
    () async {
      // Existing site at ~160 m (outside inner 150, so precedence does not fire),
      // bundled at ~140 m (inside inner -> auto), and the two are ~20 m apart so
      // the guard fires at apply time.
      final existing = DiveSite(
        id: 's-exist',
        name: 'Known Reef',
        location: _eastMeters(160),
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => [existing]);
      when(
        api.searchNearby(
          latitude: anyNamed('latitude'),
          longitude: anyNamed('longitude'),
          radiusKm: anyNamed('radiusKm'),
        ),
      ).thenAnswer(
        (_) async => DiveSiteSearchResult(
          sites: [
            ExternalDiveSite(
              externalId: 'osm_2',
              name: 'Reef',
              latitude: 0,
              longitude: _eastMeters(140).longitude,
              source: 'OpenStreetMap',
            ),
          ],
        ),
      );

      await service().run([_diveAt('d1', const GeoPoint(0, 0))]);

      verify(dives.setSite('d1', 's-exist')).called(1);
      verifyNever(sites.createSite(any));
    },
  );

  test(
    'unlink clears site and deletes an orphaned created bundled site',
    () async {
      when(
        api.searchNearby(
          latitude: anyNamed('latitude'),
          longitude: anyNamed('longitude'),
          radiusKm: anyNamed('radiusKm'),
        ),
      ).thenAnswer(
        (_) async => const DiveSiteSearchResult(
          sites: [
            ExternalDiveSite(
              externalId: 'osm_1',
              name: 'Wreck',
              latitude: 0,
              longitude: 0,
              source: 'OpenStreetMap',
            ),
          ],
        ),
      );
      when(sites.createSite(any)).thenAnswer(
        (inv) async =>
            (inv.positionalArguments.first as DiveSite).copyWith(id: 'new-1'),
      );

      final s = service();
      await s.run([_diveAt('d1', _eastMeters(22))]);
      await s.unlink('d1');

      verify(dives.setSite('d1', null)).called(1);
      verify(sites.deleteSite('new-1')).called(1);
    },
  );

  test('link applies a user-chosen candidate to a needsReview dive', () async {
    const a = DiveSite(id: 's-a', name: 'A', location: GeoPoint(0, 0.0030));
    const b = DiveSite(id: 's-b', name: 'B', location: GeoPoint(0, 0.0034));
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const [a, b]); // both >150 m, <1000 m

    final s = service();
    final entries = await s.run([_diveAt('d1', const GeoPoint(0, 0))]);
    expect(entries.single.status, MatchEntryStatus.needsReview);

    final applied = await s.link('d1', 's-b');
    expect(applied?.siteId, 's-b');
    verify(dives.setSite('d1', 's-b')).called(1);
  });
}
