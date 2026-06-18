import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

/// Fake of the narrow bookmark seam so the leased resolver can be tested
/// without a native channel.
class _FakeBookmarkPort implements BackupBookmarkPort {
  _FakeBookmarkPort({this.resolveResult});
  final BackupBookmarkLease? resolveResult;
  final List<String> released = [];
  int resolveCalls = 0;

  @override
  Future<BackupBookmarkLease?> resolve(Uint8List data) async {
    resolveCalls++;
    return resolveResult;
  }

  @override
  Future<void> release(String ref) async => released.add(ref);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences preferences;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
  });

  tearDown(() {
    BackupBookmarkService.debugSupportedOverride = null;
  });

  group('resolveBackupsDirectoryLeased', () {
    test('no custom location -> sandbox default, no bookmark calls', () async {
      final port = _FakeBookmarkPort();

      final lease = await BackupService.resolveBackupsDirectoryLeased(
        preferences,
        bookmarks: port,
      );

      expect(lease.path, contains('Submersion'));
      expect(lease.path, contains('Backups'));
      expect(port.resolveCalls, 0);
      await lease.release(); // no-op; must not throw
    });

    test(
      'Apple + resolvable bookmark -> armed path, releases the ref',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lease_ok_');
        addTearDown(() => tmp.delete(recursive: true));
        await preferences.setBackupLocation('/icloud/dir');
        await preferences.setBackupLocationBookmark([1, 2, 3]);
        BackupBookmarkService.debugSupportedOverride = true;
        final port = _FakeBookmarkPort(
          resolveResult: BackupBookmarkLease(
            ref: 'R',
            path: tmp.path,
            isStale: false,
          ),
        );

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, tmp.path);
        expect(port.resolveCalls, 1);
        await lease.release();
        expect(port.released, ['R']);
      },
    );

    test('Apple + unresolvable bookmark -> resets to default', () async {
      await preferences.setBackupLocation('/icloud/dir');
      await preferences.setBackupLocationBookmark([1, 2, 3]);
      BackupBookmarkService.debugSupportedOverride = true;
      final port = _FakeBookmarkPort(resolveResult: null);

      final lease = await BackupService.resolveBackupsDirectoryLeased(
        preferences,
        bookmarks: port,
      );

      expect(preferences.getSettings().backupLocation, isNull);
      expect(preferences.getBackupLocationBookmark(), isNull);
      expect(lease.path, contains('Submersion'));
      expect(port.resolveCalls, 1);
    });

    test(
      'Apple + custom location but no bookmark -> resets to default',
      () async {
        await preferences.setBackupLocation('/icloud/dir');
        BackupBookmarkService.debugSupportedOverride = true;
        final port = _FakeBookmarkPort();

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(port.resolveCalls, 0);
        expect(preferences.getSettings().backupLocation, isNull);
        expect(lease.path, contains('Submersion'));
      },
    );

    test(
      'non-Apple + custom location -> bare path, no bookmark calls',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lease_bare_');
        addTearDown(() => tmp.delete(recursive: true));
        await preferences.setBackupLocation(tmp.path);
        BackupBookmarkService.debugSupportedOverride = false;
        final port = _FakeBookmarkPort();

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, tmp.path);
        expect(port.resolveCalls, 0);
      },
    );
  });
}
