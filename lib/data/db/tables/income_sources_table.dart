import 'package:drift/drift.dart';

/// doc.md §4.2. Money columns are TEXT + a separate currency column (§0.4
/// rule) — `nominal_amount`/`contract_currency` for the contract-currency
/// nominal amount, `deduction_amount` for a fixed deduction (assumed to be
/// in the contract currency, like a schedule rule's fixed payment part).
@DataClassName('IncomeSourceRow')
class IncomeSources extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// [IncomeType] enum name.
  TextColumn get type => text()();

  TextColumn get nominalAmount => text().named('nominal_amount')();

  TextColumn get contractCurrency => text().named('contract_currency')();

  TextColumn get payoutCurrency => text().named('payout_currency')();

  /// `'none' | 'fixedAmount' | 'percentage'` — [DeductionRule] discriminator.
  TextColumn get deductionType =>
      text().named('deduction_type').withDefault(const Constant('none'))();

  TextColumn get deductionAmount => text().named('deduction_amount').nullable()();

  TextColumn get deductionPercentage => text().named('deduction_percentage').nullable()();

  /// Unused until the Accounts epic — see [IncomeSource.targetAccountId].
  IntColumn get targetAccountId => integer().named('target_account_id').nullable()();

  DateTimeColumn get startDate => dateTime().named('start_date')();

  DateTimeColumn get endDate => dateTime().named('end_date').nullable()();

  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}
