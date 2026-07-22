import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_assistant/core/money/currency_code.dart';
import 'package:personal_finance_assistant/core/money/money.dart';
import 'package:personal_finance_assistant/core/money/percentage.dart';
import 'package:personal_finance_assistant/data/db/app_database.dart';
import 'package:personal_finance_assistant/data/repositories/drift_income_source_repository.dart';
import 'package:personal_finance_assistant/domain/entities/deduction_rule.dart';
import 'package:personal_finance_assistant/domain/entities/income_schedule_rule.dart';
import 'package:personal_finance_assistant/domain/entities/income_source.dart';
import 'package:personal_finance_assistant/domain/entities/income_type.dart';
import 'package:personal_finance_assistant/domain/entities/payment_part_amount.dart';
import 'package:personal_finance_assistant/domain/entities/weekend_shift_rule.dart';

void main() {
  final usd = CurrencyCode('USD');
  final uah = CurrencyCode('UAH');

  late AppDatabase db;
  late DriftIncomeSourceRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftIncomeSourceRepository(db);
  });

  tearDown(() => db.close());

  // Advance (50%, day 15) + main payment (the rest, fixed amount, day 30) —
  // covers the §2.3 "две части (%/фикс)" scenario the DoD requires.
  IncomeSource buildSource({String name = 'Main job'}) => IncomeSource(
    name: name,
    type: IncomeType.salary,
    nominalAmount: Money(Decimal.fromInt(5500), usd),
    payoutCurrency: uah,
    deductionRule: const DeductionRule.none(),
    startDate: DateTime.utc(2026, 1, 1),
    isActive: true,
    scheduleRules: [
      IncomeScheduleRule(
        partIndex: 0,
        coverageStartDay: 1,
        coverageEndDay: 15,
        paymentDay: 15,
        amount: PaymentPartAmount.percentage(percentage: Percentage(Decimal.fromInt(50))),
        weekendShiftRule: WeekendShiftRule.moveToPreviousBusinessDay,
        isActive: true,
      ),
      IncomeScheduleRule(
        partIndex: 1,
        coverageStartDay: 16,
        coverageEndDay: 30,
        paymentDay: 30,
        amount: PaymentPartAmount.fixed(amount: Money(Decimal.fromInt(2750), usd)),
        weekendShiftRule: WeekendShiftRule.moveToNextBusinessDay,
        paymentMonthOffset: 1,
        rateFixingDay: 1,
        isActive: true,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  IncomeSource stripIds(IncomeSource source) => source.copyWith(
    id: null,
    scheduleRules: [for (final rule in source.scheduleRules) rule.copyWith(id: null)],
  );

  test('getAll returns nothing before any source is created', () async {
    expect(await repository.getAll(), isEmpty);
  });

  test('create then getById round-trips a source with two payment parts', () async {
    final id = await repository.create(buildSource());
    final loaded = await repository.getById(id);

    expect(loaded, isNotNull);
    expect(loaded!.id, id);
    expect(stripIds(loaded), stripIds(buildSource()));
    // Schedule rules get their own generated ids too, and stay ordered by
    // partIndex regardless of insertion order.
    expect(loaded.scheduleRules.map((r) => r.id), everyElement(isNotNull));
    expect(loaded.scheduleRules.map((r) => r.partIndex), [0, 1]);
  });

  test('getAll lists every created source', () async {
    await repository.create(buildSource(name: 'Main job'));
    await repository.create(buildSource(name: 'Freelance'));

    final all = await repository.getAll();

    expect(all.map((s) => s.name), containsAll(['Main job', 'Freelance']));
  });

  test('update replaces both the source fields and its schedule rules', () async {
    final id = await repository.create(buildSource());
    final loaded = (await repository.getById(id))!;

    await repository.update(
      loaded.copyWith(
        name: 'Renamed job',
        scheduleRules: [
          IncomeScheduleRule(
            partIndex: 0,
            coverageStartDay: 1,
            coverageEndDay: 31,
            paymentDay: 20,
            amount: PaymentPartAmount.fixed(amount: Money(Decimal.fromInt(5500), usd)),
            weekendShiftRule: WeekendShiftRule.none,
            isActive: true,
          ),
        ],
      ),
    );
    final updated = await repository.getById(id);

    expect(updated?.name, 'Renamed job');
    expect(updated?.scheduleRules, hasLength(1));
    expect(updated?.scheduleRules.single.paymentDay, 20);
  });

  test('delete removes the source and its schedule rules', () async {
    final id = await repository.create(buildSource());

    await repository.delete(id);

    expect(await repository.getById(id), isNull);
    final orphanedRules = await (db.select(
      db.incomeScheduleRules,
    )..where((t) => t.incomeSourceId.equals(id))).get();
    expect(orphanedRules, isEmpty);
  });

  test('a fixed deduction rule round-trips in the contract currency', () async {
    final source = buildSource().copyWith(
      deductionRule: DeductionRule.fixedAmount(amount: Money(Decimal.fromInt(200), usd)),
    );
    final id = await repository.create(source);

    final loaded = await repository.getById(id);

    expect(loaded?.deductionRule, DeductionRule.fixedAmount(amount: Money(Decimal.fromInt(200), usd)));
  });

  test('a percentage deduction rule round-trips exactly', () async {
    final source = buildSource().copyWith(
      deductionRule: DeductionRule.percentage(percentage: Percentage(Decimal.fromInt(18))),
    );
    final id = await repository.create(source);

    final loaded = await repository.getById(id);

    expect(loaded?.deductionRule, DeductionRule.percentage(percentage: Percentage(Decimal.fromInt(18))));
  });
}
