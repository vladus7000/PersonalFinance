import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/currency_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/income_calculation_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/income_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/life_expenses_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/onboarding_shell.dart';

import '../../../support/pump_app.dart';

void main() {
  Widget buildRealFlow() {
    return OnboardingShell(
      stepBuilder: (context, stepId) => switch (stepId) {
        'currency' => const CurrencyStepScreen(),
        'income' => const IncomeStepScreen(),
        'income_calculation' => const IncomeCalculationStepScreen(),
        'life_expenses' => const LifeExpensesStepScreen(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// Fills in just enough of the income steps to unblock progression — a
  /// single payment (the default) only requires a name, an amount, and a
  /// payment day; every other field already has a valid default.
  Future<void> fillMinimalIncomeSteps(WidgetTester tester) async {
    expect(find.byType(IncomeStepScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Main job');
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeCalculationStepScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('currency selection survives navigating to the next step and back', (
    tester,
  ) async {
    // No provider override — this exercises the real onboardingStepsProvider
    // (currency, income, income_calculation, life_expenses), proving these
    // steps actually work end to end, not just in isolation.
    await pumpApp(tester, buildRealFlow());

    // Primary defaults to the first common currency (USD); switch it to EUR.
    // byWidgetPredicate (not byType) because DropdownButton<CurrencyCode>'s
    // runtime type doesn't match a bare `DropdownButton` type literal.
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();

    // Advance to the next step (income — currency is complete, the
    // required step, so Next is enabled).
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(IncomeStepScreen), findsOneWidget);

    // Go back and confirm the selection was retained, not reset.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('EUR'), findsWidgets); // shown as the selected dropdown value
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

    await fillMinimalIncomeSteps(tester);

    expect(find.byType(LifeExpensesStepScreen), findsOneWidget);

    await tester.tap(find.text('% of income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '35');
    await tester.pump();

    // Go back through the income steps to currency and return here.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(IncomeCalculationStepScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(IncomeStepScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(CurrencyStepScreen), findsOneWidget);

    // ...and all the way forward again.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(IncomeStepScreen), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(IncomeCalculationStepScreen), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('35'), findsOneWidget);
    expect(find.text('% of income'), findsOneWidget);
  });
}
