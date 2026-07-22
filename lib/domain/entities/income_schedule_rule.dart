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

    /// The 1-based day-of-month range within the forecasted period this
    /// part compensates for (e.g. an advance covering the 1st-15th, a main
    /// payment covering the 16th-30th) — doc.md §8.18. Only affects the
    /// calculation when [amount] is `null` (see its doc); still recorded
    /// when [amount] is set, but ignored by `SalaryCalculator` there.
    required int coverageStartDay,
    required int coverageEndDay,
    required int paymentDay,

    /// The payment lands in `forecast()`'s `(year, month + paymentMonthOffset)`
    /// rather than always the same calendar month as the period being
    /// forecast — real payroll commonly pays a period's salary early in the
    /// *following* month (e.g. June's salary paid July 7).
    @Default(0) int paymentMonthOffset,

    /// This part's share of [IncomeSource.nominalAmount] as a percentage or
    /// fixed sum. `null` means this part is instead computed automatically
    /// from attendance: a daily rate (`nominalAmount / workingDaysInMonth`)
    /// times the days actually worked within [coverageStartDay]-
    /// [coverageEndDay] — doc.md §8.18/§8.20. Decided independently per
    /// part, not by a source-wide mode: an onboarding-created source always
    /// asks this only for the first part (the rest, if any, mirror the same
    /// choice — percentage gets "the remainder", attendance-based gets the
    /// complementary coverage range — see `IncomeCalculationStepScreen`).
    PaymentPartAmount? amount,
    required WeekendShiftRule weekendShiftRule,

    /// Day of the forecasted period's month (`forecast()`'s `(year, month)`,
    /// NOT the possibly-shifted payment month) on which the exchange rate is
    /// fixed — `null` means the rate is taken on the payment date itself.
    /// Anchored to the period, not the payment, because accounting practice
    /// fixes one rate per period and every part of that period (advance and
    /// main payment alike) uses it, even when the payment itself lands in a
    /// different month (§2.3 "расчёт по курсу на определённый день").
    /// Interpreted by `SalaryCalculator` (E3.T2). A full `ExchangeRateRule`
    /// entity (doc.md §4.5) is out of scope for MVP — rates come from the
    /// already-built [ExchangeRateSource] instead (compat principle #2).
    int? rateFixingDay,
    required bool isActive,
  }) = _IncomeScheduleRule;
}
