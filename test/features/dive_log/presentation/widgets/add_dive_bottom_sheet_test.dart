import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('shows all three add-dive options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showAddDiveBottomSheet(
                  context: context,
                  onLogManually: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Log Dive Manually'), findsOneWidget);
    expect(find.text('Import from Computer'), findsOneWidget);
    expect(find.text('Scan Paper Log'), findsOneWidget);
  });
}
