import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_location_service.dart';

void main() {
  test(
    'classifies the emulated volume as internal and others as removable',
    () {
      final opts = classifyExternalDirs([
        '/storage/emulated/0/Android/data/app.submersion/files',
        '/storage/1A2B-3C4D/Android/data/app.submersion/files',
      ]);
      expect(opts[0].isInternal, isTrue);
      expect(opts[1].isInternal, isFalse);
      expect(opts[1].path, contains('1A2B-3C4D'));
    },
  );

  test('a single volume is classified as internal', () {
    final opts = classifyExternalDirs([
      '/storage/emulated/0/Android/data/app.submersion/files',
    ]);
    expect(opts.single.isInternal, isTrue);
  });
}
