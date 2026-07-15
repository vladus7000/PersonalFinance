import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';

part 'salary_forecast.freezed.dart';

/// The result of forecasting a single [IncomeScheduleRule] payment part —
/// doc.md §2.3/§2.4, produced by `SalaryCalculator` (BUILD_PLAN.md E3.T2).
@freezed
sealed class SalaryForecast with _$SalaryForecast {
  const factory SalaryForecast({
    required DateTime expectedDate,
    required Money amountContract,
    required Money amountPayout,
    required Decimal rate,
    required String rateSource,
    required int workingDays,
    required int partIndex,
    required bool isRateStale,
  }) = _SalaryForecast;
}
