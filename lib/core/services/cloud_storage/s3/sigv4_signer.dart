import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure-function AWS Signature Version 4 signing for S3-compatible services.
///
/// No I/O and no clock access: the request time is always a parameter, so
/// every function is deterministic and testable against AWS's published
/// worked examples (see sigv4_signer_test.dart for vector sources).
class SigV4Signer {
  SigV4Signer._();

  static const _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  static String hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String hexSha256(List<int> bytes) => sha256.convert(bytes).toString();

  static List<int> hmacSha256(List<int> key, List<int> message) =>
      Hmac(sha256, key).convert(message).bytes;

  /// kSigning = HMAC(HMAC(HMAC(HMAC("AWS4"+secret, date), region), service),
  /// "aws4_request") -- the SigV4 key-derivation chain.
  static List<int> deriveSigningKey({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    String service = 's3',
  }) {
    final kDate = hmacSha256(
      utf8.encode('AWS4$secretAccessKey'),
      utf8.encode(dateStamp),
    );
    final kRegion = hmacSha256(kDate, utf8.encode(region));
    final kService = hmacSha256(kRegion, utf8.encode(service));
    return hmacSha256(kService, utf8.encode('aws4_request'));
  }

  /// `20130524T000000Z` -- the x-amz-date header format.
  static String amzDateFormat(DateTime time) {
    final t = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}T${p2(t.hour)}${p2(t.minute)}${p2(t.second)}Z';
  }

  /// `20130524` -- the credential-scope date.
  static String dateStampFormat(DateTime time) {
    final t = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}';
  }

  /// RFC 3986 encoding as SigV4 requires it: unreserved characters pass
  /// through, everything else becomes uppercase %XX; '/' survives only when
  /// [encodeSlash] is false (object-key paths).
  static String uriEncode(String input, {bool encodeSlash = true}) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(input)) {
      final char = String.fromCharCode(byte);
      if (_unreserved.contains(char) || (char == '/' && !encodeSlash)) {
        buffer.write(char);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }

  /// Query parameters sorted by key, each key and value uriEncoded.
  static String canonicalQueryString(Map<String, String> queryParams) {
    final keys = queryParams.keys.toList()..sort();
    return keys
        .map((k) => '${uriEncode(k)}=${uriEncode(queryParams[k]!)}')
        .join('&');
  }
}
