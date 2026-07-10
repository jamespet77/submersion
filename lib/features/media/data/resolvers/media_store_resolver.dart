import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Store-backed fallback resolution (design spec section 10). Deliberately
/// NOT a MediaSourceResolver and never registered under a MediaSourceType:
/// rows keep their native source type, so disconnecting the store degrades
/// every row to exactly the pre-store behavior.
class MediaStoreResolver {
  MediaStoreResolver({
    required MediaObjectStore store,
    required MediaCacheStore cache,
  }) : _store = store,
       _cache = cache;

  final MediaObjectStore _store;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(MediaStoreResolver);

  /// Returns FileData when the bytes are cached or fetched (originals are
  /// hash-verified); null when this item is not confirmed in the store or
  /// any error occurs (the caller keeps its native UnavailableData).
  ///
  /// Thumbnail requests route to the thumb object when one was uploaded
  /// and degrade to the original otherwise (spec section 10).
  Future<MediaSourceData?> tryResolveRemote(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    final hash = item.contentHash;
    if (hash == null || item.remoteUploadedAt == null) return null;
    if (thumbnail && item.remoteThumbUploadedAt != null) {
      final thumb = await _fetchThumb(item, hash);
      if (thumb != null) return thumb;
      // Fall through: a missing/broken thumb degrades to the original.
    }
    return _fetchOriginal(item, hash);
  }

  Future<MediaSourceData?> _fetchThumb(MediaItem item, String hash) async {
    try {
      final cached = await _cache.get(hash, MediaCacheKind.thumb);
      if (cached != null) return FileData(file: cached);
      final staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.thumbKey(hash), staging);
      // No hash verification: thumb bytes are derived; the key carries the
      // original's hash purely for addressing.
      final file = await _cache.put(hash, MediaCacheKind.thumb, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Thumb fetch failed for ${item.id}: $e');
      return null;
    }
  }

  Future<MediaSourceData?> _fetchOriginal(MediaItem item, String hash) async {
    try {
      final cached = await _cache.get(hash, MediaCacheKind.original);
      if (cached != null) return FileData(file: cached);

      final staging = await _cache.stagingFile();
      final extension = StoreKeys.extensionFor(item.originalFilename);
      await _store.getFile(
        StoreKeys.objectKey(hash, extension: extension),
        staging,
      );
      final digest = await sha256OfFile(staging);
      if (digest.hash != hash) {
        _log.warning('Store object failed hash verification for ${item.id}');
        await staging.delete();
        return null;
      }
      final file = await _cache.put(hash, MediaCacheKind.original, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Store fallback failed for ${item.id}: $e');
      return null;
    }
  }
}
