import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/money/percentage.dart';
import '../../../domain/entities/deduction_rule.dart';
import '../../../domain/entities/income_calculation_mode.dart';
import '../../../domain/entities/payment_part_amount.dart';
import '../../../domain/entities/weekend_shift_rule.dart';
import '../application/income_calculation_step_data.dart';
import '../application/income_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

enum _AmountMode { percentage, fixed }

enum _DeductionMode { none, fixed, percentage }

class _PartFormState {
  final dayController = TextEditingController();
  WeekendShiftRule weekendShiftRule = WeekendShiftRule.none;
  _AmountMode amountMode = _AmountMode.percentage;
  final percentageController = TextEditingController();
  final fixedController = TextEditingController();

  void dispose() {
    dayController.dispose();
    percentageController.dispose();
    fixedController.dispose();
  }
}

/// Onboarding step 3 (doc.md §3.3): [IncomeCalculationStepData] — how many
/// parts to render is fixed by [IncomeStepData.payoutsPerMonth] (set in the
/// previous step). A single-part source skips asking for that part's
/// amount at all — it is implicitly the full nominal amount.
class IncomeCalculationStepScreen extends ConsumerStatefulWidget {
  const IncomeCalculationStepScreen({super.key});

  @override
  ConsumerState<IncomeCalculationStepScreen> createState() =>
      _IncomeCalculationStepScreenState();
}

class _IncomeCalculationStepScreenState extends ConsumerState<IncomeCalculationStepScreen> {
  IncomeCalculationMode _mode = IncomeCalculationMode.fixed;
  late final List<_PartFormState> _parts;
  _DeductionMode _deductionMode = _DeductionMode.none;
  final _deductionAmountController = TextEditingController();
  final _deductionPercentController = TextEditingController();

