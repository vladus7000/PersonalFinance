import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/core/money/percentage.dart';
import 'package:personal_finance_assistant/data/sources/manual_work_calendar_source.dart';
import 'package:personal_finance_assistant/domain/engines/currency_converter.dart';
import 'package:personal_finance_assistant/domain/engines/salary_calculator.dart';
import 'package:personal_finance_assistant/domain/entities/deduction_rule.dart';
import 'package:personal_finance_assistant/domain/entities/exchange_rate.dart';
import 'package:personal_finance_assistant/domain/entities/income_calculation_mode.dart';
import 'package:personal_finance_assistant/domain/entities/income_schedule_rule.dart';
import 'package:personal_finance_assistant/domain/entities/income_source.dart';
import 'package:personal_finance_assistant/domain/entities/income_type.dart';
import 'package:personal_finance_assistant/domain/entities/payment_part_amount.dart';
import 'package:personal_finance_assistant/domain/entities/salary_forecast_outcome.dart';
import 'package:personal_finance_assistant/domain/entities/weekend_shift_rule.dart';
import 'package:personal_finance_assistant/domain/repositories/exchange_rate_source.dart';

/// In-memory fake — same pattern as currency_converter_test.dart, keeps
/// this a pure domain-layer test with no Drift dependency (§0.1 п.4).
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

  late _FakeExchangeRateSource rateSource;
  late SalaryCalculator calculator;

  setUp(() {
    rateSource = _FakeExchangeRateSource();
    calculator = SalaryCalculator(
      const ManualWorkCalendarSource(),
      CurrencyConverter(rateSource),
    );
  });

  IncomeSource buildSource({
    required IncomeCalculationMode calculationMode,
    required List<IncomeScheduleRule> scheduleRules,
    CurrencyCode? payoutCurrency,
    DeductionRule deductionRule = const DeductionRule.none(),
    Decimal? nominal,
  }) => IncomeSource(
    name: 'Main job',
    type: IncomeType.salary,
    nominalAmount: Money(nominal ?? Decimal.fromInt(5500), usd),
    payoutCurrency: payoutCurrency ?? usd,
    calculationMode: calculationMode,
    deductionRule: deductionRule,
    startDate: DateTime.utc(2026, 1, 1),
    isActive: true,
    scheduleRules: scheduleRules,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  IncomeScheduleRule fixedRule({
    int partIndex = 0,
    required int paymentDay,
    required Decimal amount,
    WeekendShiftRule weekendShiftRule = WeekendShiftRule.none,
    int? rateFixingOffsetDays,
  }) => IncomeScheduleRule(
    partIndex: partIndex,
    paymentDay: paymentDay,
    amount: PaymentPartAmount.fixed(amount: Money(amount, usd)),
    weekendShiftRule: weekendShiftRule,
    rateFixingOffsetDays: rateFixingOffsetDays,
    isActive: true,
  );

  IncomeScheduleRule percentRule({
    int partIndex = 0,
    required int paymentDay,
    required Decimal percentage,
    WeekendShiftRule weekendShiftRule = WeekendShiftRule.none,
  }) => IncomeScheduleRule(
    partIndex: partIndex,
    paymentDay: paymentDay,
    amount: PaymentPartAmount.percentage(percentage: Percentage(percentage)),
    weekendShiftRule: weekendShiftRule,
    isActive: true,
  );

  SalaryForecastAvailable forecastOf(SalaryForecastOutcome outcome) {
    expect(outcome, isA<SalaryForecastAvailable>());
    return outcome as SalaryForecastAvailable;
  }

  test('fixed salary: full nominal amount regardless of days worked', () async {
    final rule = fixedRule(paymentDay: 30, amount: Decimal.fromInt(5500));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [rule],
    );

    final outcome = await calculator.forecast(
      source: source,
      rule: rule,
      year: 2026,
      month: 7,
      countryCode: 'UA',
      actualWorkedDays: 5, // irrelevant in fixed mode
    );

    final forecast = forecastOf(outcome).forecast;
    expect(forecast.amountContract, Money(Decimal.parse('5500.00'), usd));
    expect(forecast.amountPayout, Money(Decimal.parse('5500.00'), usd));
    expect(forecast.rate, Decimal.one);
    expect(forecast.rateSource, 'identity');
    expect(forecast.isRateStale, isFalse);
  });

  test('by working days: an incomplete month prorates the amount', () async {
    final rule = percentRule(paymentDay: 30, percentage: Decimal.fromInt(100));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.byWorkingDays,
      scheduleRules: [rule],
    );

    // July 2026 has 23 working days (verified by manual_work_calendar_source_test.dart).
    final outcome = await calculator.forecast(
      source: source,
      rule: rule,
      year: 2026,
      month: 7,
      countryCode: 'UA',
      actualWorkedDays: 15,
    );

    final forecast = forecastOf(outcome).forecast;
    expect(forecast.workingDays, 23);
    final expected = (Decimal.fromInt(5500) * Decimal.fromInt(15) / Decimal.fromInt(23))
        .toDecimal(scaleOnInfinitePrecision: 10)
        .round(scale: 2);
    expect(forecast.amountContract, Money(expected, usd));
  });

  test('two parts (advance % + main fixed) forecast independently by partIndex', () async {
    final advance = percentRule(partIndex: 0, paymentDay: 15, percentage: Decimal.fromInt(50));
    final main = fixedRule(partIndex: 1, paymentDay: 30, amount: Decimal.fromInt(2750));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [advance, main],
    );

    final advanceForecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: advance,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;
    final mainForecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: main,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;

    expect(advanceForecast.partIndex, 0);
    expect(advanceForecast.amountContract, Money(Decimal.parse('2750.00'), usd));
    expect(mainForecast.partIndex, 1);
    expect(mainForecast.amountContract, Money(Decimal.parse('2750.00'), usd));
  });

  test('contract USD, payout UAH: converts using the stored rate', () async {
    rateSource.rates.add(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('41.70'),
        effectiveDate: DateTime.utc(2026, 7, 15),
        source: 'manual',
        isFinal: true,
      ),
    );
    final rule = fixedRule(paymentDay: 15, amount: Decimal.fromInt(5500));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [rule],
      payoutCurrency: uah,
    );

    final forecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: rule,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;

    expect(forecast.amountPayout, Money(Decimal.parse('229350.00'), uah));
    expect(forecast.rate, Decimal.parse('41.70'));
    expect(forecast.rateSource, 'manual');
    expect(forecast.isRateStale, isFalse);
  });

  test('rate fixing offset: the rate is looked up before the payment date, not on it', () async {
    rateSource.rates.addAll([
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('41.00'),
        effectiveDate: DateTime.utc(2026, 7, 13),
        source: 'manual',
        isFinal: true,
      ),
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('42.00'),
        effectiveDate: DateTime.utc(2026, 7, 15),
        source: 'manual',
        isFinal: true,
      ),
    ]);
    final rule = fixedRule(
      paymentDay: 15,
      amount: Decimal.fromInt(100),
      rateFixingOffsetDays: 2, // fixed on the 13th, not the 15th
    );
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [rule],
      payoutCurrency: uah,
    );

    final forecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: rule,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;

    expect(forecast.rate, Decimal.parse('41.00'));
  });

  test('percentage deduction reduces the part amount directly', () async {
    final rule = fixedRule(paymentDay: 30, amount: Decimal.fromInt(5500));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [rule],
      deductionRule: DeductionRule.percentage(percentage: Percentage(Decimal.fromInt(18))),
    );

    final forecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: rule,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;

    // 5500 - 18% = 4510.
    expect(forecast.amountContract, Money(Decimal.parse('4510.00'), usd));
  });

  test('a fixed deduction is split proportionally across active parts, not duplicated', () async {
    final advance = percentRule(partIndex: 0, paymentDay: 15, percentage: Decimal.fromInt(50));
    final main = percentRule(partIndex: 1, paymentDay: 30, percentage: Decimal.fromInt(50));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [advance, main],
      deductionRule: DeductionRule.fixedAmount(amount: Money(Decimal.fromInt(200), usd)),
    );

    final advanceForecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: advance,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;
    final mainForecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: main,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;

    // Both parts are equal shares (50/50), so the $200 deduction splits
    // evenly: 2750 - 100 = 2650 each. Together they still sum to 5500 - 200.
    expect(advanceForecast.amountContract, Money(Decimal.parse('2650.00'), usd));
    expect(mainForecast.amountContract, Money(Decimal.parse('2650.00'), usd));
  });

  test('weekend shift: a payment day landing on a weekend moves as configured', () async {
    // Find a Saturday in July 2026 to use as the nominal payment day.
    final saturday = [
      for (var day = 1; day <= 31; day++) DateTime.utc(2026, 7, day),
    ].firstWhere((d) => d.weekday == DateTime.saturday);

    final noShift = fixedRule(
      paymentDay: saturday.day,
      amount: Decimal.fromInt(100),
      weekendShiftRule: WeekendShiftRule.none,
    );
    final shiftBack = fixedRule(
      paymentDay: saturday.day,
      amount: Decimal.fromInt(100),
      weekendShiftRule: WeekendShiftRule.moveToPreviousBusinessDay,
    );
    final shiftForward = fixedRule(
      paymentDay: saturday.day,
      amount: Decimal.fromInt(100),
      weekendShiftRule: WeekendShiftRule.moveToNextBusinessDay,
    );
    final source = buildSource(calculationMode: IncomeCalculationMode.fixed, scheduleRules: []);

    Future<DateTime> expectedDateFor(IncomeScheduleRule rule) async => forecastOf(
      await calculator.forecast(
        source: source,
        rule: rule,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast.expectedDate;

    expect(await expectedDateFor(noShift), saturday);
    expect(await expectedDateFor(shiftBack), saturday.subtract(const Duration(days: 1)));
    // Saturday + 1 day is still Sunday (a weekend day) — the shift must
    // keep moving until it actually lands on a business day (Monday).
    expect(await expectedDateFor(shiftForward), saturday.add(const Duration(days: 2)));
  });

  test('a payment day beyond the month length clamps to the last day', () async {
    final rule = fixedRule(paymentDay: 31, amount: Decimal.fromInt(100));
    final source = buildSource(calculationMode: IncomeCalculationMode.fixed, scheduleRules: [rule]);

    final forecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: rule,
        year: 2026,
        month: 2, // February 2026 has 28 days
        countryCode: 'UA',
      ),
    ).forecast;

    expect(forecast.expectedDate, DateTime.utc(2026, 2, 28));
  });

  test('no rate available: flagged as rate-missing, not a crash', () async {
    final rule = fixedRule(paymentDay: 30, amount: Decimal.fromInt(5500));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [rule],
      payoutCurrency: uah,
    );

    final outcome = await calculator.forecast(
      source: source,
      rule: rule,
      year: 2026,
      month: 7,
      countryCode: 'UA',
    );

    expect(outcome, isA<SalaryForecastRateMissing>());
    final missing = outcome as SalaryForecastRateMissing;
    expect(missing.amountContract, Money(Decimal.parse('5500.00'), usd));
    expect(missing.partIndex, 0);
  });

  test('a rate older than the fixing date is used but flagged stale', () async {
    rateSource.rates.add(
      ExchangeRate(
        from: usd,
        to: uah,
        rate: Decimal.parse('40.00'),
        effectiveDate: DateTime.utc(2026, 6, 1),
        source: 'manual',
        isFinal: true,
      ),
    );
    final rule = fixedRule(paymentDay: 15, amount: Decimal.fromInt(100));
    final source = buildSource(
      calculationMode: IncomeCalculationMode.fixed,
      scheduleRules: [rule],
      payoutCurrency: uah,
    );

    final forecast = forecastOf(
      await calculator.forecast(
        source: source,
        rule: rule,
        year: 2026,
        month: 7,
        countryCode: 'UA',
      ),
    ).forecast;

    expect(forecast.isRateStale, isTrue);
  });
}
