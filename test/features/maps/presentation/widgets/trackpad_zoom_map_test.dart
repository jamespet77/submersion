import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';

void main() {
  // Records the interaction flags the builder was last asked to render with, so
  // tests can assert the pointer-kind-aware swap.
  late int lastFlags;

  Future<MapController> pumpMap(WidgetTester tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackpadZoomMap(
            controller: controller,
            builder: (context, flags) {
              lastFlags = flags;
              return FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: const LatLng(0, 0),
                  initialZoom: 5,
                  minZoom: 1,
                  maxZoom: 18,
                  interactionOptions: InteractionOptions(flags: flags),
                ),
                children: const [],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('trackpad two-finger scroll up zooms in progressively', (
    tester,
  ) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump(); // apply the kind-aware flag swap before updates
    await gesture.panZoomUpdate(center, pan: const Offset(0, -50));
    await tester.pump();
    await gesture.panZoomUpdate(center, pan: const Offset(0, -100));
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, greaterThan(start));
  });

  testWidgets('trackpad two-finger scroll down zooms out', (tester) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump();
    await gesture.panZoomUpdate(center, pan: const Offset(0, 100));
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, lessThan(start));
  });

  testWidgets('pinchMove is dropped only while a trackpad gesture is active', (
    tester,
  ) async {
    await pumpMap(tester);
    expect(
      InteractiveFlag.hasPinchMove(lastFlags),
      isTrue,
      reason: 'touch pinch-move preserved at rest',
    );
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump();
    expect(
      InteractiveFlag.hasPinchMove(lastFlags),
      isFalse,
      reason: 'pinch-move dropped during trackpad gesture',
    );

    await gesture.panZoomEnd();
    await tester.pump();
    expect(
      InteractiveFlag.hasPinchMove(lastFlags),
      isTrue,
      reason: 'pinch-move restored after trackpad gesture',
    );
  });
}
