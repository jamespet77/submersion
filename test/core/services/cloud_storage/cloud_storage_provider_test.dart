import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

void main() {
  group('CloudStorageException.displayMessage', () {
    test('returns the bare message when there is no cause', () {
      const exception = CloudStorageException('Could not reach S3 endpoint');

      expect(exception.displayMessage, 'Could not reach S3 endpoint');
    });

    test('appends the underlying cause so transport detail is visible', () {
      const exception = CloudStorageException(
        'Could not reach S3 endpoint host.example.com',
        FormatException('CERTIFICATE_VERIFY_FAILED'),
      );

      expect(
        exception.displayMessage,
        contains('Could not reach S3 endpoint host.example.com'),
      );
      expect(exception.displayMessage, contains('CERTIFICATE_VERIFY_FAILED'));
    });
  });
}
