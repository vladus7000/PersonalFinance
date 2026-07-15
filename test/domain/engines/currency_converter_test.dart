import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/domain/engines/currency_converter.dart';
import 'package:personal_finance_assistant/domain/entities/exchange_rate.dart';
import 'package:personal_finance_assistant/domain/repositories/exchange_rate_source.dart';

/// In-memory fake — keeps this a pure domain-layer test with no Drift
/// dependency, per BUILD_PLAN.md §0.1 п.4.
class _FakeExchangeRateSource implements ExchangeRateSource {
  final List<ExchangeRate> rates = [];

  @override
  Future<ExchangeRate?> latestRate({
    required CurrencyCode from,
    required CurrencyCode to,
    required DateTime asOf,
  }) async {
    final candidates = rates
        .where((r) => r.from == from && r.to == to && !r.effectiveDate.isAfter(asOf))
        .toList()
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return candidates.isEmpty ? null : candidates.first;
  }
}

void main() {
  final usd = CurrencyCode('USD');
  final uah = CurrencyCode('UAH');
  final today = DateTime.utc(2026, 7, 15);

  late _FakeExchangeRateSource source;
  late CurrencyConverter converter;

  setUp(() {
    source = _FakeExchangeRateSource();
    converter = CurrencyConverter(source);
  });

  test('same currency converts as identity, no rate lookup needed', () async {
    final amount = Money(Decimal.fromInt(100), usd);

    final outcome = await converter.convert(amount: amount, to: usd, asOf: today);

    expect(
      outcome,
      ConversionOutcome.converted(
        money: amount,
        rate: Decimal.one,
        rateEffectiveDate: today,
        isStale: false,
        rateSource: 'identity',
      ),
    );
  });

  test('direct rate: uses the stored USD->UAH rate for today, not stale', () async {
    source.rates.add(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('41.70'),
        effectiveDate: today,
        source: 'manual',
        isFinal: true,
      ),
    );

    final outcome = await converter.convert(
      amount: Money(Decimal.fromInt(100), usd),
      to: uah,
      asOf: today,
    );

    final converted = outcome as ConvertedOutcome;
    expect(converted.money, Money(Decimal.parse('4170.00'), uah));
    expect(converted.isStale, isFalse);
    expect(converted.rateSource, 'manual');
  });

  test('reverse rate: only UAH->USD is stored, USD->UAH is derived by inversion', () async {
    source.rates.add(
      ExchangeRate(
        from: uah,
        to: usd,
        rate: Decimal.parse('0.025'), // 1 / 40
        effectiveDate: today,
        source: 'manual',
        isFinal: true,
      ),
    );

    final outcome = await converter.convert(
      amount: Money(Decimal.fromInt(100), usd),
      to: uah,
      asOf: today,
    );

    final converted = outcome as ConvertedOutcome;
    expect(converted.money, Money(Decimal.parse('4000.0000000000'), uah));
    expect(converted.rateSource, 'manual');
  });

  test('missing rate: neither direct nor reverse exists -> flagged missing', () async {
    final outcome = await converter.convert(
      amount: Money(Decimal.fromInt(100), usd),
      to: uah,
      asOf: today,
    );

    expect(outcome, ConversionOutcome.missing(from: usd, to: uah));
  });

  test('a rate older than asOf is used but flagged stale', () async {
    final lastWeek = today.subtract(const Duration(days: 7));
    source.rates.add(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('41.00'),
        effectiveDate: lastWeek,
        source: 'manual',
        isFinal: true,
      ),
    );

    final outcome = await converter.convert(
      amount: Money(Decimal.fromInt(100), usd),
      to: uah,
      asOf: today,
    );

    final converted = outcome as ConvertedOutcome;
    expect(converted.isStale, isTrue);
    expect(converted.rateEffectiveDate, lastWeek);
  });
}
