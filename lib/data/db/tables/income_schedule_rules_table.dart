import 'package:drift/drift.dart';

import 'income_sources_table.dart';

/// doc.md §4.3. `amount_fixed_value` is assumed to be in the parent
/// [IncomeSource]'s contract currency — a schedule rule only ever makes
/// sense in the context of its source (see [IncomeSource] aggregate doc).
@DataClassName('IncomeScheduleRuleRow')
class IncomeScheduleRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get incomeSourceId =>
      integer().named('income_source_id').references(IncomeSources, #id)();

  IntColumn get partIndex => integer().named('part_index')();

  IntColumn get paymentDay => integer().named('payment_day')();

  /// See [IncomeScheduleRule.paymentMonthOffset] — the payment can land in
  /// the month after the forecasted period.
  IntColumn get paymentMonthOffset =>
      integer().named('payment_month_offset').withDefault(const Constant(0))();

  /// `'percentage' | 'fixed'` — [PaymentPartAmount] discriminator.
  TextColumn get amountType => text().named('amount_type')();

  TextColumn get amountPercentage => text().named('amount_percentage').nullable()();

  TextColumn get amountFixedValue => text().named('amount_fixed_value').nullable()();

  /// [WeekendShiftRule] enum name.
  TextColumn get weekendShiftRule => text().named('weekend_shift_rule')();

  /// See [IncomeScheduleRule.rateFixingDay] — anchored to the forecasted
  /// period's month, not the (possibly later) payment month.
  IntColumn get rateFixingDay => integer().named('rate_fixing_day').nullable()();

  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
}
