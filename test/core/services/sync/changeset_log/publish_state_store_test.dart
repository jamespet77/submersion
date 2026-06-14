import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';

void main() {
  late AppDatabase db;
  late PublishStateStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = PublishStateStore(db);
  });
  tearDown(() => db.close());

  test('get returns null before any publish', () async {
    expect(await store.get('s3'), isNull);
  });

  test('upsert round-trips and overwrites', () async {
    await store.upsert(
      LocalPublishStatesCompanion(
        provider: const Value('s3'),
        baseSeq: const Value(10),
        headSeq: const Value(12),
        publishedHlcHigh: const Value('000000000000100:000000:dev'),
        changesetBytesSinceBase: const Value(2048),
        updatedAt: const Value(1),
      ),
    );
    var s = await store.get('s3');
    expect(s!.headSeq, 12);
    expect(s.publishedHlcHigh, '000000000000100:000000:dev');

    await store.upsert(
      LocalPublishStatesCompanion(
        provider: const Value('s3'),
        headSeq: const Value(15),
        updatedAt: const Value(2),
      ),
    );
    s = await store.get('s3');
    expect(s!.headSeq, 15);
  });

  test('resetForProvider clears only that provider', () async {
    await store.upsert(
      LocalPublishStatesCompanion(
        provider: const Value('s3'),
        updatedAt: const Value(1),
      ),
    );
    await store.upsert(
      LocalPublishStatesCompanion(
        provider: const Value('icloud'),
        updatedAt: const Value(1),
      ),
    );
    await store.resetForProvider('s3');
    expect(await store.get('s3'), isNull);
    expect(await store.get('icloud'), isNotNull);
  });
}
