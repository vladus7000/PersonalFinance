import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/quantity.dart';

void main() {
  group('Quantity arithmetic', () {
    test('add/subtract/negate/abs', () {
      final a = Quantity(Decimal.parse('113.5'));
      final b = Quantity(Decimal.parse('10.25'));

      expect(a + b, Quantity(Decimal.parse('123.75')));
      expect(a - b, Quantity(Decimal.parse('103.25')));
      expect(-a, Quantity(Decimal.parse('-113.5')));
      expect((-a).abs, a);
    });

    test('scaleBy multiplies by a dimensionless factor', () {
      final qty = Quantity(Decimal.parse('10'));

      expect(qty.scaleBy(Decimal.parse('0.5')), Quantity(Decimal.parse('5.0')));
    });

    test('comparison operators order by value', () {
      final small = Quantity(Decimal.fromInt(1));
      final large = Quantity(Decimal.fromInt(2));

      expect(small < large, isTrue);
      expect(large > small, isTrue);
      expect(Quantity.zero.isZero, isTrue);
    });
  });

  group('crypto precision', () {
    test('preserves 8 fractional digits (satoshi-level) through arithmetic', () {
      final a = Quantity(Decimal.parse('0.00000001')); // 1 satoshi
      final b = Quantity(Decimal.parse('0.12345678'));

      expect((a + b).toCanonicalString(), '0.12345679');
    });

    test('a sum that lands on a whole number is still exactly equal to it', () {
      // Decimal.toString() normalizes away trailing zeros (2.00000000 -> "2"),
      // so this checks value equality rather than a padded string.
      final a = Quantity(Decimal.parse('0.00000001'));
      final b = Quantity(Decimal.parse('1.99999999'));

      final sum = a + b;

      expect(sum, Quantity(Decimal.fromInt(2)));
      expect(sum.toCanonicalString(), '2');
    });
  });

  group('canonical string round-trip', () {
    test('parse recovers the exact value', () {
      final original = Quantity(Decimal.parse('-42.123456789'));

      expect(Quantity.parse(original.toCanonicalString()), original);
    });

    test('tryParse returns null for malformed input', () {
      expect(Quantity.tryParse('not a number'), isNull);
    });
  });
}
