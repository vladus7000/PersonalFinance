import '../../core/money/currency_code.dart';
import '../entities/exchange_rate.dart';

/// Abstraction over "where exchange rates come from" (BUILD_PLAN.md §0.1
/// compat principle #2). MVP has a single implementation,
/// `ManualExchangeRateSource` (data/sources/), backed by manually-entered
/// rates; NBU/bank-rate sources can implement this later without touching
/// `CurrencyConverter` or any UI.
abstract class ExchangeRateSource {
  /// The most recent stored rate for `from -> to` with
  /// `effectiveDate <= asOf`, or `null` if no such rate has ever been
  /// recorded (not even an older one).
  Future<ExchangeRate?> latestRate({
    required CurrencyCode from,
    required CurrencyCode to,
    required DateTime asOf,
  });
}
