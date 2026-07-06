import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';

final gpsTrackRepositoryProvider = Provider<GpsTrackRepository>(
  (ref) => GpsTrackRepository(),
);

final gpsTrackMatchServiceProvider = Provider<GpsTrackMatchService>(
  (ref) => GpsTrackMatchService(
    trackRepository: ref.watch(gpsTrackRepositoryProvider),
    diveRepository: ref.watch(diveRepositoryProvider),
  ),
);
