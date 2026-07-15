import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_part_amount.dart';
import 'weekend_shift_rule.dart';

part 'income_schedule_rule.freezed.dart';

/// One payment part of an [IncomeSource] — doc.md §4.3. A source with two
/// parts (e.g. advance + main payment, §2.3) has two of these, distinguished
/// by [partIndex].
///
/// [id] is `null` until persisted (assigned by
/// [IncomeSourceRepository.create]/`update`).
@freezed
sealed class IncomeScheduleRule with _$IncomeScheduleRule {
  const factory IncomeScheduleRule({
    int? id,
    required int partIndex,
    required int paymentDay,
    required PaymentPartAmount amount,
    required WeekendShiftRule weekendShiftRule,

    /// Days before [paymentDay] the exchange rate is fixed — `null`/`0`
    /// means the rate is taken on the payment day itself (§2.3 "расчёт по
    /// курсу на определённый день"). Interpreted by `SalaryCalculator`
    /// (E3.T2). A full `ExchangeRateRule` entity (doc.md §4.5) is out of
    /// scope for MVP — rates come from the already-built
    /// [ExchangeRateSource] instead (compat principle #2).
    int? rateFixingOffsetDays,
    required bool isActive,
  }) = _IncomeScheduleRule;
}
