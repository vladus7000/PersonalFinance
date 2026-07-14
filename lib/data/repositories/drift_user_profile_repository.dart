import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/money/currency_code.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../db/app_database.dart';

/// Singleton row at `id = 1` — see [UserProfiles] table doc.
class DriftUserProfileRepository implements UserProfileRepository {
  const DriftUserProfileRepository(this._db);

  static const _singletonId = 1;

  final AppDatabase _db;

  @override
  Future<UserProfile?> getProfile() async {
    final row = await (_db.select(
      _db.userProfiles,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    return _db
        .into(_db.userProfiles)
        .insertOnConflictUpdate(
          UserProfilesCompanion.insert(
            id: const Value(_singletonId),
            displayName: profile.displayName,
            countryCode: profile.countryCode,
            timezone: profile.timezone,
            primaryCurrency: profile.primaryCurrency.value,
            additionalCurrencies: _encodeCurrencies(profile.additionalCurrencies),
            locale: profile.locale,
            dateFormat: profile.dateFormat,
            numberFormat: profile.numberFormat,
            financialMonthStartDay: profile.financialMonthStartDay,
            onboardingCompleted: Value(profile.onboardingCompleted),
            familyModeEnabled: Value(profile.familyModeEnabled),
            biometricLockEnabled: Value(profile.biometricLockEnabled),
            hideBalancesEnabled: Value(profile.hideBalancesEnabled),
            householdId: Value(profile.householdId),
            // .toUtc() on write too: defensive against a caller passing a
            // local-zone DateTime — see BUILD_PLAN.md §0.4 on Drift/DateTime.
            createdAt: profile.createdAt.toUtc(),
            updatedAt: profile.updatedAt.toUtc(),
          ),
        );
  }

  UserProfile _toDomain(UserProfileRow row) => UserProfile(
    displayName: row.displayName,
    countryCode: row.countryCode,
    timezone: row.timezone,
    primaryCurrency: CurrencyCode(row.primaryCurrency),
    additionalCurrencies: _decodeCurrencies(row.additionalCurrencies),
    locale: row.locale,
    dateFormat: row.dateFormat,
    numberFormat: row.numberFormat,
    financialMonthStartDay: row.financialMonthStartDay,
    onboardingCompleted: row.onboardingCompleted,
    familyModeEnabled: row.familyModeEnabled,
    biometricLockEnabled: row.biometricLockEnabled,
    hideBalancesEnabled: row.hideBalancesEnabled,
    householdId: row.householdId,
    // Drift does not preserve DateTime.isUtc through storage — it comes
    // back as a local-zone DateTime representing the same instant. Dart's
    // DateTime.== considers isUtc, not just the instant, so every DateTime
    // read from Drift MUST be normalized here. See BUILD_PLAN.md §0.4.
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );

  String _encodeCurrencies(List<CurrencyCode> currencies) =>
      jsonEncode(currencies.map((c) => c.value).toList());

  List<CurrencyCode> _decodeCurrencies(String json) =>
      (jsonDecode(json) as List<dynamic>).map((c) => CurrencyCode(c as String)).toList();
}
