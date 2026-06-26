import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pause-aware self-invalidation for providers that refresh off a repository
/// change-tick stream.
extension RefInvalidateOnChange on Ref {
  /// Rebuilds this provider whenever [changes] emits, while still participating
  /// in Riverpod's auto-pause.
  ///
  /// The naive form -- `changes.listen((_) => ref.invalidateSelf())` -- opens a
  /// raw [StreamSubscription] that Riverpod cannot see. When the provider is
  /// paused (its widgets leave the screen and `TickerMode` disables), that
  /// subscription keeps firing and marks the provider dirty. The deferred
  /// rebuild then flushes during the next TickerMode *resume*, cascading a
  /// re-entrant pause/invalidate through this provider's `ref.watch` dependents
  /// and tripping Riverpod 3's internal `pausedActiveSubscriptionCount`
  /// assertion (`Expected pausedActiveSubscriptionCount to be N, but was N+1`).
  ///
  /// Pausing the subscription alongside the provider -- exactly what
  /// `StreamProvider` does for its own stream via `onCancel`/`onResume` -- keeps
  /// the provider clean while off-screen, so the resume flush is a no-op. The
  /// change-tick streams are single-subscription (a debounced
  /// [StreamController]), so a tick fired while paused is buffered and delivered
  /// on resume; the detail still refreshes after a background sync.
  void invalidateSelfWhen(Stream<void> changes) {
    final sub = changes.listen((_) => invalidateSelf());
    onCancel(() => sub.pause());
    onResume(() => sub.resume());
    onDispose(sub.cancel);
  }
}
