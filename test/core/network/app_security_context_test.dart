import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/app_security_context.dart';
import 'package:submersion/core/network/embedded_ca_bundle.dart';

void main() {
  group('buildWindowsSecurityContext', () {
    test('returns null when no native roots and no fallback are available', () {
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => const [],
        fallbackBundlePem: '',
      );

      expect(context, isNull);
    });

    test(
      'builds a context from the embedded fallback when native is empty',
      () {
        final context = buildWindowsSecurityContext(
          readNativeRoots: () => const [],
          fallbackBundlePem: embeddedCaBundlePem,
        );

        expect(context, isNotNull);
      },
    );

    test('falls back to the bundle when the native read throws', () {
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => throw const _StoreReadFailure(),
        fallbackBundlePem: embeddedCaBundlePem,
      );

      expect(context, isNotNull);
    });

    test('ignores malformed native DER entries without throwing', () {
      // Junk bytes are not valid certificates; the builder must skip them
      // and still fall back to the bundle rather than propagating the error.
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => [
          Uint8List.fromList([1, 2, 3, 4]),
        ],
        fallbackBundlePem: embeddedCaBundlePem,
      );

      expect(context, isNotNull);
    });
  });
}

class _StoreReadFailure implements Exception {
  const _StoreReadFailure();
}
