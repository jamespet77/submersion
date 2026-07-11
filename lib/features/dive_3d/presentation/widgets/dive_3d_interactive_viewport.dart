import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// Interactive 3D viewport rendered entirely with CustomPaint: the scene
/// paints via [Dive3dPreviewPainter] (Canvas.drawVertices, GPU-rasterized
/// by Flutter itself) and gestures drive the orthographic camera. No
/// external 3D engine. The scrub cursor lives in a foregroundPainter that
/// listens to the frame-rate ValueListenable, so playback repaints only
/// the cursor layer, never re-sorts the scene.
class Dive3dInteractiveViewport extends StatefulWidget {
  final Dive3dGeometry geometry;
  final ValueListenable<double> scrubPosition;
  final Set<SceneOverlay> visibleOverlays;
  final void Function(SceneMarker marker)? onMarkerTap;

  const Dive3dInteractiveViewport({
    super.key,
    required this.geometry,
    required this.scrubPosition,
    required this.visibleOverlays,
    this.onMarkerTap,
  });

  @override
  State<Dive3dInteractiveViewport> createState() =>
      _Dive3dInteractiveViewportState();
}

class _Dive3dInteractiveViewportState extends State<Dive3dInteractiveViewport> {
  static const double _initialYaw = -32;
  static const double _initialPitch = 22;
  double _yaw = _initialYaw;
  double _pitch = _initialPitch;
  double _zoom = 1.0;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _yaw -= details.delta.dx * 0.4;
      _pitch = (_pitch + details.delta.dy * 0.4).clamp(-80.0, 80.0);
    });
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(0.4, 8.0);
    });
  }

  void _resetCamera() {
    setState(() {
      _yaw = _initialYaw;
      _pitch = _initialPitch;
      _zoom = 1.0;
    });
  }

  SceneProjector _projectorFor(Size size) => SceneProjector(
    size: size,
    bounds: widget.geometry.bounds,
    yawDegrees: _yaw,
    pitchDegrees: _pitch,
    zoom: _zoom,
  );

  void _handleTapUp(Size size, TapUpDetails details) {
    final onTap = widget.onMarkerTap;
    if (onTap == null ||
        !widget.visibleOverlays.contains(SceneOverlay.markers)) {
      return;
    }
    final projector = _projectorFor(size);
    SceneMarker? best;
    var bestDistance = 24.0;
    for (final marker in widget.geometry.markers) {
      final d =
          (projector.project(marker.x, marker.y, 0) - details.localPosition)
              .distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = marker;
      }
    }
    if (best != null) onTap(best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _zoomBy(signal.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            }
          },
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onDoubleTap: _resetCamera,
            onTapUp: (details) => _handleTapUp(size, details),
            child: CustomPaint(
              painter: Dive3dPreviewPainter(
                geometry: widget.geometry,
                yawDegrees: _yaw,
                pitchDegrees: _pitch,
                zoom: _zoom,
                visibleOverlays: widget.visibleOverlays,
              ),
              foregroundPainter: _ScrubCursorPainter(
                geometry: widget.geometry,
                yawDegrees: _yaw,
                pitchDegrees: _pitch,
                zoom: _zoom,
                scrubPosition: widget.scrubPosition,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// Foreground layer: only the diver cursor. Repaints on every scrub tick
/// (via [scrubPosition] as the repaint listenable) without touching the
/// depth-sorted scene beneath it.
class _ScrubCursorPainter extends CustomPainter {
  final Dive3dGeometry geometry;
  final double yawDegrees;
  final double pitchDegrees;
  final double zoom;
  final ValueListenable<double> scrubPosition;

  _ScrubCursorPainter({
    required this.geometry,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    required this.scrubPosition,
  }) : super(repaint: scrubPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final ribbon = geometry.ribbon;
    if (ribbon.vertexCount < 4) return;
    final projector = SceneProjector(
      size: size,
      bounds: geometry.bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    // Ribbon x is monotonic in time: interpolate ribbon y over x along the
    // pair-leading vertices to place the cursor exactly on the ribbon.
    final t = scrubPosition.value * geometry.bounds.durationSeconds;
    final xs = <double>[
      for (var i = 0; i < ribbon.vertexCount; i += 2) ribbon.positions[i * 3],
    ];
    final ys = <double?>[
      for (var i = 0; i < ribbon.vertexCount; i += 2)
        ribbon.positions[i * 3 + 1],
    ];
    final x = geometry.bounds.xOf(t);
    final y = ProfileLookup(xs).interpolate(ys, x) ?? 0;
    final center = projector.project(x, y, 0);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubCursorPainter oldDelegate) =>
      !identical(oldDelegate.geometry, geometry) ||
      oldDelegate.yawDegrees != yawDegrees ||
      oldDelegate.pitchDegrees != pitchDegrees ||
      oldDelegate.zoom != zoom;
}
