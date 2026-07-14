import 'package:freezed_annotation/freezed_annotation.dart';

import 'onboarding_step.dart';

part 'onboarding_state.freezed.dart';

@freezed
sealed class OnboardingState with _$OnboardingState {
  const OnboardingState._();

  const factory OnboardingState({
    required List<OnboardingStepDefinition> steps,
    required int currentIndex,
    required Set<String> completedStepIds,
    required Map<String, Object?> stepData,
  }) = _OnboardingState;

  factory OnboardingState.initial(List<OnboardingStepDefinition> steps) =>
      OnboardingState(steps: steps, currentIndex: 0, completedStepIds: const {}, stepData: const {});

  OnboardingStepDefinition? get currentStep => steps.isEmpty ? null : steps[currentIndex];

  bool get isFirstStep => currentIndex == 0;

  bool get isLastStep => steps.isEmpty || currentIndex == steps.length - 1;

  /// Whether "Next" should be enabled: the current step is either optional,
  /// or has been marked complete via `setStepData(..., completed: true)`.
  bool get canProceed {
    final step = currentStep;
    if (step == null) return false;
    return !step.isRequired || completedStepIds.contains(step.id);
  }

  /// Whether "Skip" should be shown for the current step.
  bool get canSkipCurrentStep => currentStep != null && !currentStep!.isRequired;

  /// 0..1, for a progress indicator. 0 when there are no steps.
  double get progress => steps.isEmpty ? 0 : (currentIndex + 1) / steps.length;
}
