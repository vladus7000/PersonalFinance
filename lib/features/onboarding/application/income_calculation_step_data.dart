import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/deduction_rule.dart';
import '../../../domain/entities/income_calculation_mode.dart';
import '../../../domain/entities/payment_part_amount.dart';
import '../../../domain/entities/weekend_shift_rule.dart';

part 'income_calculation_step_data.freezed.dart';

/// Onboarding step 3 (doc.md §3.3): how [IncomeStepData]'s nominal amount
/// turns into actual scheduled payments. [parts] has one entry per
/// [IncomeStepData.payoutsPerMonth]. Kept intentionally simpler than the
/// full [IncomeScheduleRule] shape for a first-run wizard —
/// `paymentMonthOffset` and `rateFixingDay` default to "same month as the
/// period" / "fixed on the payment date" and are not asked here; they can
/// be adjusted later once a dedicated income source editor exists.
@freezed
sealed class IncomeCalculationStepData with _$IncomeCalculationStepData {
  const factory IncomeCalculationStepData({
    required IncomeCalculationMode calculationMode,
    required List<IncomePartInput> parts,
    required DeductionRule deductionRule,
  }) = _IncomeCalculationStepData;
}

@freezed
sealed class IncomePartInput with _$IncomePartInput {
  const factory IncomePartInput({
    required int paymentDay,
    required WeekendShiftRule weekendShiftRule,
    required PaymentPartAmount amount,
  }) = _IncomePartInput;
}
