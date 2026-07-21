import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

const _ffprobeJson = '''
{
  "streams": [
    {"codec_type": "audio", "codec_name": "aac"},
    {"codec_type": "video", "codec_name": "h264", "width": 1920, "height": 1080}
  ],
  "format": {"duration": "12.480000", "bit_rate": "9600000"}
}
''';

void main() {
  test('parses dimensions, duration, and overall bitrate', () {
    final probe = parseFfprobeJson(_ffprobeJson)!;
    expect(probe.width, 1920);
    expect(probe.height, 1080);
    expect(probe.durationMs, 12480);
    expect(probe.overallBitrateKbps, 9600);
  });

  test('returns null when no video stream exists', () {
    expect(
      parseFfprobeJson('{"streams": [], "format": {"duration": "1"}}'),
      isNull,
    );
  });

  test('returns null on malformed json', () {
    expect(parseFfprobeJson('not json'), isNull);
  });
}
