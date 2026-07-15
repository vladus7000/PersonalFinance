import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import '../../core/money/percentage.dart';

part 'deduction_rule.freezed.dart';

/// Withholding applied to an [IncomeSource]'s payout — doc.md §4.2
/// `deductionRule` (§2.3 "удержания"). `none` is the common case (most
/// income sources have no withholding modeled in MVP).
@freezed
sealed class DeductionRule with _$DeductionRule {
  const factory DeductionRule.none() = NoDeduction;

  const factory DeductionRule.fixedAmount({required Money amount}) = FixedDeduction;

  const factory DeductionRule.percentage({required Percentage percentage}) = PercentageDeduction;
}
