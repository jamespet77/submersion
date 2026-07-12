import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';

/// Language-neutral fallback labels for [resolveSourceName] used off the
/// widget tree (providers cannot read context.l10n). Comparison labels favor
/// the computer model/serial, which are language-neutral, so this only
/// affects the rare fully-unidentified source.
const _neutralLabels = SourceNameLabels(
  unknownComputer: 'Computer',
  manualEntry: 'Manual entry',
  importedFile: 'Imported file',
  editedSuffix: ' (edited)',
);

/// The dive-computer sources of a single dive, as comparison profiles. The
/// primary source is placed first so it is the reference (index 0). Sources
/// without usable depth samples are skipped; the list is capped for
/// legibility.
final computerComparisonProfilesProvider =
    FutureProvider.family<List<ComparisonProfile>, String>((ref, diveId) async {
      final sources = await ref.watch(diveDataSourcesProvider(diveId).future);
      final profilesBySource = await ref.watch(
        sourceProfilesProvider(diveId).future,
      );

      // Primary first (reference index 0), then the rest in source order.
      final ordered = [...sources]
        ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));

      final out = <ComparisonProfile>[];
      for (final source in ordered) {
        final sp = profilesBySource[source.id];
        if (sp == null || sp.points.length < 2) continue; // metadata-only
        final times = [for (final p in sp.points) p.timestamp.toDouble()];
        final depths = [for (final p in sp.points) p.depth];
        out.add(
          ComparisonProfile(
            id: source.id,
            label: resolveSourceName(
              source,
              _neutralLabels,
              edited: sp.isEdited,
            ),
            color: sourceColorAt(out.length),
            times: times,
            depths: depths,
            maxDepthMeters: depths.fold(0.0, (a, b) => b > a ? b : a),
          ),
        );
      }
      return out.length > kMaxComparisonProfiles
          ? out.sublist(0, kMaxComparisonProfiles)
          : out;
    });
