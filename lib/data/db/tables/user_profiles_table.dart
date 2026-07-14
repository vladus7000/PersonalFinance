import 'package:drift/drift.dart';

/// Singleton row: `id` is always `1`, never auto-incremented — there is
/// exactly one local user profile in MVP (see [UserProfileRepository]).
/// `additional_currencies` is JSON-encoded `List<String>` (currency codes).
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  IntColumn get id => integer()();

  TextColumn get displayName => text().named('display_name')();

  TextColumn get countryCode => text().named('country_code')();

  TextColumn get timezone => text()();

  TextColumn get primaryCurrency => text().named('primary_currency')();

  TextColumn get additionalCurrencies => text().named('additional_currencies')();

  TextColumn get locale => text()();

  TextColumn get dateFormat => text().named('date_format')();

  TextColumn get numberFormat => text().named('number_format')();

  IntColumn get financialMonthStartDay => integer().named('financial_month_start_day')();

  BoolColumn get onboardingCompleted =>
      boolean().named('onboarding_completed').withDefault(const Constant(false))();

  BoolColumn get familyModeEnabled =>
      boolean().named('family_mode_enabled').withDefault(const Constant(false))();

  BoolColumn get biometricLockEnabled =>
      boolean().named('biometric_lock_enabled').withDefault(const Constant(false))();

  BoolColumn get hideBalancesEnabled =>
      boolean().named('hide_balances_enabled').withDefault(const Constant(false))();

  /// Nullable, unused until family mode — compat principle #7, BUILD_PLAN.md §0.1.
  TextColumn get householdId => text().named('household_id').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
