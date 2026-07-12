# Detail Pane Scroll Retention

**Date:** 2026-07-11
**Status:** Approved (design)
**Branch/worktree:** `worktree-detail-scroll-retention`

## Problem

In the wide-screen master-detail layout (list on the left, detail on the
right, `>= 800px`), scrolling a detail pane down to a section and then selecting
a different item in the list **resets the detail pane to the top**. This forces
the user to re-scroll to the same section for every item, which defeats the
common workflow of scrolling to a section (e.g. Marine Life, Cylinders) and
quickly comparing that section across several dives/sites/etc.

Desired behavior: when you switch the selected item, the detail pane **keeps its
scroll offset** so the same region stays in view.

## Root cause

`MasterDetailScaffold._DetailPane`
(`lib/shared/widgets/master_detail/master_detail_scaffold.dart`) renders the
detail via an `AnimatedSwitcher` whose child is wrapped in
`KeyedSubtree(key: ValueKey('detail_$selectedId'))`. When `selectedId` changes,
the `ValueKey` changes, so Flutter tears down the old detail element subtree and
builds a brand-new one. The detail page's top-level `SingleChildScrollView`
(e.g. `dive_detail_page.dart`'s `body`) therefore gets a fresh `ScrollPosition`
starting at offset 0.

The per-id `ValueKey` is **intentional**: it isolates each item's local UI
state (active data source, expanded panels, etc.), so it must stay. We need
scroll retention *without* removing that key.

## Approach: `PageStorage` offset retention

Flutter's `Scrollable` automatically saves and restores its scroll offset to the
nearest ancestor `PageStorageBucket`, keyed by the chain of `PageStorageKey`s
between the bucket and the scrollable. Crucially, a plain `ValueKey` is **not** a
`PageStorageKey` and does not participate in that path. So if:

1. a `PageStorageBucket` lives **above** the per-id `KeyedSubtree`, and
2. each detail page's scroll view carries a **stable** `PageStorageKey`,

then every item reads and writes the **same** storage slot — exactly the
cross-item retention we want — while each item still gets a fresh element (no
state leakage) and its own `ScrollController` (so the `AnimatedSwitcher`
cross-fade, which briefly mounts both panes, causes no controller conflict).

### Part 1 — Scaffold provides a persistent, isolated bucket

In `_MasterDetailScaffoldState`:

- Add `final PageStorageBucket _detailBucket = PageStorageBucket();`. Because the
  `State` object outlives the per-id `KeyedSubtree` teardown, the bucket (and
  thus the saved offset) persists across selections.
- Wrap the detail-pane subtree (the `_DetailPane` / map-view `Expanded` child)
  in `PageStorage(bucket: _detailBucket, child: ...)`. Owning the bucket at the
  scaffold guarantees a bucket exists and isolates it per section, so
  `PageStorageKey` strings cannot collide across sections (defensive; sections
  are already separate routes today).

### Part 2 — Each in-scope detail page tags its scroll view

Add a constant `PageStorageKey` to the top-level vertical scroll view of each
in-scope detail page. The key string is descriptive and unique per page:

| Page | File | Scroll view | Key |
| ---- | ---- | ----------- | --- |
| Dive | `dive_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('diveDetailScroll')` |
| Site | `dive_sites/.../site_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('siteDetailScroll')` |
| Course | `courses/.../course_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('courseDetailScroll')` |
| Certification | `certifications/.../certification_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('certificationDetailScroll')` |
| Dive center | `dive_centers/.../dive_center_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('diveCenterDetailScroll')` |
| Equipment | `equipment/.../equipment_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('equipmentDetailScroll')` |
| Buddy | `buddies/.../buddy_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('buddyDetailScroll')` |
| Trip | `trips/.../trip_detail_page.dart` | tabbed — each tab's scroll view (`TripOverviewTab` and siblings) | `PageStorageKey('trip<Tab>Scroll')` per tab |

Notes:

- Most pages expose a single `final body = SingleChildScrollView(...)`; adding
  `key:` to that widget is a one-line change and is applied whether or not the
  page is in `embedded` mode (the key sits on the scroll view itself).
- **Trips** is the exception: its detail is a `TabBarView` (`body =
  TripOverviewTab(...)`), so the scroll views live one level deeper inside each
  tab. Tag each tab's own scroll view. Retaining scroll *per trip* is the goal;
  per-tab scroll retention within a trip is a natural side benefit.

## Scope

- **In:** dives, sites, courses, certifications, dive centers, equipment,
  buddies, trips.
- **Out:** statistics, settings, transfer (sectioned/config panes, not
  comparable entity records), and species (reference data). These use
  `MasterDetailScaffold` too but are explicitly excluded.

The scaffold change (Part 1) is global, but it is inert for the excluded
sections because their detail panes carry no `PageStorageKey`, so nothing is
saved or restored for them.

## Semantics & edge cases

- **Pixel offset, clamped.** The restored offset is the raw pixel value,
  clamped by `Scrollable` to the new content's scroll extent. A shorter item
  lands at its own bottom. This matches "I don't have to re-scroll to roughly
  the same place"; true section-anchoring is intentionally out of scope (YAGNI —
  sections are user-reorderable and vary in height per item).
- **Cross-fade preserved.** The existing `AnimatedSwitcher` stays. Each pane
  keeps its own controller; the two panes only share a saved-offset value, so
  the brief double-mount during the fade is safe (both write the same value).
- **Mobile unaffected.** On narrow layouts each detail is its own route with a
  fresh `PageStorageBucket` and no sibling to compare against, so it still opens
  at the top. No regression.
- **Edit/create/summary untouched.** Only the view-mode scroll view is tagged.
  Edit forms and the empty-state summary keep current behavior.
- **Section switching (dives -> sites).** Different routes -> different
  buckets -> independent offsets. No contamination.

## Testing

### Widget test (primary)

New file `test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart`,
modeled on the existing `master_detail_scaffold_focus_test.dart` harness
(`GoRouter` + `MediaQuery` at width 1200 to force the desktop layout). Because
the harness supplies its own `detailBuilder`, the test proves the scaffold
wiring without depending on any real detail page:

1. `detailBuilder: (_, id) => SingleChildScrollView(key: const
   PageStorageKey('testDetailScroll'), child: SizedBox(height: 3000, child:
   Text('Detail $id')))`.
2. Render at `/test?selected=1`, scroll the detail pane to a known offset (e.g.
   `drag`/`jumpTo` to 800), `pumpAndSettle`.
3. Drive selection to item 2 (navigate to `/test?selected=2`), `pumpAndSettle`.
4. Assert the detail pane's `ScrollPosition.pixels == 800` (retained).
5. Second case: item 2's content is shorter (e.g. height 400); assert the
   offset **clamps** to `maxScrollExtent` rather than throwing or staying at
   800.
6. Regression guard: assert an untagged detail scroll view (no
   `PageStorageKey`) still resets to 0, documenting that the key is what opts a
   section in.

### Manual verification (run skill, macOS)

Scroll a dive detail to Marine Life / Cylinders, click a different dive in the
list, confirm the pane stays scrolled. Repeat for at least one other in-scope
section (e.g. sites) and confirm an excluded section (settings) still resets.

## Files touched

- `lib/shared/widgets/master_detail/master_detail_scaffold.dart` — bucket +
  `PageStorage` wrapper (Part 1).
- 8 detail pages — one `PageStorageKey` each (trips: one per tab) (Part 2).
- `test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart` —
  new widget test.
