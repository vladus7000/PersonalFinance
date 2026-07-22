import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/deduction_rule.dart';
import '../../../domain/entities/payment_part_amount.dart';
import '../../../domain/entities/weekend_shift_rule.dart';

part 'income_calculation_step_data.freezed.dart';

/// Onboarding step 3 (doc.md §3.3, §8.20): how [IncomeStepData]'s nominal
/// amount turns into actual scheduled payments. [parts] has one entry per
/// [IncomeStepData.payoutsPerMonth].
///
/// [rateFixingDay] is asked once, here, and applied to every part — real
/// payroll fixes one rate per period and every installment of that period
/// uses it (doc.md §8.18), so it would be actively wrong to let each part
/// pick its own [IncomeScheduleRule.rateFixingDay] independently.
@freezed
sealed class IncomeCalculationStepData with _$IncomeCalculationStepData {
  const factory IncomeCalculationStepData({
    required List<IncomePartInput> parts,
    required DeductionRule deductionRule,

    /// Day of the forecasted period's month the rate is fixed on, shared by
    /// every part — `null` means each part's rate is fixed on its own
    /// payment date instead (see [IncomeScheduleRule.rateFixingDay]).
    int? rateFixingDay,
  }) = _IncomeCalculationStepData;
}

@freezed
sealed class IncomePartInput with _$IncomePartInput {
  const factory IncomePartInput({
    /// See [IncomeScheduleRule.coverageStartDay]/`coverageEndDay`. Defaults
    /// to the whole month for a single-payment source (never asked in the
    /// UI there — see [IncomeCalculationStepScreen] doc).
    required int coverageStartDay,
    required int coverageEndDay,
    required int paymentDay,

    /// See [IncomeScheduleRule.paymentMonthOffset] — not asked in the UI
    /// (doc.md §8.20): the first part defaults to 0 (this month), any
    /// further part to 1 (next month) — set programmatically, not by the
    /// user, to keep the screen simple.
    @Default(0) int paymentMonthOffset,
    required WeekendShiftRule weekendShiftRule,

    /// See [IncomeScheduleRule.amount] — `null` means this part's amount is
    /// computed automatically from attendance in [coverageStartDay]-
    /// [coverageEndDay] instead.
    PaymentPartAmount? amount,
  }) = _IncomePartInput;
}
