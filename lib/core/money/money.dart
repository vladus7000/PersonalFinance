import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'currency_code.dart';
import '../result/failure.dart';
import '../result/result.dart';

/// An exact monetary amount in a specific currency.
///
/// Always backed by [Decimal] — never `double` (BUILD_PLAN.md §0.1 п.1).
/// Full precision is kept at all times; rounding happens only for display
/// via [roundedForDisplay].
@immutable
class Money {
  const Money(this.amount, this.currency);

  factory Money.zero(CurrencyCode currency) => Money(Decimal.zero, currency);

  final Decimal amount;
  final CurrencyCode currency;

  /// Adds [other], or fails with [Failure.currencyMismatch] if the
  /// currencies differ — money of different currencies cannot be summed
  /// without an explicit, rate-aware conversion (see `CurrencyConverter`,
  /// E1.T5).
  Result<Money> add(Money other) {
    if (other.currency != currency) {
      return Result.err(
        Failure.currencyMismatch(expected: currency.value, actual: other.currency.value),
      );
    }
    return Result.ok(Money(amount + other.amount, currency));
  }

  /// Subtracts [other], or fails with [Failure.currencyMismatch] if the
  /// currencies differ.
  Result<Money> subtract(Money other) {
    if (other.currency != currency) {
      return Result.err(
        Failure.currencyMismatch(expected: currency.value, actual: other.currency.value),
      );
    }
    return Result.ok(Money(amount - other.amount, currency));
  }

  /// Scales this amount by a dimensionless factor (e.g. a [Percentage]'s
  /// fraction). Currency is preserved; this can never fail.
  ///
  /// NOT for currency conversion — an exchange rate changes the currency,
  /// so a converter must construct `Money(amount.amount * rate, to)`
  /// directly rather than calling this (`CurrencyConverter` does this).
  Money multiply(Decimal factor) => Money(amount * factor, currency);

  Money get negated => Money(-amount, currency);

  Money get abs => Money(amount.abs(), currency);

  bool get isZero => amount == Decimal.zero;

  bool get isNegative => amount.sign < 0;

  bool get isPositive => amount.sign > 0;

  /// Compares magnitude against [other]. Throws [ArgumentError] if the
  /// currencies differ: unlike [add]/[subtract] (routine operations a user
  /// can trigger, e.g. summing two account balances entered by hand),
  /// comparing unconverted amounts across currencies is always a
  /// programming error, not a recoverable domain failure.
  int compareTo(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Cannot compare Money in ${currency.value} to Money in ${other.currency.value}',
      );
    }
    return amount.compareTo(other.amount);
  }

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Rounds half-away-from-zero to [scale] fractional digits, for display
  /// only. The canonical/stored [amount] is never rounded.
  Decimal roundedForDisplay({int scale = 2}) => amount.round(scale: scale);

  /// Canonical, lossless, round-trippable representation: amount, a single
  /// space, then the currency code — e.g. `"150.50 USD"`. Use this (not
  /// [amount]/[currency] separately as a combined string) whenever Money needs to be
  /// serialized as a single field, e.g. JSON export/import (E13.T1).
  String toCanonicalString() => '${amount.toString()} ${currency.value}';

  static Money parse(String canonical) {
    final parts = canonical.trim().split(' ');
    if (parts.length != 2) {
      throw FormatException('Invalid Money canonical string', canonical);
    }
    return Money(Decimal.parse(parts[0]), CurrencyCode(parts[1]));
  }

  static Money? tryParse(String canonical) {
    final parts = canonical.trim().split(' ');
    if (parts.length != 2) return null;
    final amount = Decimal.tryParse(parts[0]);
    if (amount == null) return null;
    try {
      return Money(amount, CurrencyCode(parts[1]));
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => toCanonicalString();
}
