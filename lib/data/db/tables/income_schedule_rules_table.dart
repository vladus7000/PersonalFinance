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

  /// `'percentage' | 'fixed'` — [PaymentPartAmount] discriminator.
  TextColumn get amountType => text().named('amount_type')();

  TextColumn get amountPercentage => text().named('amount_percentage').nullable()();

  TextColumn get amountFixedValue => text().named('amount_fixed_value').nullable()();

  /// [WeekendShiftRule] enum name.
  TextColumn get weekendShiftRule => text().named('weekend_shift_rule')();

  IntColumn get rateFixingOffsetDays => integer().named('rate_fixing_offset_days').nullable()();

  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
}
