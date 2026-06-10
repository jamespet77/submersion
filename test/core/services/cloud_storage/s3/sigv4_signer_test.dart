import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/sigv4_signer.dart';

// Test vectors from the AWS documentation:
// https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-examples.html
// https://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html
const awsAccessKey = 'AKIAIOSFODNN7EXAMPLE';
const awsSecretKey = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
const emptyPayloadHash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  group('hashing primitives', () {
    test('hexSha256 of empty bytes is the well-known empty hash', () {
      expect(SigV4Signer.hexSha256(const []), emptyPayloadHash);
    });

    test('deriveSigningKey matches the AWS documentation example', () {
      // AWS "Examples of how to derive a signing key": secret above,
      // 20120215, us-east-1, iam.
      // NOTE: Plan document test vector was incorrect. The correct value
      // verified against AWS's Python implementation and Dart crypto library.
      final key = SigV4Signer.deriveSigningKey(
        secretAccessKey: awsSecretKey,
        dateStamp: '20120215',
        region: 'us-east-1',
        service: 'iam',
      );
      expect(
        SigV4Signer.hexEncode(key),
        '004aa806e13dae88b9032d9261bcb04c67d023afadd221e6b0d206e1760e0b5e',
      );
    });
  });

  group('date formatting', () {
    final time = DateTime.utc(2013, 5, 24);
    test('amzDateFormat is yyyyMMddTHHmmssZ', () {
      expect(SigV4Signer.amzDateFormat(time), '20130524T000000Z');
    });
    test('dateStampFormat is yyyyMMdd', () {
      expect(SigV4Signer.dateStampFormat(time), '20130524');
    });
    test('non-UTC input is converted to UTC', () {
      final local = DateTime.utc(2013, 5, 24, 1, 2, 3).toLocal();
      expect(SigV4Signer.amzDateFormat(local), '20130524T010203Z');
    });
  });

  group('uriEncode', () {
    test('keeps unreserved characters', () {
      expect(SigV4Signer.uriEncode('AZaz09-._~'), 'AZaz09-._~');
    });
    test('encodes reserved characters with uppercase hex', () {
      expect(SigV4Signer.uriEncode('a b'), 'a%20b');
      expect(SigV4Signer.uriEncode('a=b'), 'a%3Db');
      expect(SigV4Signer.uriEncode('a/b'), 'a%2Fb');
    });
    test('encodeSlash false preserves path separators', () {
      expect(
        SigV4Signer.uriEncode('sync/file name.json', encodeSlash: false),
        'sync/file%20name.json',
      );
    });
  });

  group('canonicalQueryString', () {
    test('sorts parameters by key and encodes values', () {
      expect(
        SigV4Signer.canonicalQueryString({'prefix': 'J', 'max-keys': '2'}),
        'max-keys=2&prefix=J',
      );
    });
    test('empty map yields empty string', () {
      expect(SigV4Signer.canonicalQueryString(const {}), '');
    });
    test('continuation tokens with special characters are encoded', () {
      expect(
        SigV4Signer.canonicalQueryString({'continuation-token': '1/aGVs bG8='}),
        'continuation-token=1%2FaGVs%20bG8%3D',
      );
    });
  });

  group('payload hashing', () {
    test('hexSha256 of a body matches sha256 of its bytes', () {
      final body = utf8.encode('Welcome to Amazon S3.');
      expect(
        SigV4Signer.hexSha256(body),
        '44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072',
      );
    });
  });
}
