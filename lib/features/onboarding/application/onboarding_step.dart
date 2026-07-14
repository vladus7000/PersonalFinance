import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_step.freezed.dart';

/// Metadata for one onboarding step — deliberately content-agnostic (no
/// widget, no data type baked in). Compat principle #5, BUILD_PLAN.md §0.1:
/// the engine must not hardcode a fixed 7-screen sequence, so new steps
/// (income, cushion, investments, goal — E3.T3, E7.T2, E8.T4) plug into the
/// same list without changing [OnboardingController].
@freezed
sealed class OnboardingStepDefinition with _$OnboardingStepDefinition {
  const factory OnboardingStepDefinition({required String id, required bool isRequired}) =
      _OnboardingStepDefinition;
}
