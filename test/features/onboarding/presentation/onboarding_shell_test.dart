import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_controller.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_step.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_steps_provider.dart';
import 'package:personal_finance_assistant/features/onboarding/presentation/onboarding_shell.dart';

import '../../../support/pump_app.dart';

void main() {
  const requiredThenOptional = [
    OnboardingStepDefinition(id: 'currency', isRequired: true),
    OnboardingStepDefinition(id: 'life_expenses', isRequired: false),
  ];

  Widget buildShell({VoidCallback? onFinish}) {
    return OnboardingShell(
      stepBuilder: (context, stepId) => Text('step:$stepId'),
      onFinish: onFinish,
    );
  }

  testWidgets('required first step: back hidden, next disabled until completed', (tester) async {
    await pumpApp(
      tester,
      buildShell(),
      overrides: [onboardingStepsProvider.overrideWith((ref) => requiredThenOptional)],
    );

    expect(find.text('step:currency'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing); // required step
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    // Complete the step directly via the notifier (this test verifies the
    // shell's reaction to state, not the controller's own logic — that is
    // covered in onboarding_controller_test.dart).
    final context = tester.element(find.byType(OnboardingShell));
    ProviderScope.containerOf(
      context,
    ).read(onboardingControllerProvider.notifier).setStepData('currency', 'USD', completed: true);
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('step:life_expenses'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget); // no longer the first step
  });

  testWidgets('optional step shows Skip; tapping it advances without completing it', (
    tester,
  ) async {
    const optionalFirst = [
      OnboardingStepDefinition(id: 'life_expenses', isRequired: false),
      OnboardingStepDefinition(id: 'goal', isRequired: false),
    ];

    await pumpApp(
      tester,
      buildShell(),
      overrides: [onboardingStepsProvider.overrideWith((ref) => optionalFirst)],
    );

    expect(find.text('step:life_expenses'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pump();

    expect(find.text('step:goal'), findsOneWidget);
  });

  testWidgets('optional last step hides Skip; the primary button finishes instead', (
    tester,
  ) async {
    const requiredThenOptionalLast = [
      OnboardingStepDefinition(id: 'currency', isRequired: true),
      OnboardingStepDefinition(id: 'life_expenses', isRequired: false),
    ];
    var finished = false;

    await pumpApp(
      tester,
      buildShell(onFinish: () => finished = true),
      overrides: [onboardingStepsProvider.overrideWith((ref) => requiredThenOptionalLast)],
    );

    final context = tester.element(find.byType(OnboardingShell));
    ProviderScope.containerOf(
      context,
    ).read(onboardingControllerProvider.notifier).setStepData('currency', 'USD', completed: true);
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('step:life_expenses'), findsOneWidget);
    // Skip would be a silent no-op on the last step (OnboardingController.skip
    // has nowhere to advance to) — the shell must not offer it here.
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing);

    expect(find.text('Finish'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(finished, isTrue);
  });

  testWidgets('last step calls onFinish instead of advancing further', (tester) async {
    const singleRequiredStep = [OnboardingStepDefinition(id: 'goal', isRequired: true)];
    var finished = false;

    await pumpApp(
      tester,
      buildShell(onFinish: () => finished = true),
      overrides: [onboardingStepsProvider.overrideWith((ref) => singleRequiredStep)],
    );

    final context = tester.element(find.byType(OnboardingShell));
    ProviderScope.containerOf(
      context,
    ).read(onboardingControllerProvider.notifier).setStepData('goal', 'apartment', completed: true);
    await tester.pump();

    expect(find.text('Finish'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(finished, isTrue);
    expect(find.text('step:goal'), findsOneWidget); // did not silently advance past the list
  });
}
