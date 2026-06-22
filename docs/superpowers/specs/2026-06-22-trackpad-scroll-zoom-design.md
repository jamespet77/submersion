# Two-finger trackpad scroll → zoom (maps + dive profile chart)

Date: 2026-06-22
Branch: `worktree-trackpad-scroll-zoom`

## Goal

Two-finger up/down scroll on a touchpad should zoom in/out:

- on **all maps** (15 `FlutterMap` instances), and
- on the **dive profile chart**.

Zoom is **cursor-anchored** (zoom toward/away from the pointer). Panning is done
by **click-drag** (already supported everywhere); two-finger drag no longer pans,
because on a trackpad "two-finger scroll" and "two-finger drag-pan" are the same
physical gesture (Flutter delivers both as `PointerPanZoom` events with a `pan`
delta — you cannot have both).

## Decisions (settled)

- **Panning after the change:** click-drag only. Pinch still zooms. Two-finger
  vertical scroll zooms; horizontal scroll component is ignored.
- **Zoom anchor:** under the cursor.
- **Direction:** matches the existing mouse-wheel convention so wheel and trackpad
  agree on the same machine — negative `dy` (scroll up/away) → zoom in. The OS
  natural-scroll setting affects the reported sign identically for wheel and
  trackpad, so they stay consistent.
- **Pointer-kind aware:** only `PointerDeviceKind.trackpad` gestures are
  re-interpreted. Touchscreen pinch / two-finger pan keep flowing through
  flutter_map and the chart's existing handlers untouched (iPad users unaffected).

## Non-goals

