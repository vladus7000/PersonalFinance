import '../../domain/repositories/work_calendar_source.dart';

/// MVP [WorkCalendarSource]: counts Mon-Fri days in the month, minus any
/// day the caller marks as a holiday. No official holiday calendar is
/// looked up (doc.md §4.4 `WorkCalendar` is out of scope) — `countryCode`
/// is accepted now so callers don't need to change signatures once a real
/// calendar-backed source lands (same pattern as [Clock.today]).
class ManualWorkCalendarSource implements WorkCalendarSource {
  const ManualWorkCalendarSource();

  @override
  Future<int> workingDaysIn({
    required String countryCode,
    required int year,
    required int month,
    int fromDay = 1,
    int? toDay,
    Set<int> manualHolidayDays = const {},
  }) async {
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    final start = fromDay < 1 ? 1 : fromDay;
    final end = (toDay == null || toDay > daysInMonth) ? daysInMonth : toDay;

    var count = 0;
    for (var day = start; day <= end; day++) {
      if (manualHolidayDays.contains(day)) continue;
      final weekday = DateTime.utc(year, month, day).weekday;
      if (weekday != DateTime.saturday && weekday != DateTime.sunday) count++;
    }
    return count;
  }
}
