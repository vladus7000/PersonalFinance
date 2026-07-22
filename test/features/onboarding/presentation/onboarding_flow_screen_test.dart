import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/app/di.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/core/time/clock.dart';
import 'package:personal_finance_assistant/domain/entities/income_source.dart';
import 'package:personal_finance_assistant/domain/entities/user_profile.dart';
import 'package:personal_finance_assistant/domain/repositories/income_source_repository.dart';
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

/// In-memory fake — the onboarding flow now also persists an [IncomeSource]
/// on completion, so this test can't rely solely on overriding
/// [userProfileRepositoryProvider]: without this, `_completeOnboarding`
/// would fall through to the real Drift-backed repository (and a real,
/// unavailable-in-tests file-backed database via path_provider).
class _FakeIncomeSourceRepository implements IncomeSourceRepository {
  final List<IncomeSource> sources = [];

  @override
  Future<List<IncomeSource>> getAll() async => sources;

  @override
  Future<IncomeSource?> getById(int id) async =>
      sources.where((s) => s.id == id).firstOrNull;

  @override
  Future<int> create(IncomeSource source) async {
    final id = sources.length + 1;
    sources.add(source.copyWith(id: id));
    return id;
  }

  @override
  Future<void> update(IncomeSource source) async {
    sources.removeWhere((s) => s.id == source.id);
    sources.add(source);
  }

  @override
  Future<void> delete(int id) async {
    sources.removeWhere((s) => s.id == id);
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
    final incomeRepository = _FakeIncomeSourceRepository();
    final clock = FixedClock(DateTime.utc(2026, 7, 15));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
          incomeSourceRepositoryProvider.overrideWithValue(incomeRepository),
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
    expect(find.text('Which currency should we total everything in?'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Income step: name + amount are the only required fields (a single
    // payment is the default, so every other field already has a valid
    // default — see IncomeStepScreen doc).
    expect(find.text('Your income'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Main job');
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Income calculation step: single part -> only the payment day is
    // required.
    expect(find.text("How it's calculated"), findsOneWidget);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
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

    expect(incomeRepository.sources, hasLength(1));
    final source = incomeRepository.sources.single;
    expect(source.name, 'Main job');
    expect(source.nominalAmount, Money(Decimal.fromInt(5000), CurrencyCode('USD')));
    expect(source.scheduleRules, hasLength(1));
    expect(source.scheduleRules.single.paymentDay, 15);
  });
}
