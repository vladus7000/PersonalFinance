import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';
import 'package:personal_finance_assistant/data/repositories/drift_user_profile_repository.dart';
import 'package:personal_finance_assistant/domain/entities/user_profile.dart';

void main() {
  final usd = CurrencyCode('USD');
  final uah = CurrencyCode('UAH');

  late AppDatabase db;
  late DriftUserProfileRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftUserProfileRepository(db);
  });

  tearDown(() => db.close());

  UserProfile buildProfile({bool onboardingCompleted = false}) => UserProfile(
    displayName: 'Vlad',
    countryCode: 'UA',
    timezone: 'Europe/Kyiv',
    primaryCurrency: usd,
    additionalCurrencies: [uah],
    locale: 'ru',
    dateFormat: 'dd.MM.yyyy',
    numberFormat: '#,##0.00',
    financialMonthStartDay: 1,
    onboardingCompleted: onboardingCompleted,
    familyModeEnabled: false,
    biometricLockEnabled: false,
    hideBalancesEnabled: false,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  test('getProfile returns null before any profile is saved (first launch)', () async {
    expect(await repository.getProfile(), isNull);
  });

  test('saveProfile then getProfile round-trips every field exactly', () async {
    final profile = buildProfile();

    await repository.saveProfile(profile);
    final loaded = await repository.getProfile();

    expect(loaded, profile);
  });

  test('saveProfile on an existing profile updates it in place (singleton row)', () async {
    await repository.saveProfile(buildProfile(onboardingCompleted: false));
    await repository.saveProfile(buildProfile(onboardingCompleted: true));

    final loaded = await repository.getProfile();

    expect(loaded?.onboardingCompleted, isTrue);
    final rowCount = await db.select(db.userProfiles).get();
    expect(rowCount, hasLength(1));
  });

  test('additionalCurrencies round-trips an empty list', () async {
    final profile = buildProfile().copyWith(additionalCurrencies: []);

    await repository.saveProfile(profile);
    final loaded = await repository.getProfile();

    expect(loaded?.additionalCurrencies, isEmpty);
  });

  test('nullable householdId round-trips both null and a real value', () async {
    await repository.saveProfile(buildProfile());
    expect((await repository.getProfile())?.householdId, isNull);

    await repository.saveProfile(buildProfile().copyWith(householdId: 'household-1'));
    expect((await repository.getProfile())?.householdId, 'household-1');
  });
}
