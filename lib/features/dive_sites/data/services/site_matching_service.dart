import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_matcher.dart';

enum MatchEntryStatus { autoMatched, needsReview, noMatch }

/// A display candidate for the review screen (resolved name + distance).
class MatchCandidateView {
  final String id; // existing site id or bundled externalId
  final String name;
  final bool isExisting;
  final double distanceMeters;

  const MatchCandidateView({
    required this.id,
    required this.name,
    required this.isExisting,
    required this.distanceMeters,
  });
}

/// The site actually linked by an apply (resolves a bundled externalId to the
/// real created/linked DiveSites row id).
class AppliedMatch {
  final String siteId; // a real DiveSites row id, never a bundled externalId
  final String siteName;
  final bool isNewlyCreated;

  const AppliedMatch({
    required this.siteId,
    required this.siteName,
    required this.isNewlyCreated,
  });
}

/// One dive's matching result, ready for the UI.
class DiveMatchEntry {
  final Dive dive;
  final MatchEntryStatus status;
  final String? siteId; // when matched
  final String? siteName; // when matched
  final double? distanceMeters;
  final bool isNewlyCreated; // bundled site materialised by this match
  final List<MatchCandidateView> candidates; // for needsReview

  const DiveMatchEntry({
    required this.dive,
    required this.status,
    this.siteId,
    this.siteName,
    this.distanceMeters,
    this.isNewlyCreated = false,
    this.candidates = const [],
  });

  DiveMatchEntry copyWith({
    MatchEntryStatus? status,
    String? siteId,
    String? siteName,
    double? distanceMeters,
    bool? isNewlyCreated,
    List<MatchCandidateView>? candidates,
    bool clearSite = false,
  }) {
    return DiveMatchEntry(
      dive: dive,
      status: status ?? this.status,
      siteId: clearSite ? null : (siteId ?? this.siteId),
      siteName: clearSite ? null : (siteName ?? this.siteName),
      distanceMeters: clearSite
          ? null
          : (distanceMeters ?? this.distanceMeters),
      isNewlyCreated: clearSite
          ? false
          : (isNewlyCreated ?? this.isNewlyCreated),
      candidates: candidates ?? this.candidates,
    );
  }
}

/// Resolved candidate objects retained per dive so the UI can apply by id.
class _CandidateRef {
  final DiveSite? existing; // non-null when existing
  final ExternalDiveSite? bundled; // non-null when bundled
  const _CandidateRef.existing(this.existing) : bundled = null;
  const _CandidateRef.bundled(this.bundled) : existing = null;
}

/// Gathers candidates, runs the matcher, and applies results for one review
/// session. Stateful: it tracks batch dedup and rollback bookkeeping.
class SiteMatchingService {
  SiteMatchingService({
    required SiteRepository siteRepository,
    required DiveSiteApiService apiService,
    required DiveRepository diveRepository,
    required this.diverId,
    required this.thresholds,
  }) : _siteRepository = siteRepository,
       _apiService = apiService,
       _diveRepository = diveRepository;

  final SiteRepository _siteRepository;
  final DiveSiteApiService _apiService;
  final DiveRepository _diveRepository;
  final String? diverId;
  final MatchThresholds thresholds;

  static const double _coincidenceMeters = 100;

  // Per-session state.
  List<DiveSite> _userSites = const [];
  final Map<String, String> _createdByExternalId = {}; // externalId -> site id
  final Map<String, Set<String>> _createdSiteRefs = {}; // created id -> diveIds
  final Map<String, Map<String, _CandidateRef>> _refsByDive = {};
  final Map<String, String> _appliedSiteByDive = {};

  GeoPoint? _pointFor(Dive dive) => dive.entryLocation ?? dive.exitLocation;

  Future<List<DiveMatchEntry>> run(List<Dive> dives) async {
    _userSites = (await _siteRepository.getAllSites(
      diverId: diverId,
    )).where((s) => s.location != null).toList();

    final entries = <DiveMatchEntry>[];
    for (final dive in dives) {
      final point = _pointFor(dive);
      if (point == null) continue;

      final bundled = await _apiService.searchNearby(
        latitude: point.latitude,
        longitude: point.longitude,
        radiusKm: thresholds.outerRadiusMeters / 1000.0,
      );

      final refs = <String, _CandidateRef>{};
      final candidates = <MatchCandidate>[];
      for (final s in _userSites) {
        refs[s.id] = _CandidateRef.existing(s);
        candidates.add(
          MatchCandidate(id: s.id, location: s.location!, isExisting: true),
        );
      }
      for (final b in bundled.sites) {
        if (!b.hasCoordinates) continue;
        refs[b.externalId] = _CandidateRef.bundled(b);
        candidates.add(
          MatchCandidate(
            id: b.externalId,
            location: GeoPoint(b.latitude!, b.longitude!),
            isExisting: false,
          ),
        );
      }
      _refsByDive[dive.id] = refs;

      // Display views for every in-range candidate, so auto-matched rows can
      // still offer "Change" and review rows can list alternatives.
      final rankedViews =
          candidates
              .map(
                (c) => MatchCandidateView(
                  id: c.id,
                  name: _nameOf(refs[c.id]!),
                  isExisting: c.isExisting,
                  distanceMeters: distanceMeters(point, c.location),
                ),
              )
              .where((v) => v.distanceMeters <= thresholds.outerRadiusMeters)
              .toList()
            ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      final outcome = matchDive(
        point: point,
        candidates: candidates,
        thresholds: thresholds,
      );
      entries.add(await _toEntry(dive, outcome, refs, rankedViews));
    }
    return entries;
  }

