import 'package:uuid/uuid.dart';

import '../../../tags/domain/entities/tag.dart';
import '../entities/dive.dart';

/// Why a merge was rejected outright (neither sequential nor overlapping).
enum DiveMergeInvalidReason { tooFewDives, mixedDivers }

/// One inter-dive surface gap on the merged timeline.
class MergeGap {
  const MergeGap({
    required this.afterDiveId,
    required this.beforeDiveId,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// The gap follows this source dive.
  final String afterDiveId;

  /// The gap precedes this source dive.
  final String beforeDiveId;

  /// Seconds from the merged dive's start.
  final int startSeconds;
  final int endSeconds;

  Duration get duration => Duration(seconds: endSeconds - startSeconds);
}

sealed class DiveMergeClassification {
  const DiveMergeClassification();
}

class MergeInvalid extends DiveMergeClassification {
  const MergeInvalid(this.reason);
  final DiveMergeInvalidReason reason;
}

/// Any pair of dives overlaps in time — these look like the same dive from
/// multiple computers (future feature), not a sequential combine.
class MergeOverlapping extends DiveMergeClassification {
  const MergeOverlapping();
}

class MergeSequential extends DiveMergeClassification {
  const MergeSequential({required this.sortedDives, required this.gaps});
  final List<Dive> sortedDives;
  final List<MergeGap> gaps;
}

/// Everything the merge service needs to persist a sequential combine.
class DiveMergeResult {
  const DiveMergeResult({
    required this.mergedDive,
    required this.sortedSources,
    required this.gaps,
    required this.segmentOffsetsSeconds,
    required this.tankIdMap,
    required this.mergedSightings,
  });

  final Dive mergedDive;
  final List<Dive> sortedSources;
  final List<MergeGap> gaps;

  /// Source dive id -> seconds to add to that segment's profile timestamps.
  final Map<String, int> segmentOffsetsSeconds;

  /// Old source tank id -> fresh tank id on the merged dive.
  final Map<String, String> tankIdMap;

  /// Union of source sightings (same species merged), with fresh ids.
  final List<MarineSighting> mergedSightings;
}

class DiveMergeBuilder {
  const DiveMergeBuilder();

  static const _uuid = Uuid();

  DiveMergeResult build(
    List<Dive> dives, {
    Map<String, List<Tag>> tagsByDive = const {},
    Map<String, List<MarineSighting>> sightingsByDive = const {},
    String Function()? idGenerator,
  }) {
    final classification = classify(dives);
    if (classification is! MergeSequential) {
      throw ArgumentError(
        'build() requires a sequential selection; got $classification',
      );
    }
    final idGen = idGenerator ?? _uuid.v4;
    final sorted = classification.sortedDives;
    final first = sorted.first;
    final last = sorted.last;

    final mergedStart = first.effectiveEntryTime;
    final mergedEnd =
        last.exitTime ??
        last.effectiveEntryTime.add(last.effectiveRuntime ?? Duration.zero);

    final offsets = <String, int>{
      for (final d in sorted)
        d.id: d.effectiveEntryTime.difference(mergedStart).inSeconds,
    };

    final mergedDive = Dive(
      id: idGen(),
      diverId: first.diverId,
      dateTime: first.dateTime,
      entryTime: mergedStart,
      exitTime: mergedEnd,
      runtime: mergedEnd.difference(mergedStart),
    );

    return DiveMergeResult(
      mergedDive: mergedDive,
      sortedSources: sorted,
      gaps: classification.gaps,
      segmentOffsetsSeconds: offsets,
      tankIdMap: const {},
      mergedSightings: const [],
    );
  }

  DiveMergeClassification classify(List<Dive> dives) {
    if (dives.length < 2) {
      return const MergeInvalid(DiveMergeInvalidReason.tooFewDives);
    }
    if (dives.map((d) => d.diverId).toSet().length > 1) {
      return const MergeInvalid(DiveMergeInvalidReason.mixedDivers);
    }
    final sorted = [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    final mergedStart = sorted.first.effectiveEntryTime;
    final gaps = <MergeGap>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final prev = sorted[i];
      final next = sorted[i + 1];
      // A dive with no derivable duration is treated as zero-length: it has
      // no profile samples, so nothing can overlap it. Deliberate (#449
      // review).
      final prevEnd = prev.effectiveEntryTime.add(
        prev.effectiveRuntime ?? Duration.zero,
      );
      if (next.effectiveEntryTime.isBefore(prevEnd)) {
        return const MergeOverlapping();
      }
      gaps.add(
        MergeGap(
          afterDiveId: prev.id,
          beforeDiveId: next.id,
          startSeconds: prevEnd.difference(mergedStart).inSeconds,
          endSeconds: next.effectiveEntryTime.difference(mergedStart).inSeconds,
        ),
      );
    }
    return MergeSequential(sortedDives: sorted, gaps: gaps);
  }
}
