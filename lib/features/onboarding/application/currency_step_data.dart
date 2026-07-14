import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/money/currency_code.dart';

part 'currency_step_data.freezed.dart';

/// What onboarding step 1 (§3.3) collects — held in
/// [OnboardingState.stepData] under `OnboardingStepIds.currency` until
/// onboarding completes (E2.T4 persists it into [UserProfile]).
@freezed
sealed class CurrencyStepData with _$CurrencyStepData {
  const factory CurrencyStepData({
    required CurrencyCode primary,
    required List<CurrencyCode> additional,
  }) = _CurrencyStepData;
}
