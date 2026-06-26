import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/ref_invalidate_on_change.dart';

/// Reproduction + regression for the Riverpod 3 auto-pause assertion:
///
///   Expected pausedActiveSubscriptionCount to be 3, but was 4.
///
/// A `FutureProvider` that self-invalidates from a raw change-stream
/// (`stream.listen((_) => ref.invalidateSelf())`) keeps firing while the
/// provider is paused (its widgets are off-screen via `TickerMode`). The
/// deferred invalidation flushes during the next TickerMode *resume*, cascading
/// a re-entrant pause/invalidate through the provider's `ref.watch` dependents
/// and tripping Riverpod's internal pause-state accounting.
///
/// The raw pattern reproduces the crash; [Ref.invalidateSelfWhen] (which pauses
/// the subscription alongside the provider) must not.
void main() {
  /// Drives [body] in its own error-capturing zone so the assertion that
  /// Riverpod reports through `runBinaryGuarded` -> `Zone.handleUncaughtError`
  /// is observable instead of silently swallowed.
  Future<List<Object>> captureZoneErrors(Future<void> Function() body) async {
    final errors = <Object>[];
    final done = Completer<void>();
    unawaited(
      runZonedGuarded(
        () async {
          await body();
          if (!done.isCompleted) done.complete();
        },
        (error, _) {
          errors.add(error);
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    await done.future;
    return errors;
  }

  /// Builds the gas-switch-style graph: a self-invalidating base provider with
  /// two dependents that `await ref.watch(base.future)`, subscribes to all
  /// three like on-screen widgets, then pauses everything, fires a change while
  /// paused, and resumes the base subscription (mirroring a TickerMode resume).
  Future<List<Object>> runPauseResume(
    void Function(Ref ref, Stream<void> changes) wire,
  ) {
    return captureZoneErrors(() async {
      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);

      final baseProvider = FutureProvider.family<List<int>, String>((ref, id) {
        wire(ref, changes.stream);
        // A fresh (non-const) list each build so a rebuild actually notifies
        // dependents, matching a DB-query-backed provider.
        return [1, 2, 3];
      });
      final depBool = FutureProvider.family<bool, String>((ref, id) async {
        final v = await ref.watch(baseProvider(id).future);
        return v.isNotEmpty;
      });
      final depLen = FutureProvider.family<int, String>((ref, id) async {
        final v = await ref.watch(baseProvider(id).future);
        return v.length;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final base = container.listen(baseProvider('d'), (_, _) {});
      final a = container.listen(depBool('d'), (_, _) {});
      final b = container.listen(depLen('d'), (_, _) {});

      await container.read(baseProvider('d').future);
      await container.read(depBool('d').future);
      await container.read(depLen('d').future);

      // Page off-screen: every subscription pauses.
      base.pause();
      a.pause();
      b.pause();

      // Background sync writes the DB while off-screen.
      changes.add(null);
      await Future<void>.delayed(Duration.zero);

      // Page returns: the base widget's subscription resumes first and flushes
      // the dirty provider while the dependents are still paused.
      base.resume();
      await Future<void>.delayed(Duration.zero);
    });
  }

  test(
    'raw stream.listen((_) => ref.invalidateSelf()) trips the pause assertion '
    'on resume (reproduction)',
    () async {
      final errors = await runPauseResume((ref, changes) {
        final sub = changes.listen((_) => ref.invalidateSelf());
        ref.onDispose(sub.cancel);
      });
      // Documents the bug: the raw pattern reports the pause-state assertion.
      expect(errors, isNotEmpty);
      expect(
        errors.first.toString(),
        contains('pausedActiveSubscriptionCount'),
      );
    },
  );

  test('Ref.invalidateSelfWhen pauses with the provider and does not trip the '
      'assertion on resume', () async {
    final errors = await runPauseResume((ref, changes) {
      ref.invalidateSelfWhen(changes);
    });
    expect(errors, isEmpty);
  });
}
