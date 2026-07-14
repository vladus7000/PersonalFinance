import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';

void main() {
  test('normalizes to upper case', () {
    expect(CurrencyCode('usd'), CurrencyCode('USD'));
  });

  test('accepts fiat and crypto/ledger codes of varying length', () {
    expect(() => CurrencyCode('UAH'), returnsNormally);
    expect(() => CurrencyCode('USDT'), returnsNormally);
    expect(() => CurrencyCode('BTC'), returnsNormally);
  });

  test('rejects malformed codes', () {
    expect(() => CurrencyCode(''), throwsArgumentError);
    expect(() => CurrencyCode('U'), throwsArgumentError);
    expect(() => CurrencyCode('US D'), throwsArgumentError);
    expect(() => CurrencyCode('12345678901'), throwsArgumentError);
  });
}
