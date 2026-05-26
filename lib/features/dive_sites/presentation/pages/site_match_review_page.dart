import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reviews auto-matched dives and lets the user resolve ambiguous/unmatched
/// ones. Reached post-download (seeded with imported dive ids) and from the
/// dives-list overflow menu (null = whole eligible backlog).
class SiteMatchReviewPage extends ConsumerWidget {
  const SiteMatchReviewPage({super.key, this.diveIds});

  final List<String>? diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(siteMatchReviewProvider(diveIds));
    final notifier = ref.read(siteMatchReviewProvider(diveIds).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.siteMatchReview_title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.siteMatchReview_done),
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text(state.errorMessage!));
          }
          if (state.entries.isEmpty) {
            return Center(child: Text(l10n.siteMatchReview_empty));
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.siteMatchReview_summary(
                    state.matchedCount,
                    state.reviewCount,
                    state.noMatchCount,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final e in state.entries)
                _EntryTile(
                  entry: e,
                  onUnlink: () => notifier.unlink(e.dive.id),
                  onPick: (cid) => notifier.link(e.dive.id, cid),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onUnlink,
    required this.onPick,
  });

  final DiveMatchEntry entry;
  final VoidCallback onUnlink;
  final void Function(String candidateId) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = 'Dive #${entry.dive.diveNumber ?? '?'}';

    List<Widget> candidateTiles() => [
      for (final c in entry.candidates)
        ListTile(
          title: Text(c.name),
          subtitle: Text(
            l10n.siteMatchReview_candidateSubtitle(
              c.distanceMeters.round(),
              c.isExisting
                  ? l10n.siteMatchReview_sourceExisting
                  : l10n.siteMatchReview_sourceBundled,
            ),
          ),
          onTap: () => onPick(c.id),
        ),
    ];

    switch (entry.status) {
      case MatchEntryStatus.autoMatched:
        final base = l10n.siteMatchReview_matchedSubtitle(
          entry.siteName ?? '',
          entry.distanceMeters?.round() ?? 0,
        );
        final subtitle = entry.isNewlyCreated
            ? '$base · ${l10n.siteMatchReview_newlyAdded}'
            : base;
        return ExpansionTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(title),
          subtitle: Text(subtitle),
          children: [
            // Expand to unlink or change to a different nearby site.
            ListTile(
              leading: const Icon(Icons.link_off),
              title: Text(l10n.siteMatchReview_unlink),
              onTap: onUnlink,
            ),
            ...candidateTiles(),
          ],
        );
      case MatchEntryStatus.needsReview:
        return ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: Text(title),
          subtitle: Text(
            l10n.siteMatchReview_nearbySites(entry.candidates.length),
          ),
          children: candidateTiles(),
        );
      case MatchEntryStatus.noMatch:
        return ListTile(
          leading: const Icon(Icons.location_off_outlined),
          title: Text(title),
          subtitle: Text(l10n.siteMatchReview_noNearbySite),
        );
    }
  }
}
