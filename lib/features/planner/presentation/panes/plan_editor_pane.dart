import 'package:flutter/material.dart';

import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The editing column of Mission Control: segments and tanks always visible,
/// everything else in the Setup accordion.
class PlanEditorPane extends StatelessWidget {
  const PlanEditorPane({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SegmentList(),
        const SizedBox(height: 12),
        const PlanTankList(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: PlanSectionHeader(context.l10n.divePlanner_label_planSettings),
        ),
        const PlanSetupAccordion(),
      ],
    );
  }
}
