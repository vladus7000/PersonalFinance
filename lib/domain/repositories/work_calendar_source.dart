/// Abstraction over "how many working days are in a given month" (BUILD_PLAN.md
/// §0.1 compat principle #2, mirroring [ExchangeRateSource]). MVP has a
/// single implementation, `ManualWorkCalendarSource` (data/sources/), which
/// counts weekdays and accepts caller-supplied holiday overrides — a real
/// country-calendar-backed source (doc.md §4.4 `WorkCalendar`) can
/// implement this later without touching `SalaryCalculator` or any UI.
abstract class WorkCalendarSource {
  /// Working days in [year]-[month] for [countryCode], excluding weekends
  /// and any day listed in [manualHolidayDays] (1-based day-of-month).
  Future<int> workingDaysIn({
    required String countryCode,
    required int year,
    required int month,
    Set<int> manualHolidayDays = const {},
  });
}
