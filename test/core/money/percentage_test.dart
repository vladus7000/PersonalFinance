import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/core/money/percentage.dart';

void main() {
  final usd = CurrencyCode('USD');

  test('asFraction converts an exact percentage', () {
    expect(Percentage(Decimal.fromInt(20)).asFraction(), Decimal.parse('0.2'));
  });

  test('asFraction is always exact — dividing by 100 never loses precision', () {
    // 100 = 2^2 * 5^2, so any finite Decimal divided by 100 stays finite;
    // this locks in that guarantee rather than a rounding/truncation policy.
    final fraction = Percentage(Decimal.parse('33.333333333333')).asFraction();

    expect(fraction, Decimal.parse('0.33333333333333'));
  });

  test('of applies the percentage to a Money amount', () {
    final income = Money(Decimal.fromInt(500), usd);

    final twentyPercent = Percentage(Decimal.fromInt(20)).of(income);

    expect(twentyPercent, Money(Decimal.fromInt(100), usd));
  });

  test('canonical string round-trip', () {
    final original = Percentage(Decimal.parse('12.5'));

    expect(Percentage.parse(original.toCanonicalString()), original);
  });
}
