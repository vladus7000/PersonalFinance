import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'money.dart';

/// A percentage, stored as the percent value itself (e.g. `20` for 20%),
/// matching how it is entered/displayed throughout doc.md (e.g. §2.7 "20%
/// от дохода") — not as a 0..1 fraction.
@immutable
class Percentage {
  const Percentage(this.value);

  final Decimal value;

  static final zero = Percentage(Decimal.zero);
  static final hundred = Percentage(Decimal.fromInt(100));

  /// The 0..1 fraction equivalent (20% -> 0.2), exact. Dividing any finite
  /// [Decimal] by 100 always yields a finite result (100 = 2²·5², and a
  /// fraction is finite-precision iff its reduced denominator has only 2
  /// and 5 as prime factors), so this never needs rounding.
  Decimal asFraction() => (value / Decimal.fromInt(100)).toDecimal();

  /// Applies this percentage to a [Money] amount, e.g. 20% of 500 USD = 100 USD.
  Money of(Money money) => money.multiply(asFraction());

  bool get isZero => value == Decimal.zero;

  bool get isNegative => value.sign < 0;

  String toCanonicalString() => value.toString();

  static Percentage parse(String canonical) => Percentage(Decimal.parse(canonical));

  static Percentage? tryParse(String canonical) {
    final value = Decimal.tryParse(canonical);
    return value == null ? null : Percentage(value);
  }

  @override
  bool operator ==(Object other) => other is Percentage && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value%';
}
