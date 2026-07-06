import 'package:flutter/widgets.dart';

/// Initial presence of an item across the selected dives.
enum MembershipPresence { all, some, none }

/// The desired end-state the user picked for an item in a bulk edit.
///
/// - [ensureOn]: the item must end up on ALL selected dives.
/// - [ensureOff]: the item must end up on NONE of the selected dives.
/// - [leaveAsIs]: do not change membership (the safe default for "on some").
enum MembershipChoice { ensureOn, ensureOff, leaveAsIs }

/// One row in the bulk membership editor: a display label + optional icon.
class BulkMembershipItem {
  final String id;
  final String label;
  final IconData? icon;
  const BulkMembershipItem({required this.id, required this.label, this.icon});
}

/// Pure derivation of the (addIds, removeIds) to apply, given each item's
/// initial presence across the selection and the user's chosen end-state.
///
/// A checked item that was not already on all dives becomes an add; an
/// unchecked item that was on some/all becomes a remove; "leave as-is" (and
/// no-op cases like checking an already-on-all item) produce nothing.
class MembershipDelta {
  final List<String> addIds;
  final List<String> removeIds;
  const MembershipDelta(this.addIds, this.removeIds);

  static const empty = MembershipDelta([], []);

  bool get isEmpty => addIds.isEmpty && removeIds.isEmpty;

  static MembershipDelta from(
    Map<String, MembershipPresence> initial,
    Map<String, MembershipChoice> choices,
  ) {
    final add = <String>[];
    final remove = <String>[];
    for (final entry in choices.entries) {
      final presence = initial[entry.key] ?? MembershipPresence.none;
      switch (entry.value) {
        case MembershipChoice.ensureOn:
          if (presence != MembershipPresence.all) add.add(entry.key);
        case MembershipChoice.ensureOff:
          if (presence != MembershipPresence.none) remove.add(entry.key);
        case MembershipChoice.leaveAsIs:
          break;
      }
    }
    return MembershipDelta(add, remove);
  }
}
