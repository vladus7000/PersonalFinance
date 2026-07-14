import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_controller.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_step.dart';
import 'package:personal_finance_assistant/features/onboarding/application/onboarding_steps_provider.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  // A synthetic 3-step flow (required, optional, required) — proves the
  // engine works without depending on the real steps E2.T3 adds later.
  const steps = [
    OnboardingStepDefinition(id: 'currency', isRequired: true),
    OnboardingStepDefinition(id: 'life_expenses', isRequired: false),
    OnboardingStepDefinition(id: 'goal', isRequired: true),
  ];

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [onboardingStepsProvider.overrideWith((ref) => steps)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts on the first step with zero progress made', () {
    final container = buildContainer();

    final state = container.read(onboardingControllerProvider);

    expect(state.currentStep?.id, 'currency');
    expect(state.isFirstStep, isTrue);
    expect(state.canProceed, isFalse); // required step, not yet completed
    expect(state.progress, closeTo(1 / 3, 0.0001));
  });

  test('next is a no-op on a required step until it is marked completed', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.next();

    expect(container.read(onboardingControllerProvider).currentStep?.id, 'currency');
  });

  test('completing a required step unblocks next, and data is retained', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.setStepData('currency', 'USD', completed: true);
    notifier.next();

    final state = container.read(onboardingControllerProvider);
    expect(state.currentStep?.id, 'life_expenses');
    expect(state.stepData['currency'], 'USD');
  });

  test('skip advances past an optional step without marking it completed', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.setStepData('currency', 'USD', completed: true);
    notifier.next(); // -> life_expenses (optional)
    notifier.skip();

    final state = container.read(onboardingControllerProvider);
    expect(state.currentStep?.id, 'goal');
    expect(state.completedStepIds.contains('life_expenses'), isFalse);
  });

  test('skip is a no-op on a required step', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.skip(); // currency is required

    expect(container.read(onboardingControllerProvider).currentStep?.id, 'currency');
  });

  test('back returns to the previous step and is a no-op on the first step', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.back();
    expect(container.read(onboardingControllerProvider).currentStep?.id, 'currency');

    notifier.setStepData('currency', 'USD', completed: true);
    notifier.next();
    expect(container.read(onboardingControllerProvider).currentStep?.id, 'life_expenses');

    notifier.back();
    expect(container.read(onboardingControllerProvider).currentStep?.id, 'currency');
  });

  test('un-completing a step revokes canProceed again', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.setStepData('currency', 'USD', completed: true);
    expect(container.read(onboardingControllerProvider).canProceed, isTrue);

    notifier.setStepData('currency', null, completed: false);
    expect(container.read(onboardingControllerProvider).canProceed, isFalse);
  });

  test('reaching the last step and completing it reflects isLastStep + full progress', () {
    final container = buildContainer();
    final notifier = container.read(onboardingControllerProvider.notifier);

    notifier.setStepData('currency', 'USD', completed: true);
    notifier.next();
    notifier.skip();
    notifier.setStepData('goal', 'apartment', completed: true);

    final state = container.read(onboardingControllerProvider);
    expect(state.isLastStep, isTrue);
    expect(state.canProceed, isTrue);
    expect(state.progress, 1.0);
  });
}
