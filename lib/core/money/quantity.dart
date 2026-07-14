import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// A dimensionless exact quantity — number of shares, crypto units, etc.
/// Arbitrary precision via [Decimal] (crypto needs 8+ fractional digits).
@immutable
class Quantity implements Comparable<Quantity> {
  const Quantity(this.value);

  final Decimal value;

  static final zero = Quantity(Decimal.zero);

  Quantity operator +(Quantity other) => Quantity(value + other.value);

  Quantity operator -(Quantity other) => Quantity(value - other.value);

  Quantity operator -() => Quantity(-value);

  Quantity get abs => Quantity(value.abs());

  /// Scales by a dimensionless factor (e.g. splitting a holding).
  Quantity scaleBy(Decimal factor) => Quantity(value * factor);

  bool get isZero => value == Decimal.zero;

  bool get isNegative => value.sign < 0;

  bool get isPositive => value.sign > 0;

  @override
  int compareTo(Quantity other) => value.compareTo(other.value);

  bool operator <(Quantity other) => compareTo(other) < 0;

  bool operator <=(Quantity other) => compareTo(other) <= 0;

  bool operator >(Quantity other) => compareTo(other) > 0;

  bool operator >=(Quantity other) => compareTo(other) >= 0;

  /// Canonical, lossless, round-trippable string — the raw decimal, e.g.
  /// `"113.00000000"` for a crypto quantity.
  String toCanonicalString() => value.toString();

  static Quantity parse(String canonical) => Quantity(Decimal.parse(canonical));

  static Quantity? tryParse(String canonical) {
    final value = Decimal.tryParse(canonical);
    return value == null ? null : Quantity(value);
  }

  @override
  bool operator ==(Object other) => other is Quantity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toCanonicalString();
}
