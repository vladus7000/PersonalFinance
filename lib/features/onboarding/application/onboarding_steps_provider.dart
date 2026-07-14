import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'onboarding_step.dart';
import 'onboarding_step_ids.dart';

part 'onboarding_steps_provider.g.dart';

/// The ordered list of onboarding steps. Currently steps 1 and 4 of §3.3
/// doc.md (E2.T3) — later tasks (income E3.T3, cushion E7.T2, investments
/// E8.T4, goal) insert more between them, without touching
/// [OnboardingController] itself (compat principle #5, BUILD_PLAN.md §0.1).
@riverpod
List<OnboardingStepDefinition> onboardingSteps(Ref ref) => const [
  OnboardingStepDefinition(id: OnboardingStepIds.currency, isRequired: true),
  OnboardingStepDefinition(id: OnboardingStepIds.lifeExpenses, isRequired: false),
];
