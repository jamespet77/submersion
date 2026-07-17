import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// pSCR ratio control for a passive semi-closed rebreather plan. The ratio is a
/// global equipment preference (Subsurface `pscr_ratio`): larger values add
/// more fresh gas and shrink the inspired-O2 drop.
class PscrSettingsSection extends ConsumerStatefulWidget {
  const PscrSettingsSection({super.key});

  @override
  ConsumerState<PscrSettingsSection> createState() =>
      _PscrSettingsSectionState();
}

class _PscrSettingsSectionState extends ConsumerState<PscrSettingsSection> {
  late final TextEditingController _ratioController;

  @override
  void initState() {
    super.initState();
    _ratioController = TextEditingController(
      text: ref.read(pscrRatioProvider).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ratioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _ratioController,
              decoration: InputDecoration(
                labelText: context.l10n.plannerCanvas_pscr_ratio,
                helperText: context.l10n.plannerCanvas_pscr_ratio_hint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(),
              onChanged: (text) {
                final parsed = double.tryParse(text);
                if (parsed == null || parsed <= 0) return;
                ref.read(settingsProvider.notifier).setPscrRatio(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}