  Future<DiveMatchEntry> _toEntry(
    Dive dive,
    SiteMatchOutcome outcome,
    Map<String, _CandidateRef> refs,
    List<MatchCandidateView> rankedViews,
  ) async {
    switch (outcome) {
      case NoMatch():
        return DiveMatchEntry(dive: dive, status: MatchEntryStatus.noMatch);
      case Suggested():
        return DiveMatchEntry(
          dive: dive,
          status: MatchEntryStatus.needsReview,
          candidates: rankedViews,
        );
      case AutoMatch(:final siteId, :final distanceMeters):
        final applied = await _applyCandidate(dive.id, refs[siteId]!);
        _appliedSiteByDive[dive.id] = applied.siteId;
        return DiveMatchEntry(
          dive: dive,
          status: MatchEntryStatus.autoMatched,
          siteId: applied.siteId,
          siteName: applied.siteName,
          distanceMeters: distanceMeters,
          isNewlyCreated: applied.isNewlyCreated,
          candidates: rankedViews,
        );
    }
  }

  String _nameOf(_CandidateRef ref) => ref.existing?.name ?? ref.bundled!.name;

  /// Applies a user-chosen candidate; returns the real applied site (resolving
  /// a bundled externalId to its created site id), or null if it is gone.
  Future<AppliedMatch?> link(String diveId, String candidateId) async {
    await unlink(diveId); // clear any prior link (and roll back its orphan)
    final ref = _refsByDive[diveId]?[candidateId];
    if (ref == null) return null;
    final applied = await _applyCandidate(diveId, ref);
    _appliedSiteByDive[diveId] = applied.siteId;
    return applied;
  }

  Future<void> unlink(String diveId) async {
    final prior = _appliedSiteByDive.remove(diveId);
    // Nothing was applied by this session -> no DB write or sync event needed.
    if (prior == null) return;
    await _diveRepository.setSite(diveId, null);

    final refs = _createdSiteRefs[prior];
    if (refs != null) {
      refs.remove(diveId);
      if (refs.isEmpty) {
        _createdSiteRefs.remove(prior);
        _createdByExternalId.removeWhere((_, id) => id == prior);
        await _siteRepository.deleteSite(prior);
      }
    }
  }

  Future<AppliedMatch> _applyCandidate(String diveId, _CandidateRef ref) async {
    if (ref.existing != null) {
      final site = ref.existing!;
      await _diveRepository.setSite(diveId, site.id);
      _track(site.id, diveId, created: false);
      return AppliedMatch(
        siteId: site.id,
        siteName: site.name,
        isNewlyCreated: false,
      );
    }

    final bundled = ref.bundled!;
    final point = GeoPoint(bundled.latitude!, bundled.longitude!);

    // Batch dedup: already materialised this bundled site in this session?
    final existingNewId = _createdByExternalId[bundled.externalId];
    if (existingNewId != null) {
      await _diveRepository.setSite(diveId, existingNewId);
      _track(existingNewId, diveId, created: true);
      return AppliedMatch(
        siteId: existingNewId,
        siteName: bundled.name,
        isNewlyCreated: true,
      );
    }

    // Coincidence guard: an existing user site essentially here?
    for (final s in _userSites) {
      if (distanceMeters(point, s.location!) <= _coincidenceMeters) {
        await _diveRepository.setSite(diveId, s.id);
        _track(s.id, diveId, created: false);
        return AppliedMatch(
          siteId: s.id,
          siteName: s.name,
          isNewlyCreated: false,
        );
      }
    }

    // Materialise.
    final created = await _siteRepository.createSite(
      bundled.toDiveSite(diverId: diverId),
    );
    _createdByExternalId[bundled.externalId] = created.id;
    await _diveRepository.setSite(diveId, created.id);
    _track(created.id, diveId, created: true);
    return AppliedMatch(
      siteId: created.id,
      siteName: created.name,
      isNewlyCreated: true,
    );
  }

  void _track(String siteId, String diveId, {required bool created}) {
    if (!created) return;
    (_createdSiteRefs[siteId] ??= <String>{}).add(diveId);
  }
}
