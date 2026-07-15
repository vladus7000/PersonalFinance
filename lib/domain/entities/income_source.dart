import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/currency_code.dart';
import '../../core/money/money.dart';
import 'deduction_rule.dart';
import 'income_calculation_mode.dart';
import 'income_schedule_rule.dart';
import 'income_type.dart';

part 'income_source.freezed.dart';

/// A recurring or one-off source of income — doc.md §4.2. Aggregate root
/// over its [scheduleRules] (doc.md §4.3 `IncomeScheduleRule`): a rule only
/// makes sense in the context of its source, so both are read/written
/// together through [IncomeSourceRepository].
///
/// [id] is `null` until persisted. [nominalAmount] carries the contract
/// currency directly (`nominalAmount.currency`) — doc.md's separate
/// `contractCurrency` field is not duplicated (single source of truth,
/// BUILD_PLAN.md §0.1 п.5 applies the same principle elsewhere).
///
/// Deliberately not modeled (see BUILD_PLAN.md E3.T1 note): `userId` (MVP
/// has exactly one local user, like [UserProfile]); `frequency` /
/// `payoutsPerMonth` (MVP is month-cycle-only, §2.6, and the part count is
/// already `scheduleRules.length`); `exchangeRateRuleId` (superseded by
/// [ExchangeRateSource], compat principle #2); `notificationOffset`
/// (deferred to E10, no notification system exists yet).
@freezed
sealed class IncomeSource with _$IncomeSource {
  const factory IncomeSource({
    int? id,
    required String name,
    required IncomeType type,
    required Money nominalAmount,
    required CurrencyCode payoutCurrency,
    required IncomeCalculationMode calculationMode,
    required DeductionRule deductionRule,

    /// Unused until the Accounts epic lands — pre-added like
    /// [UserProfile.householdId] (compat principle, BUILD_PLAN.md §0.1 п.9).
    int? targetAccountId,
    required DateTime startDate,
    DateTime? endDate,
    required bool isActive,
    String? notes,
    required List<IncomeScheduleRule> scheduleRules,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _IncomeSource;
}
