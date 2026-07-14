import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/time/clock.dart';

void main() {
  group('FixedClock', () {
    test('now() always returns the same instant, deterministically', () {
      final fixed = DateTime.utc(2026, 7, 15, 10, 30);
      final clock = FixedClock(fixed);

      expect(clock.now(), fixed);
      expect(clock.now(), fixed); // calling twice must not drift
    });

    test('today() truncates to the UTC calendar date at midnight', () {
      final clock = FixedClock(DateTime.utc(2026, 7, 15, 23, 59, 59));

      expect(clock.today(), DateTime.utc(2026, 7, 15));
    });
  });

  group('SystemClock', () {
    test('now() reflects the real wall clock (within a generous tolerance)', () {
      const clock = SystemClock();

      final before = DateTime.now();
      final observed = clock.now();
      final after = DateTime.now();

      expect(
        observed.isAfter(before.subtract(const Duration(seconds: 1))) &&
            observed.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
