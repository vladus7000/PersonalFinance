import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/data/sources/manual_work_calendar_source.dart';

void main() {
  final source = ManualWorkCalendarSource();

  test('counts Mon-Fri days in a month with no holidays', () async {
    // July 2026: 1 Wed .. 31 Fri, 23 weekdays.
    final workingDays = await source.workingDaysIn(countryCode: 'UA', year: 2026, month: 7);
    expect(workingDays, 23);
  });

  test('subtracts manually supplied holiday days that fall on a weekday', () async {
    // July 4, 2026 is a Saturday already excluded — pick a weekday holiday.
    final workingDays = await source.workingDaysIn(
      countryCode: 'UA',
      year: 2026,
      month: 7,
      manualHolidayDays: {1, 2}, // Wed, Thu
    );
    expect(workingDays, 21);
  });

  test('handles December correctly (month + 1 wraps into the next year)', () async {
    final workingDays = await source.workingDaysIn(countryCode: 'UA', year: 2026, month: 12);
    // December 2026: 1 Tue .. 31 Thu, 23 weekdays.
    expect(workingDays, 23);
  });
}
