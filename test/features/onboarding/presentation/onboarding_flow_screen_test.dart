import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/app/di.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/time/clock.dart';
import 'package:personal_finance_assistant/domain/entities/user_profile.dart';
import 'package:personal_finance_assistant/domain/repositories/user_profile_repository.dart';
import 'package:personal_finance_assistant/main.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  UserProfile? profile;

  @override
  Future<UserProfile?> getProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile newProfile) async {
    profile = newProfile;
  }
}

UserProfile _completedProfile() => UserProfile(
  displayName: '',
  countryCode: '',
  timezone: 'UTC',
  primaryCurrency: CurrencyCode('USD'),
  additionalCurrencies: const [],
  locale: 'en',
  dateFormat: 'dd.MM.yyyy',
  numberFormat: '#,##0.00',
  financialMonthStartDay: 1,
  onboardingCompleted: true,
  familyModeEnabled: false,
  biometricLockEnabled: false,
  hideBalancesEnabled: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('first launch with no profile redirects to onboarding welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(_FakeUserProfileRepository()),
        ],
        child: const PfaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('a completed profile skips onboarding and lands on the Dashboard', (tester) async {
    final repository = _FakeUserProfileRepository()..profile = _completedProfile();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [userProfileRepositoryProvider.overrideWithValue(repository)],
        child: const PfaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsNothing);
    expect(find.text('Overview'), findsWidgets);
  });

  testWidgets('completing onboarding saves the profile and navigates to the Dashboard', (
    tester,
  ) async {
    final repository = _FakeUserProfileRepository();
    final clock = FixedClock(DateTime.utc(2026, 7, 15));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
        ],
        child: const PfaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Welcome -> Start.
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Currency step: default primary currency is committed asynchronously
    // (see CurrencyStepScreen.initState) — settle, then advance since the
    // required step is already complete.
    expect(find.text('Your main currency'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Life expenses is optional and last — Skip is hidden here (see
    // OnboardingShell), so the primary "Finish" button both leaves it empty
    // and advances to the summary.
    expect(find.text('Monthly living expenses'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    // Summary -> Open Dashboard.
    expect(find.text("You're all set"), findsOneWidget);
    await tester.tap(find.text('Open Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsWidgets);
    expect(repository.profile, isNotNull);
    expect(repository.profile!.onboardingCompleted, isTrue);
    expect(repository.profile!.primaryCurrency, CurrencyCode('USD'));
    expect(repository.profile!.createdAt, clock.now());
  });
}
