import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart';

import '../../../../helpers/test_app.dart';

void main() {
  Future<void> pumpNewTemplatePage(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: const PreDiveTemplateEditPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('new-template mode renders name field and Save', (tester) async {
    await pumpNewTemplatePage(tester);
    expect(find.text('New Pre-Dive Checklist'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Strict order'), findsOneWidget);
  });

  testWidgets('Add item opens the item dialog with a type picker', (
    tester,
  ) async {
    await pumpNewTemplatePage(tester);
    await tester.ensureVisible(find.text('Add item'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    // Type dropdown defaults to Checkbox; value fields hidden.
    expect(find.text('Checkbox'), findsOneWidget);
    expect(find.text('Value label'), findsNothing);
  });

  testWidgets('selecting Recorded value reveals the value fields', (
    tester,
  ) async {
    await pumpNewTemplatePage(tester);
    await tester.ensureVisible(find.text('Add item'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Checkbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recorded value').last);
    await tester.pumpAndSettle();

    expect(find.text('Value label'), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Min (warning)'), findsOneWidget);
    expect(find.text('Max (warning)'), findsOneWidget);
  });

  testWidgets('Save with empty name shows validation and stays', (
    tester,
  ) async {
    await pumpNewTemplatePage(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.byType(PreDiveTemplateEditPage), findsOneWidget);
  });
}
