import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';

import '../../../helpers/test_database.dart';

/// A repository whose [getDeviceId] always throws, to exercise the launch-safe
/// error branch of [SyncInitializer.reconcileDeviceIdentity].
class _ThrowingSyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async {
    throw StateError('boom');
  }
}

/// Tests for the launch-time device-identity reconciliation that recovers a
/// database restore.
///
/// All sync bookkeeping (device id, HLC clock, last-sync timestamp, cursors,
/// deletion log) lives inside the database, so a whole-DB restore silently
/// rewinds it to the backup's snapshot. The device id mirrored in
/// SharedPreferences (the "sentinel") survives the restore, so a launch-time
/// mismatch between the sentinel and the restored in-DB device id is the signal
/// that a restore happened -- and the cue to re-baseline sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncRepository repository;
  late SharedPreferences prefs;
  late SyncInitializer initializer;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SyncRepository();
    initializer = SyncInitializer(syncRepository: repository, prefs: prefs);
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
  });

  group('reconcileDeviceIdentity', () {
    test(
      'seeds the sentinel on first run without touching the baseline',
      () async {
        // Materialize metadata so updateLastSyncTime() (a bare UPDATE) sticks.
        await repository.getOrCreateMetadata();
        await repository.updateLastSyncTime(
          DateTime.fromMillisecondsSinceEpoch(5000),
        );
        final before = await repository.getDeviceId();

        final status = await initializer.reconcileDeviceIdentity();

        expect(
          status,
          DeviceIdentityStatus.seeded,
          reason: 'the first run has no sentinel to compare against',
        );
        expect(
          await repository.getDeviceId(),
          before,
          reason: 'seeding must not change this installation identity',
        );
        expect(
          await repository.getLastSyncTime(),
          isNotNull,
          reason: 'seeding must not wipe a legitimate baseline',
        );

        // The sentinel now exists and matches, so a second run is a no-op.
        expect(
          await initializer.reconcileDeviceIdentity(),
          DeviceIdentityStatus.unchanged,
        );
      },
    );

    test(
      'is a no-op when the sentinel already matches the device id',
      () async {
        // First run seeds the sentinel from the current device id.
        await initializer.reconcileDeviceIdentity();
        await repository.updateLastSyncTime(
          DateTime.fromMillisecondsSinceEpoch(5000),
        );
        await repository.logDeletion(entityType: 'dives', recordId: 'keep-me');

        final status = await initializer.reconcileDeviceIdentity();

        expect(status, DeviceIdentityStatus.unchanged);
        expect(
          await repository.getLastSyncTime(),
          isNotNull,
          reason: 'a matching identity must not trigger a rebaseline',
        );
        expect(
          await repository.getAllDeletions(),
          isNotEmpty,
          reason: 'a matching identity must leave the deletion log intact',
        );
      },
    );

    test('rebaselines and restores the live identity after a restore', () async {
      // Establish this install's identity and seed the out-of-DB sentinel.
      await repository.setDeviceId('live-device');
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.seeded,
      );

      // A restore swaps the whole DB: the in-DB device id becomes the backup's,
      // with a rewound baseline (stale lastSync) and a leftover tombstone.
      await repository.setDeviceId('backup-device');
      await repository.updateLastSyncTime(
        DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await repository.logDeletion(
        entityType: 'dives',
        recordId: 'old-tombstone',
      );

      final status = await initializer.reconcileDeviceIdentity();

      expect(status, DeviceIdentityStatus.rebaselined);
      expect(
        await repository.getDeviceId(),
        'live-device',
        reason:
            'the live identity from the sentinel must replace the '
            "backup's device id",
      );
      expect(
        await repository.getLastSyncTime(),
        isNull,
        reason:
            'the rewound baseline must be cleared so the next sync does a '
            'full reconcile',
      );
      expect(
        await repository.getAllDeletions(),
        isEmpty,
        reason: "the backup's stale tombstones must be cleared",
      );

      // The sentinel now matches the restored identity, so the next launch is a
      // no-op rather than a second rebaseline.
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.unchanged,
      );
    });

    test('returns error and never throws when the lookup fails', () async {
      final throwingInitializer = SyncInitializer(
        syncRepository: _ThrowingSyncRepository(),
        prefs: prefs,
      );

      // Must not throw -- a reconcile failure cannot be allowed to crash launch.
      final status = await throwingInitializer.reconcileDeviceIdentity();

      expect(status, DeviceIdentityStatus.error);
    });
  });
}
