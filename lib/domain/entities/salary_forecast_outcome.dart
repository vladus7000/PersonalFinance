import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import 'salary_forecast.dart';

part 'salary_forecast_outcome.freezed.dart';

/// Result of `SalaryCalculator.forecast`. Deliberately not a
/// `Result<T, Failure>` (BUILD_PLAN.md §0.1 п.8), mirroring
/// [ConversionOutcome]: a missing exchange rate is an expected, common
/// outcome (no rate has been entered yet) that the UI must show a
/// still-useful partial answer for (doc.md §2.4 "диапазон, если курс ещё
/// неизвестен"), not an exceptional failure to short-circuit on.
@freezed
sealed class SalaryForecastOutcome with _$SalaryForecastOutcome {
  const factory SalaryForecastOutcome.forecast({required SalaryForecast forecast}) =
      SalaryForecastAvailable;

  const factory SalaryForecastOutcome.rateMissing({
    required DateTime expectedDate,
    required Money amountContract,
    required int workingDays,
    required int partIndex,
  }) = SalaryForecastRateMissing;
}
