import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import '../../core/money/percentage.dart';

part 'payment_part_amount.freezed.dart';

/// How a single [IncomeScheduleRule] part's size is expressed — doc.md §4.3
/// `percentage` / `fixedAmount` (mutually exclusive, §2.3 "две части
/// (%/фикс)"). Same shape as [LivingExpensePreference]'s fixed/percent
/// variants, for the same reason: exactly one of the two ever applies.
@freezed
sealed class PaymentPartAmount with _$PaymentPartAmount {
  const factory PaymentPartAmount.percentage({required Percentage percentage}) =
      PercentagePaymentPart;

  const factory PaymentPartAmount.fixed({required Money amount}) = FixedPaymentPart;
}
