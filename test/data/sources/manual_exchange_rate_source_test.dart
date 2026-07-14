import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';
import 'package:personal_finance_assistant/data/sources/manual_exchange_rate_source.dart';
import 'package:personal_finance_assistant/domain/entities/exchange_rate.dart';

void main() {
  final usd = CurrencyCode('USD');
  final uah = CurrencyCode('UAH');

  late AppDatabase db;
  late ManualExchangeRateSource source;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    source = ManualExchangeRateSource(db);
  });

  tearDown(() => db.close());

  test('returns null when no rate has ever been recorded', () async {
    final result = await source.latestRate(from: usd, to: uah, asOf: DateTime.utc(2026, 7, 15));

    expect(result, isNull);
  });

  test('record then latestRate round-trips the rate exactly', () async {
    final date = DateTime.utc(2026, 7, 15);
    await source.record(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('41.70'),
        effectiveDate: date,
        source: 'manual',
        isFinal: true,
      ),
    );

    final result = await source.latestRate(from: usd, to: uah, asOf: date);

    expect(result?.rate, Decimal.parse('41.70'));
    expect(result?.source, 'manual');
    expect(result?.isFinal, isTrue);
  });

  test('latestRate picks the most recent rate on or before asOf, not after', () async {
    await source.record(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('40.00'),
        effectiveDate: DateTime.utc(2026, 7, 1),
        source: 'manual',
        isFinal: true,
      ),
    );
    await source.record(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('41.00'),
        effectiveDate: DateTime.utc(2026, 7, 10),
        source: 'manual',
        isFinal: true,
      ),
    );
    await source.record(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('42.00'), // future rate, must be ignored
        effectiveDate: DateTime.utc(2026, 7, 20),
        source: 'manual',
        isFinal: true,
      ),
    );

    final result = await source.latestRate(from: usd, to: uah, asOf: DateTime.utc(2026, 7, 15));

    expect(result?.rate, Decimal.parse('41.00'));
  });
}
