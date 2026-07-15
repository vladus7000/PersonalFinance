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

  test('a fromDay/toDay range counts only weekdays within that range', () async {
    // July 2026 1st-15th: verified against manual_work_calendar_source_test.dart's
    // whole-month count (23) and the salary_calculator_test.dart split (11/12).
    final firstHalf = await source.workingDaysIn(
      countryCode: 'UA',
      year: 2026,
      month: 7,
      fromDay: 1,
      toDay: 15,
    );
    final secondHalf = await source.workingDaysIn(
      countryCode: 'UA',
      year: 2026,
      month: 7,
      fromDay: 16,
      toDay: 31,
    );
    expect(firstHalf, 11);
    expect(secondHalf, 12);
    expect(firstHalf + secondHalf, 23); // matches the whole-month count
  });

  test('a toDay beyond the month length clamps to the last real day', () async {
    // February 2026 has 28 days — asking for up to day 31 must not throw or
    // count nonexistent days.
    final wholeMonth = await source.workingDaysIn(countryCode: 'UA', year: 2026, month: 2);
    final clamped = await source.workingDaysIn(
      countryCode: 'UA',
      year: 2026,
      month: 2,
      toDay: 31,
    );
    expect(clamped, wholeMonth);
  });
}
