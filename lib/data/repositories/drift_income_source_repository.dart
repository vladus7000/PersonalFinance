import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../core/money/currency_code.dart';
import '../../core/money/money.dart';
import '../../core/money/percentage.dart';
import '../../domain/entities/deduction_rule.dart';
import '../../domain/entities/income_calculation_mode.dart';
import '../../domain/entities/income_schedule_rule.dart';
import '../../domain/entities/income_source.dart';
import '../../domain/entities/income_type.dart';
import '../../domain/entities/payment_part_amount.dart';
import '../../domain/entities/weekend_shift_rule.dart';
import '../../domain/repositories/income_source_repository.dart';
import '../db/app_database.dart';

/// Reads/writes the [IncomeSource] aggregate (source row + its schedule
/// rule rows) as a unit — see [IncomeSource] doc on why they're not
/// persisted independently.
class DriftIncomeSourceRepository implements IncomeSourceRepository {
  const DriftIncomeSourceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<IncomeSource>> getAll() async {
    final rows = await _db.select(_db.incomeSources).get();
    return Future.wait(rows.map(_toDomain));
  }

  @override
  Future<IncomeSource?> getById(int id) async {
    final row = await (_db.select(
      _db.incomeSources,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> create(IncomeSource source) {
    return _db.transaction(() async {
      final id = await _db.into(_db.incomeSources).insert(_toCompanion(source));
      await _insertScheduleRules(id, source.scheduleRules);
      return id;
    });
  }

  @override
  Future<void> update(IncomeSource source) {
    final id = source.id;
    if (id == null) {
      throw ArgumentError('Cannot update an IncomeSource without an id');
    }
    return _db.transaction(() async {
      await (_db.update(
        _db.incomeSources,
      )..where((t) => t.id.equals(id))).write(_toCompanion(source));
      await (_db.delete(
        _db.incomeScheduleRules,
      )..where((t) => t.incomeSourceId.equals(id))).go();
      await _insertScheduleRules(id, source.scheduleRules);
    });
  }

  @override
  Future<void> delete(int id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.incomeScheduleRules,
      )..where((t) => t.incomeSourceId.equals(id))).go();
      await (_db.delete(_db.incomeSources)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> _insertScheduleRules(int incomeSourceId, List<IncomeScheduleRule> rules) async {
    for (final rule in rules) {
      await _db
          .into(_db.incomeScheduleRules)
          .insert(_ruleToCompanion(incomeSourceId, rule));
    }
  }

  Future<IncomeSource> _toDomain(IncomeSourceRow row) async {
    final ruleRows =
        await (_db.select(_db.incomeScheduleRules)
              ..where((t) => t.incomeSourceId.equals(row.id))
              ..orderBy([(t) => OrderingTerm.asc(t.partIndex)]))
            .get();

    return IncomeSource(
      id: row.id,
      name: row.name,
      type: IncomeType.values.byName(row.type),
      nominalAmount: Money(Decimal.parse(row.nominalAmount), CurrencyCode(row.contractCurrency)),
      payoutCurrency: CurrencyCode(row.payoutCurrency),
      calculationMode: IncomeCalculationMode.values.byName(row.calculationMode),
      deductionRule: _deductionRuleFrom(row),
      targetAccountId: row.targetAccountId,
      // Drift does not preserve DateTime.isUtc through storage — see
      // BUILD_PLAN.md §0.4. Must normalize on every read.
      startDate: row.startDate.toUtc(),
      endDate: row.endDate?.toUtc(),
      isActive: row.isActive,
      notes: row.notes,
      scheduleRules: ruleRows.map((r) => _ruleFromRow(r, row.contractCurrency)).toList(),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  DeductionRule _deductionRuleFrom(IncomeSourceRow row) {
    return switch (row.deductionType) {
      'fixedAmount' => DeductionRule.fixedAmount(
        amount: Money(Decimal.parse(row.deductionAmount!), CurrencyCode(row.contractCurrency)),
      ),
      'percentage' => DeductionRule.percentage(
        percentage: Percentage(Decimal.parse(row.deductionPercentage!)),
      ),
      _ => const DeductionRule.none(),
    };
  }

  IncomeScheduleRule _ruleFromRow(IncomeScheduleRuleRow row, String contractCurrency) {
    return IncomeScheduleRule(
      id: row.id,
      partIndex: row.partIndex,
      coverageStartDay: row.coverageStartDay,
      coverageEndDay: row.coverageEndDay,
      paymentDay: row.paymentDay,
      paymentMonthOffset: row.paymentMonthOffset,
      amount: switch (row.amountType) {
        'percentage' => PaymentPartAmount.percentage(
          percentage: Percentage(Decimal.parse(row.amountPercentage!)),
        ),
        'fixed' => PaymentPartAmount.fixed(
          amount: Money(Decimal.parse(row.amountFixedValue!), CurrencyCode(contractCurrency)),
        ),
        _ => null,
      },
      weekendShiftRule: WeekendShiftRule.values.byName(row.weekendShiftRule),
      rateFixingDay: row.rateFixingDay,
      isActive: row.isActive,
    );
  }

  IncomeSourcesCompanion _toCompanion(IncomeSource source) {
    final deduction = source.deductionRule;
    return IncomeSourcesCompanion.insert(
      name: source.name,
      type: source.type.name,
      nominalAmount: source.nominalAmount.amount.toString(),
      contractCurrency: source.nominalAmount.currency.value,
      payoutCurrency: source.payoutCurrency.value,
      calculationMode: source.calculationMode.name,
      deductionType: Value(switch (deduction) {
        NoDeduction() => 'none',
        FixedDeduction() => 'fixedAmount',
        PercentageDeduction() => 'percentage',
      }),
      deductionAmount: Value(switch (deduction) {
        FixedDeduction(:final amount) => amount.amount.toString(),
        _ => null,
      }),
      deductionPercentage: Value(switch (deduction) {
        PercentageDeduction(:final percentage) => percentage.value.toString(),
        _ => null,
      }),
      targetAccountId: Value(source.targetAccountId),
      // .toUtc() on write too: defensive against a caller passing a
      // local-zone DateTime — see BUILD_PLAN.md §0.4.
      startDate: source.startDate.toUtc(),
      endDate: Value(source.endDate?.toUtc()),
      isActive: Value(source.isActive),
      notes: Value(source.notes),
      createdAt: source.createdAt.toUtc(),
      updatedAt: source.updatedAt.toUtc(),
    );
  }

  IncomeScheduleRulesCompanion _ruleToCompanion(int incomeSourceId, IncomeScheduleRule rule) {
    final amount = rule.amount;
    return IncomeScheduleRulesCompanion.insert(
      incomeSourceId: incomeSourceId,
      partIndex: rule.partIndex,
      coverageStartDay: rule.coverageStartDay,
      coverageEndDay: rule.coverageEndDay,
      paymentDay: rule.paymentDay,
      paymentMonthOffset: Value(rule.paymentMonthOffset),
      amountType: Value(switch (amount) {
        PercentagePaymentPart() => 'percentage',
        FixedPaymentPart() => 'fixed',
        null => null,
      }),
      amountPercentage: Value(switch (amount) {
        PercentagePaymentPart(:final percentage) => percentage.value.toString(),
        _ => null,
      }),
      amountFixedValue: Value(switch (amount) {
        FixedPaymentPart(:final amount) => amount.amount.toString(),
        _ => null,
      }),
      weekendShiftRule: rule.weekendShiftRule.name,
      rateFixingDay: Value(rule.rateFixingDay),
      isActive: Value(rule.isActive),
    );
  }
}
