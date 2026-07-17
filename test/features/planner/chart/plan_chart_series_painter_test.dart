import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';

import 'chart_fixtures.dart';

void main() {
  final palette = PlanChartPalette.of(
    ThemeData(colorScheme: const ColorScheme.dark()),
  );
  const geometry = PlanChartGeometry(
    size: Size(500, 400),
    maxTimeSeconds: 3100,
    maxDepthMeters: 45,
    depthUnitScale: 1,
  );

  PlanChartSeriesPainter painter({bool withGhost = false}) =>
      PlanChartSeriesPainter(
        geometry: geometry,
        palette: palette,
        series: decoSeries(),
        ghost: withGhost ? ndlSeries() : null,
        stopTagLabels: const ["21m 1'", "12m 3'", "9m 5'", "6m 12'"],
        meanDepthLabel: 'mean 32m',
        labelStyle: const TextStyle(fontSize: 10),
        tagStyle: const TextStyle(fontSize: 9),
        textDirection: TextDirection.ltr,
      );

  test('paints deco plan with ghost, tags, and flags without throwing', () {
    final recorder = ui.PictureRecorder();
    painter(withGhost: true).paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('paints a dense 15-stop schedule without throwing', () {
    final dense = denseDecoSeries();
    final p = PlanChartSeriesPainter(
      geometry: PlanChartGeometry(
        size: const Size(500, 400),
        maxTimeSeconds: dense.maxTimeSeconds,
        maxDepthMeters: dense.maxDepth,
        depthUnitScale: 1,
      ),
      palette: palette,
      series: dense,
      ghost: null,
      stopTagLabels: [
        for (final m in dense.stopLabels)
          "${m.depth.round()}m ${m.durationSeconds ~/ 60}'",
      ],
      meanDepthLabel: 'mean 40m',
      labelStyle: const TextStyle(fontSize: 10),
      tagStyle: const TextStyle(fontSize: 9),
      textDirection: TextDirection.ltr,
    );
    final recorder = ui.PictureRecorder();
    p.paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('shouldRepaint when the ghost appears', () {
    expect(painter(withGhost: true).shouldRepaint(painter()), isTrue);
    expect(painter().shouldRepaint(painter()), isFalse);
  });
}
