import 'package:meta/meta.dart';

/// A currency or ledger-currency code (ISO 4217 for fiat, e.g. `USD`/`UAH`;
/// also used for crypto ledger balances, e.g. `USDT`).
///
/// Kept as a free-form validated string, not an enum — see BUILD_PLAN.md
/// §0.1 compat principle #9 (institutions/currencies must stay
/// configurable, not hardcoded, for the mass-market extension path).
@immutable
class CurrencyCode {
  factory CurrencyCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (!_pattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        code,
        'code',
        'Currency code must be 2-10 upper-case letters/digits',
      );
    }
    return CurrencyCode._(normalized);
  }

  const CurrencyCode._(this.value);

  static final _pattern = RegExp(r'^[A-Z0-9]{2,10}$');

  final String value;

  @override
  bool operator ==(Object other) => other is CurrencyCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
