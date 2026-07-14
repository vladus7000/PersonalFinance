import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/currency_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/life_expenses_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/onboarding_shell.dart';

import '../../../support/pump_app.dart';

void main() {
  Widget buildRealFlow() {
    return OnboardingShell(
      stepBuilder: (context, stepId) => switch (stepId) {
        'currency' => const CurrencyStepScreen(),
        'life_expenses' => const LifeExpensesStepScreen(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  testWidgets('currency selection survives navigating to the next step and back', (
    tester,
  ) async {
    // No provider override — this exercises the real onboardingStepsProvider
    // (currency, life_expenses), proving the two steps E2.T3 added actually
    // work end to end, not just in isolation.
    await pumpApp(tester, buildRealFlow());

    // Primary defaults to the first common currency (USD); switch it to EUR.
    // byWidgetPredicate (not byType) because DropdownButton<CurrencyCode>'s
    // runtime type doesn't match a bare `DropdownButton` type literal.
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();

    // Select an additional currency.
    await tester.tap(find.widgetWithText(FilterChip, 'UAH'));
    await tester.pump();

    // Advance to step 4 (life_expenses is optional, so Next is now enabled
    // because currency — the required step — is complete).
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(LifeExpensesStepScreen), findsOneWidget);

    // Go back and confirm the selections were retained, not reset.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('EUR'), findsWidgets); // shown as the selected dropdown value
    final uahChip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'UAH'));
    expect(uahChip.selected, isTrue);
  });

  testWidgets('life expenses: switching to percent mode and typing keeps the value on revisit', (
    tester,
  ) async {
    await pumpApp(tester, buildRealFlow());
    // CurrencyStepScreen.initState defers its default-value commit past the
    // first frame (Riverpod forbids mutating state during build) — settle
    // so the rebuild carrying canProceed: true actually happens before we
    // rely on it.
    await tester.pumpAndSettle();

    // Primary currency has a default (USD), so currency step is already
    // marked complete once the deferred update above lands.
    expect(find.byType(CurrencyStepScreen), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(LifeExpensesStepScreen), findsOneWidget);

    await tester.tap(find.text('% of income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '35');
    await tester.pump();

    // Skip forward and back within the same step is not applicable (it's
    // the last step); instead go back to currency and return here.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('35'), findsOneWidget);
    expect(find.text('% of income'), findsOneWidget);
  });
}
