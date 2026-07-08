import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_desktop.dart';

void main() {
  test('getAssetMetadata returns null', () async {
    final metadata = await PhotoPickerServiceDesktop().getAssetMetadata(
      'asset-1',
    );

    expect(metadata, isNull);
  });
}
