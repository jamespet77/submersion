import 'dart:convert';

/// Source-video metadata used by the ceiling rule and progress reporting.
class VideoProbe {
  const VideoProbe({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.overallBitrateKbps,
  });
  final int width;
  final int height;
  final int durationMs;
  final int overallBitrateKbps;
}

/// Parses `ffprobe -print_format json -show_format -show_streams` output.
/// Returns null for anything that is not a probeable video (malformed JSON,
/// no video stream, missing dimensions) — the caller uploads the original.
VideoProbe? parseFfprobeJson(String json) {
  try {
    final root = jsonDecode(json) as Map<String, dynamic>;
    final streams = (root['streams'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final video = streams.firstWhere(
      (s) => s['codec_type'] == 'video',
      orElse: () => const {},
    );
    final width = video['width'] as int?;
    final height = video['height'] as int?;
    if (width == null || height == null) return null;
    final format = root['format'] as Map<String, dynamic>? ?? const {};
    final durationSec = double.tryParse('${format['duration']}') ?? 0;
    final bitRateBps = int.tryParse('${format['bit_rate']}') ?? 0;
    return VideoProbe(
      width: width,
      height: height,
      durationMs: (durationSec * 1000).round(),
      overallBitrateKbps: (bitRateBps / 1000).round(),
    );
  } on FormatException {
    return null;
  }
}
