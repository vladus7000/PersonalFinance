import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/currency_code.dart';
import '../../core/money/money.dart';
import '../repositories/exchange_rate_source.dart';

part 'currency_converter.freezed.dart';

/// Result of a currency conversion attempt. Deliberately not a
/// `Result<T, Failure>` (BUILD_PLAN.md §0.1 п.8): a missing rate is an
/// expected, common outcome that callers (e.g. `NetWorthCalculator`) must
/// display something sensible for — it is not an exceptional failure to
/// short-circuit on.
///
/// §5.9 doc.md: never present an approximate figure as exact — [isStale]
/// must be surfaced to the user whenever it is true.
@freezed
sealed class ConversionOutcome with _$ConversionOutcome {
  const factory ConversionOutcome.converted({
    required Money money,
    required Decimal rate,
    required DateTime rateEffectiveDate,
    required bool isStale,

    /// The [ExchangeRate.source] the rate came from (e.g. `'manual'`), or
    /// `'identity'` when [from] == [to] and no lookup happened — doc.md
    /// §2.4/§5.9 require the rate source to be surfaced to the user.
    required String rateSource,
  }) = ConvertedOutcome;

  const factory ConversionOutcome.missing({
    required CurrencyCode from,
    required CurrencyCode to,
  }) = MissingRateOutcome;
}

/// Converts [Money] between currencies using rates from an
/// [ExchangeRateSource]. Pure domain logic — no Flutter/Drift dependency
/// (BUILD_PLAN.md §0.1 п.4).
class CurrencyConverter {
  const CurrencyConverter(this._source);

  final ExchangeRateSource _source;

  /// Converts [amount] to [to] using the best available rate as of [asOf].
  ///
  /// Resolution order: identity (same currency) → direct rate → inverted
  /// reverse rate → [ConversionOutcome.missing]. A rate found for an
  /// earlier date than [asOf] is still used, but flagged [ConvertedOutcome.isStale].
  Future<ConversionOutcome> convert({
    required Money amount,
    required CurrencyCode to,
    required DateTime asOf,
  }) async {
    if (amount.currency == to) {
      return ConversionOutcome.converted(
        money: amount,
        rate: Decimal.one,
        rateEffectiveDate: asOf,
        isStale: false,
        rateSource: 'identity',
      );
    }

    final direct = await _source.latestRate(from: amount.currency, to: to, asOf: asOf);
    if (direct != null) {
      return ConversionOutcome.converted(
        // Money.multiply keeps the receiver's currency (it's designed for
        // same-currency scaling, e.g. Percentage.of) — conversion must
        // construct the result in the target currency explicitly.
        money: Money(amount.amount * direct.rate, to),
        rate: direct.rate,
        rateEffectiveDate: direct.effectiveDate,
        isStale: !_isSameDate(direct.effectiveDate, asOf),
        rateSource: direct.source,
      );
    }

    final inverse = await _source.latestRate(from: to, to: amount.currency, asOf: asOf);
    if (inverse != null) {
      final invertedRate = (Decimal.one / inverse.rate).toDecimal(scaleOnInfinitePrecision: 10);
      return ConversionOutcome.converted(
        money: Money(amount.amount * invertedRate, to),
        rate: invertedRate,
        rateEffectiveDate: inverse.effectiveDate,
        isStale: !_isSameDate(inverse.effectiveDate, asOf),
        rateSource: inverse.source,
      );
    }

    return ConversionOutcome.missing(from: amount.currency, to: to);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    final ua = a.toUtc();
    final ub = b.toUtc();
    return ua.year == ub.year && ua.month == ub.month && ua.day == ub.day;
  }
}
