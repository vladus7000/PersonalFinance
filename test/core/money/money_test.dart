import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/core/result/failure.dart';

void main() {
  final usd = CurrencyCode('USD');
  final eur = CurrencyCode('EUR');

  group('Money arithmetic', () {
    test('add sums two amounts of the same currency', () {
      final a = Money(Decimal.parse('100.25'), usd);
      final b = Money(Decimal.parse('50.10'), usd);

      final result = a.add(b);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, Money(Decimal.parse('150.35'), usd));
    });

    test('subtract can go negative without losing precision', () {
      final a = Money(Decimal.parse('10.00'), usd);
      final b = Money(Decimal.parse('12.345'), usd);

      final result = a.subtract(b);

      expect(result.valueOrNull, Money(Decimal.parse('-2.345'), usd));
    });

    test('multiply scales the amount and keeps the currency', () {
      final price = Money(Decimal.parse('148.35'), usd);

      final total = price.multiply(Decimal.fromInt(113));

      expect(total, Money(Decimal.parse('16763.55'), usd));
    });

    test('negated and abs behave as expected', () {
      final positive = Money(Decimal.parse('5.00'), usd);
      final negative = Money(Decimal.parse('-5.00'), usd);

      expect(positive.negated, negative);
      expect(negative.abs, positive);
      expect(positive.isPositive, isTrue);
      expect(negative.isNegative, isTrue);
      expect(Money.zero(usd).isZero, isTrue);
    });

    test('comparison operators order by amount within the same currency', () {
      final small = Money(Decimal.parse('1.00'), usd);
      final large = Money(Decimal.parse('2.00'), usd);

      expect(small < large, isTrue);
      expect(large > small, isTrue);
      expect(small <= small, isTrue);
      expect(large >= large, isTrue);
    });
  });

  group('Currency mismatch is a typed Failure, not an exception', () {
    test('add across currencies fails with Failure.currencyMismatch', () {
      final result = Money(Decimal.fromInt(10), usd).add(Money(Decimal.fromInt(10), eur));

      expect(result.isErr, isTrue);
      expect(
        result.failureOrNull,
        const Failure.currencyMismatch(expected: 'USD', actual: 'EUR'),
      );
    });

    test('subtract across currencies fails with Failure.currencyMismatch', () {
      final result = Money(Decimal.fromInt(10), usd).subtract(Money(Decimal.fromInt(10), eur));

      expect(result.isErr, isTrue);
      expect(
        result.failureOrNull,
        const Failure.currencyMismatch(expected: 'USD', actual: 'EUR'),
      );
    });

    test('comparing across currencies throws ArgumentError (programmer error)', () {
      final a = Money(Decimal.fromInt(10), usd);
      final b = Money(Decimal.fromInt(10), eur);

      expect(() => a.compareTo(b), throwsArgumentError);
      expect(() => a < b, throwsArgumentError);
    });
  });

  group('Canonical string round-trip', () {
    test('toCanonicalString -> parse recovers the exact value', () {
      final original = Money(Decimal.parse('-1234.5678'), usd);

      final roundTripped = Money.parse(original.toCanonicalString());

      expect(roundTripped, original);
      expect(roundTripped.amount.toString(), original.amount.toString());
    });

    test('tryParse returns null for malformed input instead of throwing', () {
      expect(Money.tryParse('not a valid money string'), isNull);
      expect(Money.tryParse('12.50'), isNull); // missing currency
      expect(Money.tryParse('abc USD'), isNull); // invalid amount
    });

    test('parse throws FormatException for malformed input', () {
      expect(() => Money.parse('12.50'), throwsFormatException);
    });
  });

  group('Crypto precision', () {
    test('preserves 8+ fractional digits through arithmetic and round-trip', () {
      final btc = CurrencyCode('BTC');
      final a = Money(Decimal.parse('0.00000001'), btc); // 1 satoshi
      final b = Money(Decimal.parse('0.12345678'), btc);

      final sum = a.add(b).valueOrNull!;

      expect(sum.amount.toString(), '0.12345679');
      expect(Money.parse(sum.toCanonicalString()), sum);
    });
  });

  group('roundedForDisplay', () {
    test('rounds half-away-from-zero without mutating the stored amount', () {
      final money = Money(Decimal.parse('10.125'), usd);

      expect(money.roundedForDisplay(scale: 2), Decimal.parse('10.13'));
      expect(money.amount, Decimal.parse('10.125')); // unchanged
    });
  });
}
