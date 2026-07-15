/// Abstraction over "how many working days are in a given month" (BUILD_PLAN.md
/// §0.1 compat principle #2, mirroring [ExchangeRateSource]). MVP has a
/// single implementation, `ManualWorkCalendarSource` (data/sources/), which
/// counts weekdays and accepts caller-supplied holiday overrides — a real
/// country-calendar-backed source (doc.md §4.4 `WorkCalendar`) can
/// implement this later without touching `SalaryCalculator` or any UI.
abstract class WorkCalendarSource {
  /// Working days in `[fromDay, toDay]` (inclusive, both 1-based
  /// day-of-month, clamped to the real length of [month]) of [year]-[month]
  /// for [countryCode], excluding weekends and any day listed in
  /// [manualHolidayDays]. Defaults to the whole month — used both as the
  /// whole-month denominator for a daily rate and, restricted to one
  /// [IncomeScheduleRule]'s coverage range, as that part's own numerator
  /// (`SalaryCalculator`, E3.T2/doc.md §8.18).
  Future<int> workingDaysIn({
    required String countryCode,
    required int year,
    required int month,
    int fromDay = 1,
    int? toDay,
    Set<int> manualHolidayDays = const {},
  });
}
