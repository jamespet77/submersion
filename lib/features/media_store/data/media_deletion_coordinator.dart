import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Wraps media-row deletion with the remote-blob delete fast path
/// (orphan-prevention spec 5.2): the delete INTENT is enqueued BEFORE the
/// row dies - the queue lives in a different database, so no cross-DB
/// transaction exists, and this ordering makes the only crash window
/// harmless (an intent whose row survived no-ops on the drain-time
/// refcount). Enqueue problems never block the deletion itself; missed
/// intents fall to the Verify Library sweep.
///
/// Single-enqueuer rule (spec 5.4): only user-action deletion flows go
/// through this coordinator. Sync tombstone application deletes rows
/// directly and must never enqueue remote deletes.
class MediaDeletionCoordinator {
  MediaDeletionCoordinator({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository Function() queue,
    Future<void> Function()? kickWorker,
  }) : _mediaRepository = mediaRepository,
       _queue = queue,
       _kickWorker = kickWorker;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository Function() _queue;
  final Future<void> Function()? _kickWorker;
  final _log = LoggerService.forClass(MediaDeletionCoordinator);

  Future<void> deleteMedia(String id) => deleteMultipleMedia([id]);

  Future<void> deleteMultipleMedia(List<String> ids) async {
    var enqueued = false;
    for (final id in ids) {
      // Untyped catch on purpose: an uninitialized
      // LocalCacheDatabaseService throws StateError (an Error, not an
      // Exception), and no media-store problem may ever block the user's
      // deletion.
      try {
        if (await _enqueueIntent(id)) enqueued = true;
      } catch (e, stackTrace) {
        _log.warning(
          'Could not enqueue remote delete for media $id '
          '(sweep will reconcile)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (ids.length == 1) {
      await _mediaRepository.deleteMedia(ids.single);
    } else {
      await _mediaRepository.deleteMultipleMedia(ids);
    }
    if (enqueued && _kickWorker != null) {
      try {
        await _kickWorker();
      } catch (e) {
        _log.warning('Worker kick after media delete failed', error: e);
      }
    }
  }

  Future<bool> _enqueueIntent(String id) async {
    final item = await _mediaRepository.getMediaById(id);
    final hash = item?.contentHash;
    if (item == null || hash == null || hash.isEmpty) return false;
    final everUploaded =
        item.remoteUploadedAt != null ||
        item.remoteThumbUploadedAt != null ||
        item.remoteCompressedUploadedAt != null;
    if (!everUploaded) return false;
    await _queue().enqueueDelete(
      mediaId: id,
      contentHash: hash,
      originalExt: StoreKeys.extensionFor(item.originalFilename),
      renditionExt: item.mediaType == MediaType.video ? 'mp4' : 'jpg',
    );
    return true;
  }
}
