import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/common_currencies.dart';
import '../../../core/money/currency_code.dart';
import '../../../core/money/money.dart';
import '../../../core/money/percentage.dart';
import '../../../domain/entities/living_expense_preference.dart';
import '../application/currency_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

enum _LifeExpenseMode { fixed, percent, range }

/// Onboarding step 4 (§3.3, §2.8 doc.md): an aggregate estimate of monthly
/// living expenses, never per-transaction. Optional — see
/// [OnboardingStepDefinition.isRequired] in onboardingStepsProvider.
class LifeExpensesStepScreen extends ConsumerStatefulWidget {
  const LifeExpensesStepScreen({super.key});

  @override
  ConsumerState<LifeExpensesStepScreen> createState() => _LifeExpensesStepScreenState();
}

class _LifeExpensesStepScreenState extends ConsumerState<LifeExpensesStepScreen> {
  _LifeExpenseMode _mode = _LifeExpenseMode.fixed;
  final _fixedController = TextEditingController();
  final _percentController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.lifeExpenses]
            as LivingExpensePreference?;
    switch (existing) {
      case FixedLivingExpense(:final amount):
        _mode = _LifeExpenseMode.fixed;
        _fixedController.text = amount.amount.toString();
      case PercentLivingExpense(:final percentage):
        _mode = _LifeExpenseMode.percent;
        _percentController.text = percentage.value.toString();
      case RangeLivingExpense(:final min, :final max):
        _mode = _LifeExpenseMode.range;
        _minController.text = min.amount.toString();
        _maxController.text = max.amount.toString();
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _fixedController.dispose();
    _percentController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  CurrencyCode get _primaryCurrency {
    final currencyStep =
        ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.currency]
            as CurrencyStepData?;
    return currencyStep?.primary ?? commonCurrencyCodes.first;
  }

  void _apply() {
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final currency = _primaryCurrency;

    switch (_mode) {
      case _LifeExpenseMode.fixed:
        final amount = Decimal.tryParse(_fixedController.text);
        if (amount == null) {
          notifier.setStepData(OnboardingStepIds.lifeExpenses, null, completed: false);
          return;
        }
        notifier.setStepData(
          OnboardingStepIds.lifeExpenses,
          LivingExpensePreference.fixed(amount: Money(amount, currency)),
          completed: true,
        );
      case _LifeExpenseMode.percent:
        final percent = Decimal.tryParse(_percentController.text);
        if (percent == null) {
          notifier.setStepData(OnboardingStepIds.lifeExpenses, null, completed: false);
          return;
        }
        notifier.setStepData(
          OnboardingStepIds.lifeExpenses,
          LivingExpensePreference.percentOfIncome(percentage: Percentage(percent)),
          completed: true,
        );
      case _LifeExpenseMode.range:
        final min = Decimal.tryParse(_minController.text);
        final max = Decimal.tryParse(_maxController.text);
        if (min == null || max == null) {
          notifier.setStepData(OnboardingStepIds.lifeExpenses, null, completed: false);
          return;
        }
        notifier.setStepData(
          OnboardingStepIds.lifeExpenses,
          LivingExpensePreference.range(min: Money(min, currency), max: Money(max, currency)),
          completed: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingLifeExpensesTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          SegmentedButton<_LifeExpenseMode>(
            segments: [
              ButtonSegment(value: _LifeExpenseMode.fixed, label: Text(l10n.onboardingLifeModeFixed)),
              ButtonSegment(
                value: _LifeExpenseMode.percent,
                label: Text(l10n.onboardingLifeModePercent),
              ),
              ButtonSegment(value: _LifeExpenseMode.range, label: Text(l10n.onboardingLifeModeRange)),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
              _apply();
            },
          ),
          const SizedBox(height: 24),
          switch (_mode) {
            _LifeExpenseMode.fixed => TextField(
              controller: _fixedController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.onboardingLifeFixedAmountLabel),
              onChanged: (_) => _apply(),
            ),
            _LifeExpenseMode.percent => TextField(
              controller: _percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.onboardingLifePercentLabel),
              onChanged: (_) => _apply(),
            ),
            _LifeExpenseMode.range => Column(
              children: [
                TextField(
                  controller: _minController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.onboardingLifeRangeMinLabel),
                  onChanged: (_) => _apply(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.onboardingLifeRangeMaxLabel),
                  onChanged: (_) => _apply(),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}
