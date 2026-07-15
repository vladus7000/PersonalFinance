import 'package:decimal/decimal.dart';

import '../../core/money/money.dart';
import '../entities/deduction_rule.dart';
import '../entities/income_calculation_mode.dart';
import '../entities/income_schedule_rule.dart';
import '../entities/income_source.dart';
import '../entities/payment_part_amount.dart';
import '../entities/salary_forecast.dart';
import '../entities/salary_forecast_outcome.dart';
import '../entities/weekend_shift_rule.dart';
import '../repositories/work_calendar_source.dart';
import 'currency_converter.dart';

/// Forecasts the expected payout of one [IncomeScheduleRule] part of an
/// [IncomeSource] — doc.md §2.3, the most consequential calculation in the
/// app (BUILD_PLAN.md E3.T2). Pure domain logic: no Flutter/Drift
/// dependency (§0.1 п.4), fully deterministic given a fixed [Clock] is not
/// even needed here — every "now" the calculation depends on ([year],
/// [month], the exchange rate's `asOf`) is an explicit parameter.
///
/// Calculation pipeline for a single part (documented since doc.md does not
/// specify composition order):
/// 1. Gross amount: a `fixed` part is taken literally; a `percentage` part
///    is that percentage of [IncomeSource.nominalAmount].
/// 2. If [IncomeSource.calculationMode] is `byWorkingDays`, the gross
///    amount is scaled by `workedDays / workingDays` (incomplete month).
/// 3. [IncomeSource.deductionRule] is applied to this part: a `percentage`
///    deduction applies directly to this part's (prorated) gross amount; a
///    `fixedAmount` deduction is split across all of the source's active
///    schedule rules proportionally to their own (prorated) gross amounts —
///    otherwise calling `forecast` once per part would subtract the full
///    fixed deduction from each part, over-deducting by a multiple of the
///    part count.
/// 4. The expected date is [IncomeScheduleRule.paymentDay] in
///    [year]/`month + `[IncomeScheduleRule.paymentMonthOffset] (payroll
///    commonly pays a period in the month that follows it), adjusted by
///    [IncomeScheduleRule.weekendShiftRule].
/// 5. The exchange rate is fixed on [IncomeScheduleRule.rateFixingDay] of
///    the *forecasted period's* [year]/[month] — not the payment month —
///    so every part of the same period shares one rate even when paid in
///    different months; `null` means the rate is fixed on the expected
///    date itself.
/// 6. The net contract-currency amount is converted to
///    [IncomeSource.payoutCurrency] via [CurrencyConverter]. Both returned
///    amounts are rounded to [roundingScale] fractional digits — the
///    stored [IncomeSource.nominalAmount] itself is never rounded.
class SalaryCalculator {
  const SalaryCalculator(this._workCalendarSource, this._currencyConverter);

  final WorkCalendarSource _workCalendarSource;
  final CurrencyConverter _currencyConverter;

  Future<SalaryForecastOutcome> forecast({
    required IncomeSource source,
    required IncomeScheduleRule rule,
    required int year,
    required int month,
    required String countryCode,
    int? actualWorkedDays,
    Set<int> manualHolidayDays = const {},
    int roundingScale = 2,
  }) async {
    final workingDays = await _workCalendarSource.workingDaysIn(
      countryCode: countryCode,
      year: year,
      month: month,
      manualHolidayDays: manualHolidayDays,
    );
    final workedDays = actualWorkedDays ?? workingDays;

    final expectedDate = _resolvePaymentDate(
      year: year,
      month: month + rule.paymentMonthOffset,
      paymentDay: rule.paymentDay,
      shiftRule: rule.weekendShiftRule,
    );

    var partAmount = _grossFor(source.nominalAmount, rule.amount);
    if (source.calculationMode == IncomeCalculationMode.byWorkingDays) {
      partAmount = _prorate(partAmount, workedDays: workedDays, workingDays: workingDays);
    }

    final deduction = _deductionFor(
      source: source,
      partAmount: partAmount,
      workedDays: workedDays,
      workingDays: workingDays,
    );
    final netResult = partAmount.subtract(deduction);
    final partNet = netResult.valueOrNull;
    if (partNet == null) {
      // Only reachable if a DeductionRule.Money was constructed in a
      // currency other than the source's contract currency — a data-entry
      // bug, not a recoverable domain case (same reasoning as
      // Money.compareTo's ArgumentError).
      throw ArgumentError(
        'IncomeSource.deductionRule currency must match nominalAmount.currency',
      );
    }

    final rateFixingDate = rule.rateFixingDay == null
        ? expectedDate
        : _clampedDate(year: year, month: month, day: rule.rateFixingDay!);
    final conversion = await _currencyConverter.convert(
      amount: partNet,
      to: source.payoutCurrency,
      asOf: rateFixingDate,
    );

    final roundedContract = Money(partNet.amount.round(scale: roundingScale), partNet.currency);

    return switch (conversion) {
      ConvertedOutcome(
        money: final money,
        rate: final rate,
        isStale: final isStale,
        rateSource: final rateSource,
      ) =>
        SalaryForecastOutcome.forecast(
          forecast: SalaryForecast(
            expectedDate: expectedDate,
            amountContract: roundedContract,
            amountPayout: Money(money.amount.round(scale: roundingScale), money.currency),
            rate: rate,
            rateSource: rateSource,
            workingDays: workingDays,
            partIndex: rule.partIndex,
            isRateStale: isStale,
          ),
        ),
      MissingRateOutcome() => SalaryForecastOutcome.rateMissing(
        expectedDate: expectedDate,
        amountContract: roundedContract,
        workingDays: workingDays,
        partIndex: rule.partIndex,
      ),
    };
  }

