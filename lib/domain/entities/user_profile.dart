import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/currency_code.dart';

part 'user_profile.freezed.dart';

/// The single local user's profile — doc.md §4.1. Exactly one row ever
/// exists locally in MVP (no accounts/sync yet); [householdId] is nullable
/// and unused until family mode (compat principle #7, BUILD_PLAN.md §0.1).
@freezed
sealed class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String displayName,
    required String countryCode,
    required String timezone,
    required CurrencyCode primaryCurrency,
    required List<CurrencyCode> additionalCurrencies,
    required String locale,
    required String dateFormat,
    required String numberFormat,
    required int financialMonthStartDay,
    required bool onboardingCompleted,
    required bool familyModeEnabled,
    required bool biometricLockEnabled,
    required bool hideBalancesEnabled,
    String? householdId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserProfile;
}