  IncomeStepData? get _incomeData =>
      ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.income]
          as IncomeStepData?;

  @override
  void initState() {
    super.initState();
    final payoutsPerMonth = _incomeData?.payoutsPerMonth ?? 1;
    _parts = List.generate(payoutsPerMonth, (_) => _PartFormState());

    final existing =
        ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.incomeCalculation]
            as IncomeCalculationStepData?;
    if (existing == null) return;

    _mode = existing.calculationMode;
    switch (existing.deductionRule) {
      case NoDeduction():
        _deductionMode = _DeductionMode.none;
      case FixedDeduction(:final amount):
        _deductionMode = _DeductionMode.fixed;
        _deductionAmountController.text = amount.amount.toString();
      case PercentageDeduction(:final percentage):
        _deductionMode = _DeductionMode.percentage;
        _deductionPercentController.text = percentage.value.toString();
    }
    for (var i = 0; i < _parts.length && i < existing.parts.length; i++) {
      final part = existing.parts[i];
      _parts[i].dayController.text = part.paymentDay.toString();
      _parts[i].weekendShiftRule = part.weekendShiftRule;
      switch (part.amount) {
        case PercentagePaymentPart(:final percentage):
          _parts[i].amountMode = _AmountMode.percentage;
          _parts[i].percentageController.text = percentage.value.toString();
        case FixedPaymentPart(:final amount):
          _parts[i].amountMode = _AmountMode.fixed;
          _parts[i].fixedController.text = amount.amount.toString();
      }
    }
  }

  @override
  void dispose() {
    for (final part in _parts) {
      part.dispose();
    }
    _deductionAmountController.dispose();
    _deductionPercentController.dispose();
    super.dispose();
  }

  void _markIncomplete() {
    ref
        .read(onboardingControllerProvider.notifier)
        .setStepData(OnboardingStepIds.incomeCalculation, null, completed: false);
  }

  void _apply() {
    final incomeData = _incomeData;
    if (incomeData == null) return _markIncomplete();

    final parts = <IncomePartInput>[];
    for (final part in _parts) {
      final day = int.tryParse(part.dayController.text);
      if (day == null || day < 1 || day > 31) return _markIncomplete();

      final PaymentPartAmount amount;
      if (_parts.length == 1) {
        amount = PaymentPartAmount.fixed(amount: incomeData.nominalAmount);
      } else if (part.amountMode == _AmountMode.percentage) {
        final percentage = Decimal.tryParse(part.percentageController.text);
        if (percentage == null) return _markIncomplete();
        amount = PaymentPartAmount.percentage(percentage: Percentage(percentage));
      } else {
        final value = Decimal.tryParse(part.fixedController.text);
        if (value == null) return _markIncomplete();
        amount = PaymentPartAmount.fixed(
          amount: Money(value, incomeData.nominalAmount.currency),
        );
      }
      parts.add(
        IncomePartInput(paymentDay: day, weekendShiftRule: part.weekendShiftRule, amount: amount),
      );
    }

    final DeductionRule deductionRule;
    switch (_deductionMode) {
      case _DeductionMode.none:
        deductionRule = const DeductionRule.none();
      case _DeductionMode.fixed:
        final value = Decimal.tryParse(_deductionAmountController.text);
        if (value == null) return _markIncomplete();
        deductionRule = DeductionRule.fixedAmount(
          amount: Money(value, incomeData.nominalAmount.currency),
        );
      case _DeductionMode.percentage:
        final percentage = Decimal.tryParse(_deductionPercentController.text);
        if (percentage == null) return _markIncomplete();
        deductionRule = DeductionRule.percentage(percentage: Percentage(percentage));
    }

    ref
        .read(onboardingControllerProvider.notifier)
        .setStepData(
          OnboardingStepIds.incomeCalculation,
          IncomeCalculationStepData(
            calculationMode: _mode,
            parts: parts,
            deductionRule: deductionRule,
          ),
          completed: true,
        );
  }

  String _weekendShiftLabel(AppLocalizations l10n, WeekendShiftRule rule) => switch (rule) {
    WeekendShiftRule.none => l10n.weekendShiftRuleNone,
    WeekendShiftRule.moveToPreviousBusinessDay => l10n.weekendShiftRuleMoveToPreviousBusinessDay,
    WeekendShiftRule.moveToNextBusinessDay => l10n.weekendShiftRuleMoveToNextBusinessDay,
  };

  Widget _buildPart(BuildContext context, AppLocalizations l10n, int index) {
    final part = _parts[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_parts.length > 1)
            Text(
              l10n.onboardingIncomePartTitle(index + 1),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: part.dayController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.onboardingIncomePartPaymentDayLabel),
                  onChanged: (_) => setState(_apply),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DropdownButton<WeekendShiftRule>(
                  value: part.weekendShiftRule,
                  isExpanded: true,
                  items: [
                    for (final rule in WeekendShiftRule.values)
                      DropdownMenuItem(value: rule, child: Text(_weekendShiftLabel(l10n, rule))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      part.weekendShiftRule = value;
                      _apply();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_parts.length > 1) ...[
            const SizedBox(height: 8),
            SegmentedButton<_AmountMode>(
              segments: [
                ButtonSegment(
                  value: _AmountMode.percentage,
                  label: Text(l10n.paymentPartAmountModePercentage),
                ),
                ButtonSegment(
                  value: _AmountMode.fixed,
                  label: Text(l10n.paymentPartAmountModeFixed),
                ),
              ],
              selected: {part.amountMode},
              onSelectionChanged: (selection) {
                setState(() {
                  part.amountMode = selection.first;
                  _apply();
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: part.amountMode == _AmountMode.percentage
                  ? part.percentageController
                  : part.fixedController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: part.amountMode == _AmountMode.percentage
                    ? l10n.onboardingIncomePartPercentageLabel
                    : l10n.onboardingIncomePartFixedAmountLabel,
              ),
              onChanged: (_) => setState(_apply),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingIncomeCalculationTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          SegmentedButton<IncomeCalculationMode>(
            segments: [
              ButtonSegment(
                value: IncomeCalculationMode.fixed,
                label: Text(l10n.onboardingIncomeCalculationModeFixed),
              ),
              ButtonSegment(
                value: IncomeCalculationMode.byWorkingDays,
                label: Text(l10n.onboardingIncomeCalculationModeByWorkingDays),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() {
                _mode = selection.first;
                _apply();
              });
            },
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _parts.length; i++) _buildPart(context, l10n, i),
          Text(l10n.onboardingIncomeDeductionLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<_DeductionMode>(
            segments: [
              ButtonSegment(value: _DeductionMode.none, label: Text(l10n.deductionRuleModeNone)),
              ButtonSegment(value: _DeductionMode.fixed, label: Text(l10n.deductionRuleModeFixed)),
              ButtonSegment(
                value: _DeductionMode.percentage,
                label: Text(l10n.deductionRuleModePercentage),
              ),
            ],
            selected: {_deductionMode},
            onSelectionChanged: (selection) {
              setState(() {
                _deductionMode = selection.first;
                _apply();
              });
            },
          ),
          if (_deductionMode == _DeductionMode.fixed) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _deductionAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.onboardingIncomeDeductionAmountLabel),
              onChanged: (_) => setState(_apply),
            ),
          ],
          if (_deductionMode == _DeductionMode.percentage) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _deductionPercentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.onboardingIncomeDeductionPercentageLabel),
              onChanged: (_) => setState(_apply),
            ),
          ],
        ],
      ),
    );
  }
}
