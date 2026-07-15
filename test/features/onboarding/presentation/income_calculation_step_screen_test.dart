import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/domain/entities/payment_part_amount.dart';
import 'package:personal_finance_assistant/features/onboarding/application/income_calculation_step_data.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_controller.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_step.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_steps_provider.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/income_calculation_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/income_step_screen.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/onboarding_shell.dart';

import '../../../support/pump_app.dart';

void main() {
  final usd = CurrencyCode('USD');

  const twoRealSteps = [
    OnboardingStepDefinition(id: 'income', isRequired: true),
    OnboardingStepDefinition(id: 'income_calculation', isRequired: true),
  ];

  Widget buildFlow() {
    return OnboardingShell(
      stepBuilder: (context, stepId) => switch (stepId) {
        'income' => const IncomeStepScreen(),
        'income_calculation' => const IncomeCalculationStepScreen(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// Fills the income step with a two-payment source (nominal 1000 USD)
  /// and advances to the calculation step.
  Future<void> setUpTwoPartIncome(WidgetTester tester) async {
    await pumpApp(
      tester,
      buildFlow(),
      overrides: [onboardingStepsProvider.overrideWith((ref) => twoRealSteps)],
    );

    await tester.enterText(find.byType(TextField).at(0), 'Main job');
    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.pump();
    await tester.tap(find.text('Advance + main payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeCalculationStepScreen), findsOneWidget);
  }

  IncomeCalculationStepData? readStepData(WidgetTester tester) {
    final context = tester.element(find.byType(IncomeCalculationStepScreen));
    final state = ProviderScope.containerOf(context).read(onboardingControllerProvider);
    return state.stepData['income_calculation'] as IncomeCalculationStepData?;
  }

  testWidgets('a two-part source only asks for the advance amount', (tester) async {
    await setUpTwoPartIncome(tester);

    expect(find.text('Advance'), findsOneWidget);
    expect(find.text('Main payment'), findsOneWidget);
    // 2 payment-day fields + 1 advance amount field — no amount field for
    // the main payment, since it is computed automatically.
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('percentage advance: the main payment is the remaining percentage', (
    tester,
  ) async {
    await setUpTwoPartIncome(tester);

    // Field order: advance day, advance amount, main day (main has no
    // amount field — see IncomeCalculationStepScreen doc).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '15'); // advance day
    await tester.enterText(fields.at(1), '40'); // advance = 40%
    await tester.enterText(fields.at(2), '30'); // main day
    await tester.pump();

    final data = readStepData(tester);
    expect(data, isNotNull);
    expect(data!.parts, hasLength(2));
    expect(
      data.parts[0].amount,
      isA<PercentagePaymentPart>().having(
        (p) => p.percentage.value,
        'percentage',
        Decimal.fromInt(40),
      ),
    );
    expect(
      data.parts[1].amount,
      isA<PercentagePaymentPart>().having(
        (p) => p.percentage.value,
        'percentage',
        Decimal.fromInt(60), // 100 - 40
      ),
    );
    // The auto-computed value is shown, not just stored silently.
    expect(find.textContaining('60%'), findsOneWidget);
  });

  testWidgets('fixed advance: the main payment is the rest of the nominal amount', (
    tester,
  ) async {
    await setUpTwoPartIncome(tester);

    await tester.ensureVisible(find.text('A fixed amount'));
    await tester.tap(find.text('A fixed amount'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '15'); // advance day
    await tester.enterText(fields.at(1), '400'); // advance = 400 of 1000
    await tester.enterText(fields.at(2), '30'); // main day
    await tester.pump();

    final data = readStepData(tester);
    expect(data, isNotNull);
    expect(
      data!.parts[0].amount,
      isA<FixedPaymentPart>().having((p) => p.amount, 'amount', Money(Decimal.fromInt(400), usd)),
    );
    expect(
      data.parts[1].amount,
      isA<FixedPaymentPart>().having(
        (p) => p.amount,
        'amount',
        Money(Decimal.fromInt(600), usd), // 1000 - 400
      ),
    );
  });

  testWidgets('the main payment can be scheduled for the following month', (tester) async {
    await setUpTwoPartIncome(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '22'); // advance day
    await tester.enterText(fields.at(1), '50'); // advance = 50%
    await tester.enterText(fields.at(2), '7'); // main day
    await tester.pump();

    // Two "Next month" segments exist (one per part) — the second belongs
    // to the main payment.
    final nextMonthForMain = find.text('Next month').last;
    await tester.ensureVisible(nextMonthForMain);
    await tester.tap(nextMonthForMain);
    await tester.pump();

    final data = readStepData(tester);
    expect(data, isNotNull);
    expect(data!.parts[0].paymentMonthOffset, 0); // advance stays "this month"
    expect(data.parts[1].paymentMonthOffset, 1); // main moves to "next month"
  });

  testWidgets('a specific rate-fixing day applies to the whole source, not per part', (
    tester,
  ) async {
    await setUpTwoPartIncome(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '22');
    await tester.enterText(fields.at(1), '50');
    await tester.enterText(fields.at(2), '7');
    await tester.pump();

    final specificDayOption = find.text('On a specific day of the month');
    await tester.ensureVisible(specificDayOption);
    await tester.tap(specificDayOption);
    await tester.pumpAndSettle();

    final dayField = find.widgetWithText(TextField, 'Day of the month');
    await tester.ensureVisible(dayField);
    await tester.enterText(dayField, '1');
    await tester.pump();

    final data = readStepData(tester);
    expect(data, isNotNull);
    // rateFixingDay is a single field on IncomeCalculationStepData, shared
    // by every part — not one-per-part.
    expect(data!.rateFixingDay, 1);
  });

  testWidgets(
    "by working days, two parts: asks for each part's coverage range instead of an amount",
    (tester) async {
      await setUpTwoPartIncome(tester);

      final byWorkingDaysOption = find.text('Prorated by working days');
      await tester.ensureVisible(byWorkingDaysOption);
      await tester.tap(byWorkingDaysOption);
      await tester.pumpAndSettle();

      // Per part: day, coverage-from, coverage-to — no amount field at all.
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(6));

      await tester.enterText(fields.at(0), '15'); // advance day
      await tester.enterText(fields.at(1), '1'); // advance coverage from
      await tester.enterText(fields.at(2), '15'); // advance coverage to
      await tester.enterText(fields.at(3), '30'); // main day
      await tester.enterText(fields.at(4), '16'); // main coverage from
      await tester.enterText(fields.at(5), '30'); // main coverage to
      await tester.pump();

      final data = readStepData(tester);
      expect(data, isNotNull);
      expect(data!.parts[0].amount, isNull);
      expect(data.parts[0].coverageStartDay, 1);
      expect(data.parts[0].coverageEndDay, 15);
      expect(data.parts[1].amount, isNull);
      expect(data.parts[1].coverageStartDay, 16);
      expect(data.parts[1].coverageEndDay, 30);

      expect(find.textContaining('depends on days actually worked'), findsWidgets);
    },
  );

  testWidgets(
    'shows a rough conversion preview when payout currency differs from contract currency',
    (tester) async {
      await pumpApp(
        tester,
        buildFlow(),
        overrides: [onboardingStepsProvider.overrideWith((ref) => twoRealSteps)],
      );

      await tester.enterText(find.byType(TextField).at(0), 'Main job');
      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.pump();

      // Switch payout currency to UAH; contract currency stays USD.
      final payoutDropdown = find
          .byWidgetPredicate((w) => w is DropdownButton<CurrencyCode>)
          .at(1);
      await tester.tap(payoutDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('UAH').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(IncomeCalculationStepScreen), findsOneWidget);

      // Single payment -> only the preview-rate field and the day field.
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(1), '15'); // payment day
      await tester.pump();
      expect(find.textContaining('Enter a rate above'), findsOneWidget);

      await tester.enterText(fields.at(0), '40'); // 1 USD = 40 UAH, for preview only
      await tester.pump();
      expect(find.textContaining('≈'), findsOneWidget);
      expect(find.textContaining('40000'), findsOneWidget); // 1000 USD * 40
    },
  );
}
