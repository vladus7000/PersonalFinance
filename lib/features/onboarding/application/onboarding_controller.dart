import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'onboarding_state.dart';
import 'onboarding_steps_provider.dart';

part 'onboarding_controller.g.dart';

/// Drives the onboarding flow: forward/back/skip, plus per-step data —
/// content-agnostic (see [onboardingStepsProvider]). BUILD_PLAN.md E2.T2.
@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingState build() => OnboardingState.initial(ref.watch(onboardingStepsProvider));

  /// Advances to the next step. No-op if [OnboardingState.canProceed] is
  /// false or already on the last step.
  void next() {
    if (!state.canProceed || state.isLastStep) return;
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  /// Returns to the previous step. No-op on the first step.
  void back() {
    if (state.isFirstStep) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  /// Advances past the current step without requiring it to be completed.
  /// No-op if the current step is required (see [OnboardingState.canSkipCurrentStep]).
  void skip() {
    if (!state.canSkipCurrentStep || state.isLastStep) return;
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  /// Stores [data] for step [stepId] and marks it completed or not — a step
  /// can transition back to incomplete (e.g. the user clears a required
  /// field), which revokes [OnboardingState.canProceed] until fixed.
  void setStepData(String stepId, Object? data, {required bool completed}) {
    final updatedData = {...state.stepData, stepId: data};
    final updatedCompleted = {...state.completedStepIds};
    if (completed) {
      updatedCompleted.add(stepId);
    } else {
      updatedCompleted.remove(stepId);
    }
    state = state.copyWith(completedStepIds: updatedCompleted, stepData: updatedData);
  }
}
