import 'package:drift/drift.dart';

/// `rate` is stored as TEXT (canonical Decimal string), never REAL —
/// see BUILD_PLAN.md §0.1 п.1 and §0.4.
@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get fromCurrency => text().named('from_currency')();

  TextColumn get toCurrency => text().named('to_currency')();

  TextColumn get rate => text()();

  DateTimeColumn get effectiveDate => dateTime().named('effective_date')();

  TextColumn get source => text().withDefault(const Constant('manual'))();

  BoolColumn get isFinal => boolean().named('is_final').withDefault(const Constant(true))();
}
