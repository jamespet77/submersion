import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/ui/trackpad_zoom.dart';

/// Wraps a [FlutterMap] so a two-finger vertical scroll on a trackpad zooms the
/// map toward the cursor, instead of panning.
///
/// flutter_map's `pinchMove` handling pins the camera to the gesture-start
/// position on every frame of a trackpad two-finger gesture, which would revert
/// any zoom we apply. So while a trackpad gesture is active this widget drops
/// `pinchMove` from the interaction flags it hands to [builder], and restores it
/// when the gesture ends. `pinchMove` also powers touch (tablet) pinch-zoom
/// focal anchoring, so it is only ever dropped for the duration of a trackpad
/// gesture and never for touch.
///
/// Because the flags must reach the wrapped map, callers build the [FlutterMap]
/// through [builder], threading the supplied `flags` into
/// `MapOptions.interactionOptions`.
class TrackpadZoomMap extends StatefulWidget {
  const TrackpadZoomMap({
    super.key,
    required this.controller,
    required this.builder,
    this.baseFlags = InteractiveFlag.all,
    this.minZoom = 1.0,
    this.maxZoom = 22.0,
  });

  /// The same controller passed to the wrapped [FlutterMap]'s `mapController`.
  final MapController controller;

  /// The interaction flags the map uses at rest (when no trackpad gesture is in
  /// progress). Defaults to [InteractiveFlag.all].
  final int baseFlags;

  final double minZoom;
  final double maxZoom;

  /// Builds the wrapped [FlutterMap] given the effective interaction flags to
  /// pass to its `MapOptions.interactionOptions`.
  final Widget Function(BuildContext context, int flags) builder;

  @override
  State<TrackpadZoomMap> createState() => _TrackpadZoomMapState();
}

class _TrackpadZoomMapState extends State<TrackpadZoomMap> {
  bool _trackpadActive = false;

  int get _effectiveFlags => _trackpadActive
      ? widget.baseFlags & ~InteractiveFlag.pinchMove
      : widget.baseFlags;

  void _onStart(PointerPanZoomStartEvent event) {
    if (event.kind == PointerDeviceKind.trackpad && !_trackpadActive) {
      setState(() => _trackpadActive = true);
    }
  }

  void _onUpdate(PointerPanZoomUpdateEvent event) {
    if (event.kind != PointerDeviceKind.trackpad) return;
    // Per-event vertical delta. Use the global panDelta (not localPanDelta):
    // on macOS the trackpad localPan is contaminated by the widget's
    // global->local translation (see dive profile chart, PR #372).
    final delta = trackpadScrollZoomDelta(event.panDelta.dy);
    if (delta == 0) return;

    final MapCamera camera;
    try {
      camera = widget.controller.camera;
    } catch (_) {
      // Controller not yet attached to a FlutterMap.
      return;
    }
    final newZoom = (camera.zoom + delta).clamp(widget.minZoom, widget.maxZoom);
    if (newZoom == camera.zoom) return;
    // focusedZoomCenter keeps the point under the cursor fixed; it already
    // accounts for map rotation.
    widget.controller.move(
      camera.focusedZoomCenter(event.localPosition, newZoom),
      newZoom,
    );
  }

  void _onEnd(PointerPanZoomEndEvent event) {
    if (_trackpadActive) {
      setState(() => _trackpadActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerPanZoomStart: _onStart,
      onPointerPanZoomUpdate: _onUpdate,
      onPointerPanZoomEnd: _onEnd,
      child: widget.builder(context, _effectiveFlags),
    );
  }
}
