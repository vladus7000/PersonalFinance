import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../core/money/currency_code.dart';
import '../../domain/entities/exchange_rate.dart';
import '../../domain/repositories/exchange_rate_source.dart';
import '../db/app_database.dart';

/// MVP implementation of [ExchangeRateSource]: rates come only from what
/// the user has manually entered (§8.8/§10.3 doc.md — NBU/bank sources are
/// a future `ExchangeRateSource` implementation, not a change to this one
/// or to `CurrencyConverter`).
class ManualExchangeRateSource implements ExchangeRateSource {
  const ManualExchangeRateSource(this._db);

  final AppDatabase _db;

  @override
  Future<ExchangeRate?> latestRate({
    required CurrencyCode from,
    required CurrencyCode to,
    required DateTime asOf,
  }) async {
    final query = _db.select(_db.exchangeRates)
      ..where(
        (t) =>
            t.fromCurrency.equals(from.value) &
            t.toCurrency.equals(to.value) &
            t.effectiveDate.isSmallerOrEqualValue(asOf),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.effectiveDate)])
      ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    return ExchangeRate(
      from: CurrencyCode(row.fromCurrency),
      to: CurrencyCode(row.toCurrency),
      rate: Decimal.parse(row.rate),
      effectiveDate: row.effectiveDate,
      source: row.source,
      isFinal: row.isFinal,
    );
  }

  /// Records a manually-entered rate (e.g. from a future onboarding/settings
  /// screen). Not part of [ExchangeRateSource] — that interface is
  /// read-only, matching how other sources (NBU, bank APIs) can only ever
  /// be read from.
  Future<void> record(ExchangeRate rate) {
    return _db
        .into(_db.exchangeRates)
        .insert(
          ExchangeRatesCompanion.insert(
            fromCurrency: rate.from.value,
            toCurrency: rate.to.value,
            rate: rate.rate.toString(),
            effectiveDate: rate.effectiveDate,
            source: Value(rate.source),
            isFinal: Value(rate.isFinal),
          ),
        );
  }
}
