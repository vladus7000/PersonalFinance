import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/money/currency_code.dart';
import '../../../core/money/money.dart';
import '../../../domain/entities/income_type.dart';

part 'income_step_data.freezed.dart';

/// Onboarding step 2 (doc.md §3.3): the basics of one income source.
/// [nominalAmount] carries the contract currency directly (same convention
/// as [IncomeSource.nominalAmount]).
@freezed
sealed class IncomeStepData with _$IncomeStepData {
  const factory IncomeStepData({
    required String name,
    required IncomeType type,
    required Money nominalAmount,
    required CurrencyCode payoutCurrency,

    /// 1 or 2 — bounds the parts collected in the next step
    /// ([OnboardingStepIds.incomeCalculation]) to the MVP scenarios (single
    /// payment, or advance + main payment).
    required int payoutsPerMonth,
  }) = _IncomeStepData;
}
