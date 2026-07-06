import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

/// Sweeps GPS-less dives against recorded tracks and stamps entry/exit
/// positions. Single choke point for all three triggers (import-time,
/// track-arrival, manual) so matching behavior cannot diverge between them.
class GpsTrackMatchService {
  final GpsTrackRepository _trackRepository;
  final DiveRepository _diveRepository;

  GpsTrackMatchService({
    required GpsTrackRepository trackRepository,
    required DiveRepository diveRepository,
  }) : _trackRepository = trackRepository,
       _diveRepository = diveRepository;

  /// Returns ids of dives that received a GPS position. Only dives with no
  /// entry GPS are candidates; existing positions are never overwritten.
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    // Close out any track a crash left open before matching against it.
    await _trackRepository.recoverOrphanedTracks();

    final candidates = await _diveRepository.getDivesMissingEntryGps(
      limitToIds: limitToIds,
    );
    if (candidates.isEmpty) return [];

    final tracks = await _trackRepository.getCompletedTracks(
      includePoints: true,
    );
    if (tracks.isEmpty) return [];

    final stamped = <String>[];
    for (final dive in candidates) {
      final track = GpsTrackMatcher.trackCovering(tracks, dive.startMs);
      if (track == null) continue;
      final entry = GpsTrackMatcher.positionAt(
        track.points,
        dive.startMs ~/ 1000,
      );
      if (entry == null) continue;
      final exit = dive.endMs != null
          ? GpsTrackMatcher.positionAt(track.points, dive.endMs! ~/ 1000)
          : null;
      await _diveRepository.setDiveGps(
        dive.id,
        entryLatitude: entry.latitude,
        entryLongitude: entry.longitude,
        exitLatitude: exit?.latitude,
        exitLongitude: exit?.longitude,
      );
      stamped.add(dive.id);
    }
    return stamped;
  }
}
