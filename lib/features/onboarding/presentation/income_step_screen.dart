import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/common_currencies.dart';
import '../../../core/money/currency_code.dart';
import '../../../core/money/money.dart';
import '../../../domain/entities/income_type.dart';
import '../application/currency_step_data.dart';
import '../application/income_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

/// Onboarding step 2 (doc.md §3.3): name, type, contract amount/currency,
/// payout currency, and how many parts the payment is split into (bounds
/// the next step, [OnboardingStepIds.incomeCalculation], to the MVP
/// scenarios — see [IncomeStepData] doc).
class IncomeStepScreen extends ConsumerStatefulWidget {
  const IncomeStepScreen({super.key});

  @override
  ConsumerState<IncomeStepScreen> createState() => _IncomeStepScreenState();
}

class _IncomeStepScreenState extends ConsumerState<IncomeStepScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  IncomeType _type = IncomeType.salary;
  CurrencyCode _contractCurrency = commonCurrencyCodes.first;
  CurrencyCode? _payoutCurrency;
  int _payoutsPerMonth = 1;

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.income]
            as IncomeStepData?;
    if (existing != null) {
      _nameController.text = existing.name;
      _amountController.text = existing.nominalAmount.amount.toString();
      _type = existing.type;
      _contractCurrency = existing.nominalAmount.currency;
      _payoutCurrency = existing.payoutCurrency;
      _payoutsPerMonth = existing.payoutsPerMonth;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  CurrencyCode get _defaultPayoutCurrency {
    final currencyData =
        ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.currency]
            as CurrencyStepData?;
    return currencyData?.primary ?? commonCurrencyCodes.first;
  }

  void _apply() {
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final amount = Decimal.tryParse(_amountController.text);
    final name = _nameController.text.trim();

    if (amount == null || amount.sign <= 0 || name.isEmpty) {
      notifier.setStepData(OnboardingStepIds.income, null, completed: false);
      return;
    }

    notifier.setStepData(
      OnboardingStepIds.income,
      IncomeStepData(
        name: name,
        type: _type,
        nominalAmount: Money(amount, _contractCurrency),
        payoutCurrency: _payoutCurrency ?? _defaultPayoutCurrency,
        payoutsPerMonth: _payoutsPerMonth,
      ),
      completed: true,
    );
  }

  String _typeLabel(AppLocalizations l10n, IncomeType type) => switch (type) {
    IncomeType.salary => l10n.incomeTypeSalary,
    IncomeType.freelance => l10n.incomeTypeFreelance,
    IncomeType.business => l10n.incomeTypeBusiness,
    IncomeType.rental => l10n.incomeTypeRental,
    IncomeType.dividend => l10n.incomeTypeDividend,
    IncomeType.other => l10n.incomeTypeOther,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payoutCurrency = _payoutCurrency ?? _defaultPayoutCurrency;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingIncomeTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.onboardingIncomeNameLabel,
              hintText: l10n.onboardingIncomeNameHint,
            ),
            onChanged: (_) => setState(_apply),
          ),
          const SizedBox(height: 16),
          Text(l10n.onboardingIncomeTypeLabel, style: Theme.of(context).textTheme.labelLarge),
          DropdownButton<IncomeType>(
            value: _type,
            isExpanded: true,
            items: [
              for (final type in IncomeType.values)
                DropdownMenuItem(value: type, child: Text(_typeLabel(l10n, type))),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _type = value;
                _apply();
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.onboardingIncomeAmountLabel),
                  onChanged: (_) => setState(_apply),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<CurrencyCode>(
                value: _contractCurrency,
                items: [
                  for (final currency in commonCurrencyCodes)
                    DropdownMenuItem(value: currency, child: Text(currency.value)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _contractCurrency = value;
                    _apply();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingIncomePayoutCurrencyLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          DropdownButton<CurrencyCode>(
            value: payoutCurrency,
            isExpanded: true,
            items: [
              for (final currency in commonCurrencyCodes)
                DropdownMenuItem(value: currency, child: Text(currency.value)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _payoutCurrency = value;
                _apply();
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingIncomePayoutsPerMonthLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 1, label: Text(l10n.onboardingIncomePayoutsPerMonthOnce)),
              ButtonSegment(value: 2, label: Text(l10n.onboardingIncomePayoutsPerMonthTwice)),
            ],
            selected: {_payoutsPerMonth},
            onSelectionChanged: (selection) {
              setState(() {
                _payoutsPerMonth = selection.first;
                _apply();
              });
            },
          ),
        ],
      ),
    );
  }
}