- No change to mouse-wheel zoom (already works on both maps and chart).
- No change to touch (tablet) gestures.
- No rotation/north-reset work (that is the separate, unmerged #238/#370 scope).
- Not coordinating with the unmerged #238/#370 branch; this builds independently
  on `main`. A future merge of #370 will need manual reconciliation.

## Architecture

Three units, each independently understandable and testable:

### 1. Pure helper — `lib/core/ui/trackpad_zoom.dart`

Dependency-free function shared by both consumers:

```dart
/// Converts a trackpad two-finger vertical scroll delta (logical px) into an
/// additive zoom-level delta. Negative dy (scroll up/away) -> positive (zoom in),
/// matching the mouse-wheel convention. Sensitivity is tuned so a normal scroll
/// flick changes zoom by roughly one level.
double trackpadScrollZoomDelta(double scrollDy, {double sensitivity = 0.01});
```

- Returns an **additive zoom-level delta** (the natural primitive for maps, whose
  zoom is logarithmic — one level = 2x scale).
- Maps add it to `camera.zoom`.
- The chart applies `pow(2, delta)` to get a multiplicative factor for
  `ProfileChartViewport.zoomedAt`.

Keeping all sign/sensitivity logic here means one unit-tested place; neither
consumer's zoom model leaks into the other.

### 2. Profile chart — modify existing handler

File: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`,
`onPointerPanZoomUpdate` (currently translates by `event.pan` and scales by
`event.scale`).

Change: stop translating; fold vertical scroll into the cumulative zoom factor,
anchored at the cursor (`_trackpadAnchor`, already cursor-positioned at gesture
start). `PointerPanZoomUpdateEvent.pan`/`.scale` are cumulative since gesture
start, matching the existing `_gestureStartViewport` model:

```
final factor = event.scale * pow(2, trackpadScrollZoomDelta(event.pan.dy));
_viewport = _gestureStartViewport.zoomedAt(focal.fx, focal.fy, factor);
```

- Pinch (`event.scale`) still zooms.
- The mouse-wheel path (`onPointerSignal` / `PointerScrollEvent`) is unchanged.
- Click-drag panning (`Listener.onPointerMove`) is unchanged.
- Net effect removes the `vp.pannedBy(event.pan...)` call.

Use cumulative `event.pan` (not `localPan`) per the macOS contamination lesson
from #372 (the chart has no rotation/scale, so global == correct local).

### 3. Maps — new shared wrapper `TrackpadZoomMap`

File: `lib/features/maps/presentation/widgets/trackpad_zoom_map.dart`.

**Revised during implementation (verified by probes):** a passive `Listener`
alone does NOT work. flutter_map's `pinchMove` handler pins the camera to the
gesture-start position on every frame of a trackpad two-finger gesture (scale
stays 1.0, so it recomputes the start camera and calls `moveRaw`), reverting any
`move()` we apply. Disabling `pinchMove` frees our zoom — but `pinchMove` also
powers touch pinch-zoom focal anchoring, so it must only be dropped for the
duration of a trackpad gesture, never for touch.

So `TrackpadZoomMap` is a **`StatefulWidget`** with a **builder** API:

```dart
TrackpadZoomMap({
  required MapController controller,
  required Widget Function(BuildContext, int flags) builder,
  int baseFlags = InteractiveFlag.all,
  double minZoom = 1.0,
  double maxZoom = 22.0,
})
```

- It holds `_trackpadActive`. `onPointerPanZoomStart` (kind == trackpad) sets it
  true; `onPointerPanZoomEnd` sets it false. Effective flags handed to `builder`
  are `baseFlags & ~InteractiveFlag.pinchMove` while active, else `baseFlags`.
- `onPointerPanZoomUpdate` (kind == trackpad) reads `controller.camera`, computes
  `newZoom = (camera.zoom + trackpadScrollZoomDelta(event.panDelta.dy)).clamp(...)`,
  and `controller.move(camera.focusedZoomCenter(event.localPosition, newZoom), newZoom)`.
- Uses **global `panDelta`** (per-event) for the scroll amount and
  **`localPosition`** for the cursor — per the #372 macOS `localPan`
  contamination lesson.
- `MapCamera.focusedZoomCenter(cursorPos, zoom)` returns the new center that keeps
  the point under the cursor fixed (flutter_map built-in). It accounts for map
  rotation.
- Callers thread the supplied `flags` into `MapOptions.interactionOptions`, and
  pass their at-rest flags as `baseFlags` (default `InteractiveFlag.all`).

This preserves touch (tablet/iPad) pinch-zoom exactly; `pinchMove` is only ever
dropped while a trackpad gesture is in progress. Aligns with the agreed UX:
two-finger trackpad scroll zooms (no two-finger trackpad pan), pan via click-drag.

#### Roll-out to 15 files / 17 maps

Each call site wraps its `FlutterMap` in
`TrackpadZoomMap(controller: ..., baseFlags: ..., builder: (context, flags) => FlutterMap(... interactionOptions: InteractionOptions(flags: flags, ...) ...))`.
Maps that are currently stateless and do not own a `MapController` get a minimal
`StatefulWidget` / `ConsumerStatefulWidget` conversion to create and hold one
(create as a field, no `dispose` needed for `MapController` — matches existing
repo pattern; note the repo-wide latent "MapController never disposed"
observation from #370, not introduced here).

The 15 files (two contain 2 maps each — `site_detail_page` and
`dive_center_detail_page` — for 17 maps total):

- `lib/features/maps/presentation/pages/region_picker_page.dart`
- `lib/features/maps/presentation/pages/dive_activity_map_page.dart`
- `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- `lib/features/dive_sites/presentation/widgets/match_sites_map.dart`
- `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- `lib/features/dive_sites/presentation/widgets/location_picker_map.dart`
- `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_locations_map.dart`
- `lib/features/trips/presentation/widgets/trip_voyage_map.dart`
- `lib/features/trips/presentation/widgets/trip_overview_tab.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart`

## Key risk — RESOLVED in implementation

The risk (flutter_map double-handling the trackpad gesture) **materialized**:
flutter_map's `ScaleGestureRecognizer` does engage on trackpad `PointerPanZoom`
and its `pinchMove` handler pins the camera to gesture-start every frame,
reverting our zoom. Verified with probes. Resolved by the pointer-kind-aware
`pinchMove` flag swap in `TrackpadZoomMap` (section 3). The earlier #370 note
("no double-handling, trackpad sends no PointerDownEvent") did not hold for
flutter_map 8.2.2; `ScaleGestureRecognizer.addAllowedPointerPanZoom` accepts the
gesture without a pointer-down. On-device macOS confirmation is still part of
Task 6 (smooth progressive zoom; brief possible stutter on the first frame of a
gesture before the flag-swap rebuild lands).

## Testing

- **Unit** (`test/core/ui/trackpad_zoom_test.dart`): `trackpadScrollZoomDelta`
  sign (negative dy → positive delta), zero at dy 0, sensitivity scaling,
  symmetry (equal-and-opposite dy → equal-and-opposite delta).
- **Widget** (`test/features/maps/.../trackpad_zoom_map_test.dart`): synthesize
  `PointerPanZoomStart/Update/End` with `kind: trackpad` and assert the
  `MapController` zoom changes in the right direction and stays clamped; assert a
  `kind: touch` pan-zoom is ignored (zoom unchanged).
- **Chart**: extend viewport tests for the scroll→factor mapping
  (`pow(2, trackpadScrollZoomDelta(dy))`). Note per #372 that full two-finger
  trackpad gestures aren't simulatable in `flutter_test`; the end-to-end chart
  behavior is covered by on-device verification.
- **Verification before completion**: `dart format .`, `flutter analyze` (whole
  project), the targeted test files, and on-device macOS trackpad check of the
  Key risk above.