  Money _grossFor(Money nominal, PaymentPartAmount amount) => switch (amount) {
    FixedPaymentPart(:final amount) => amount,
    PercentagePaymentPart(:final percentage) => percentage.of(nominal),
  };

  Money _prorate(Money gross, {required int workedDays, required int workingDays}) {
    if (workingDays <= 0) {
      throw ArgumentError('workingDays must be > 0 to prorate a byWorkingDays income source');
    }
    final fraction = (Decimal.fromInt(workedDays) / Decimal.fromInt(workingDays)).toDecimal(
      scaleOnInfinitePrecision: 10,
    );
    return gross.multiply(fraction);
  }

  Money _deductionFor({
    required IncomeSource source,
    required Money partAmount,
    required int workedDays,
    required int workingDays,
  }) {
    final rule = source.deductionRule;
    return switch (rule) {
      NoDeduction() => Money.zero(partAmount.currency),
      PercentageDeduction(:final percentage) => percentage.of(partAmount),
      FixedDeduction(:final amount) => _proportionalShare(
        totalDeduction: amount,
        partAmount: partAmount,
        source: source,
        workedDays: workedDays,
        workingDays: workingDays,
      ),
    };
  }

  /// This part's share of a source-wide fixed deduction, proportional to
  /// its (prorated) gross amount among all active schedule rules — see
  /// class doc point 3.
  Money _proportionalShare({
    required Money totalDeduction,
    required Money partAmount,
    required IncomeSource source,
    required int workedDays,
    required int workingDays,
  }) {
    var totalGross = Decimal.zero;
    for (final rule in source.scheduleRules.where((r) => r.isActive)) {
      var gross = _grossFor(source.nominalAmount, rule.amount);
      if (source.calculationMode == IncomeCalculationMode.byWorkingDays) {
        gross = _prorate(gross, workedDays: workedDays, workingDays: workingDays);
      }
      totalGross += gross.amount;
    }
    if (totalGross == Decimal.zero) return Money.zero(partAmount.currency);

    final share = (partAmount.amount / totalGross).toDecimal(scaleOnInfinitePrecision: 10);
    return totalDeduction.multiply(share);
  }

  DateTime _resolvePaymentDate({
    required int year,
    required int month,
    required int paymentDay,
    required WeekendShiftRule shiftRule,
  }) {
    var date = _clampedDate(year: year, month: month, day: paymentDay);

    while (shiftRule != WeekendShiftRule.none &&
        (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) {
      date = shiftRule == WeekendShiftRule.moveToPreviousBusinessDay
          ? date.subtract(const Duration(days: 1))
          : date.add(const Duration(days: 1));
    }
    return date;
  }

  /// [year]/[month]/[day], with [day] clamped to the last real day of that
  /// month (e.g. day 31 in February becomes the 28th/29th).
  DateTime _clampedDate({required int year, required int month, required int day}) {
    final lastDayOfMonth = DateTime.utc(year, month + 1, 0).day;
    final clampedDay = day > lastDayOfMonth ? lastDayOfMonth : day;
    return DateTime.utc(year, month, clampedDay);
  }
}
