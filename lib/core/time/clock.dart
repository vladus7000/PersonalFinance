/// Injectable source of "now". Engines and repositories must go through
/// this instead of calling `DateTime.now()` directly — see BUILD_PLAN.md
/// §0.1: determinism in tests requires a fixed clock, and this session's
/// tooling forbids bare `DateTime.now()` calls for the same reason.
abstract class Clock {
  DateTime now();

  /// Today's calendar date at midnight UTC, for the given IANA [timezone].
  ///
  /// [timezone] is accepted now so callers don't need to change signatures
  /// later, but it is not yet honoured — real timezone-aware resolution
  /// lands with `UserProfile.timezone` in E2. Until then this always
  /// returns the UTC calendar date.
  DateTime today({String? timezone});
}

/// Production implementation — wraps the real system clock.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  DateTime today({String? timezone}) {
    final n = now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }
}

/// Test implementation — always returns the same instant, so calculations
/// that depend on "now" (salary forecasts, cycle boundaries, snapshots)
/// are deterministic and reproducible.
class FixedClock implements Clock {
  const FixedClock(this.fixedNow);

  final DateTime fixedNow;

  @override
  DateTime now() => fixedNow;

  @override
  DateTime today({String? timezone}) {
    final n = fixedNow.toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }
}
