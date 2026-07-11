import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:three_js_angle_renderer/three_js_angle_renderer.dart' as angle;
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;

/// Throwaway spike proving the three_js stack (three_js_core +
/// three_js_angle_renderer) renders a dive-path-like polyline on every
/// platform. Reached only from the debug menu. Camera orbit is hand-rolled
/// (drag to orbit, pinch/scale to zoom) because three_js_controls drags in
/// dependency conflicts and the real flythrough uses its own camera anyway.
/// Delete when the real flythrough viewport lands.
class FlythroughSpikePage extends StatefulWidget {
  const FlythroughSpikePage({super.key});

  @override
  State<FlythroughSpikePage> createState() => _FlythroughSpikePageState();
}

class _FlythroughSpikePageState extends State<FlythroughSpikePage> {
  late final angle.ThreeJS _threeJs;

  // Spherical orbit state around the scene origin.
  double _azimuth = 0.8;
  double _elevation = 0.5;
  double _radius = 160.0;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _threeJs = angle.ThreeJS(
      settings: angle.Settings(clearColor: 0x0a1a2a),
      onSetupComplete: () => setState(() {}),
      setup: _setup,
    );
  }

  @override
  void dispose() {
    _threeJs.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    _threeJs.scene = three.Scene();

    _threeJs.camera = three.PerspectiveCamera(
      60,
      _threeJs.width / _threeJs.height,
      0.1,
      2000,
    );
    _positionCamera();

    // Hardcoded dive-path-like helix: descends to -30 m, spirals inward,
    // returns to the surface.
    final points = <tmath.Vector3>[];
    for (var i = 0; i <= 300; i++) {
      final t = i / 300.0;
      final theta = t * 4 * math.pi;
      final radius = 40.0 * (1.0 - 0.5 * t);
      final depth = -30.0 * (t < 0.5 ? (t * 2) : (2 - t * 2));
      points.add(
        tmath.Vector3(
          radius * math.cos(theta),
          depth,
          radius * math.sin(theta),
        ),
      );
    }
    final pathGeometry = three.BufferGeometry().setFromPoints(points);
    final path = three.Line(
      pathGeometry,
      three.LineBasicMaterial.fromMap({'color': 0x4fc3f7}),
    );
    _threeJs.scene.add(path);

    // Water surface reference: a square outline at y = 0.
    const surfaceHalf = 60.0;
    final surfacePoints = <tmath.Vector3>[
      tmath.Vector3(-surfaceHalf, 0, -surfaceHalf),
      tmath.Vector3(surfaceHalf, 0, -surfaceHalf),
      tmath.Vector3(surfaceHalf, 0, surfaceHalf),
      tmath.Vector3(-surfaceHalf, 0, surfaceHalf),
      tmath.Vector3(-surfaceHalf, 0, -surfaceHalf),
    ];
    final surface = three.Line(
      three.BufferGeometry().setFromPoints(surfacePoints),
      three.LineBasicMaterial.fromMap({'color': 0x2196f3}),
    );
    _threeJs.scene.add(surface);

    _threeJs.addAnimationEvent((dt) {
      _positionCamera();
    });
  }

  void _positionCamera() {
    final clampedElevation = _elevation.clamp(-1.4, 1.4);
    final y = _radius * math.sin(clampedElevation);
    final horizontal = _radius * math.cos(clampedElevation);
    _threeJs.camera.position.setValues(
      horizontal * math.cos(_azimuth),
      y,
      horizontal * math.sin(_azimuth),
    );
    _threeJs.camera.lookAt(tmath.Vector3(0, -10, 0));
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // One- and two-finger drags orbit; pinch zooms.
    _azimuth += details.focalPointDelta.dx * 0.01;
    _elevation += details.focalPointDelta.dy * 0.01;
    if (details.scale != 1.0) {
      final increment = details.scale / _lastScale;
      _radius = (_radius / increment).clamp(30.0, 600.0);
      _lastScale = details.scale;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('three_js Spike')),
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: _threeJs.build(),
      ),
    );
  }
}
