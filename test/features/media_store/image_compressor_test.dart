import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/image_compressor.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'support/fake_local_file_resolver.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;
  late ImageCompressor compressor;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('img_compress');
    cache = MediaCacheStore(database: db, root: root);
    compressor = ImageCompressor(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: FakeLocalFileResolver(),
      }),
      cache: cache,
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem photo() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'shot.png',
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<File> stagedPng(int width, int height) async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(
      img.encodePng(img.Image(width: width, height: height)),
      flush: true,
    );
    return f;
  }

  test('downsizes a large image to the level ceiling and emits jpg', () async {
    final result = await compressor.compress(
      photo(),
      await stagedPng(4000, 3000),
      MediaUploadQuality.balanced,
    );
    expect(result, isNotNull);
    expect(result!.ext, 'jpg');
    final decoded = img.decodeJpg(await result.file.readAsBytes())!;
    expect(decoded.width, 2048); // balanced ceiling, aspect preserved
  });

  test(
    'returns null (upload original) when already under the ceiling',
    () async {
      final result = await compressor.compress(
        photo(),
        await stagedPng(800, 600),
        MediaUploadQuality.balanced,
      );
      expect(result, isNull);
    },
  );

  test('original level never compresses', () async {
    final result = await compressor.compress(
      photo(),
      await stagedPng(4000, 3000),
      MediaUploadQuality.original,
    );
    expect(result, isNull);
  });
}
