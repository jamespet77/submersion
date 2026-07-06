import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/logbook_parser.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

OcrTextBlock block(
  String text,
  double l,
  double t, {
  double w = 80,
  double h = 12,
}) => OcrTextBlock(text: text, boundingBox: Rect.fromLTWH(l, t, w, h));

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

OcrResult page(List<OcrTextBlock> blocks) =>
    OcrResult(blocks: blocks, imageSize: const Size(1000, 1400));

void main() {
  final parser = LogbookParser();

  test('label-bound metric page parses to metric fields', () {
    final result = parser.parse(
      page([
        block('Date', 0, 0),
        block('05/14/2023', 90, 0),
        block('Location', 0, 30),
        block('Pinnacle, Sodwana Bay', 90, 30, w: 200),
        block('DEPTH', 40, 220),
        block('11.1m', 45, 195, w: 40),
        block('TIME', 150, 220),
        block('45min', 150, 195, w: 40),
        block('Start psi/bar', 0, 300, w: 90),
        block('200 bar', 100, 300, w: 50),
        block('End psi/bar', 0, 330, w: 90),
        block('70 bar', 100, 330, w: 50),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.date, DateTime(2023, 5, 14));
    expect(result.siteName, 'Pinnacle, Sodwana Bay');
    expect(result.maxDepthMeters, closeTo(11.1, 0.001));
    expect(result.durationMinutes, 45);
    expect(result.startPressureBar, 200);
    expect(result.endPressureBar, 70);
  });

  test('imperial page converts to metric storage', () {
    final result = parser.parse(
      page([
        block('DEPTH', 40, 220),
        block('69', 45, 195, w: 30),
        block('Visibility', 0, 400),
        block('60 ft', 100, 400, w: 40),
        block('bar/psi START', 200, 100, w: 90),
        block('3K', 200, 120, w: 30),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    // 60 ft visibility makes the page imperial: 69 is feet, 3K is psi.
    expect(result.maxDepthMeters, closeTo(21.03, 0.05));
    expect(result.startPressureBar, closeTo(206.8, 0.5));
    expect(result.unmapped['visibility'], '60 ft');
  });

  test('duration derived from time in and out', () {
    final result = parser.parse(
      page([
        block('Time IN', 0, 100),
        block('10:00A', 0, 120, w: 50),
        block('Time OUT', 120, 100),
        block('10:32', 120, 120, w: 50),
        block('Date', 0, 0),
        block("6 Feb '06", 90, 0, w: 70),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.durationMinutes, 32);
    expect(result.hasTimeOfDay, isTrue);
    expect(result.date, DateTime(2006, 2, 6, 10, 0));
  });

  test('implausible depth is silently dropped', () {
    final result = parser.parse(
      page([block('DEPTH', 40, 220), block('1800', 45, 195, w: 40)]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.maxDepthMeters, isNull);
  });

  test('notes collect handwriting below the comments label', () {
    final result = parser.parse(
      page([
        block('Comments', 0, 700),
        block('WE SAW', 0, 750, w: 120),
        block('A HUMPBACK WHALE', 0, 790, w: 300),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.notes, 'WE SAW A HUMPBACK WHALE');
  });

  test('empty page yields isEmpty result', () {
    final result = parser.parse(
      page([]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.isEmpty, isTrue);
  });
}
