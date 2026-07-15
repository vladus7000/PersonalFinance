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

enum _RateFixingMode { onPaymentDate, specificDay }

class _PartFormState {
  final dayController = TextEditingController();
  WeekendShiftRule weekendShiftRule = WeekendShiftRule.none;
  int paymentMonthOffset = 0;
  final coverageStartController = TextEditingController();
  final coverageEndController = TextEditingController();

  void dispose() {
    dayController.dispose();
    coverageStartController.dispose();
    coverageEndController.dispose();
  }
}

/// Onboarding step 3 (doc.md §3.3, §8.18): [IncomeCalculationStepData] — how
/// many parts to render is fixed by [IncomeStepData.payoutsPerMonth] (set
/// in the previous step).
///
/// `calculationMode` selects between two entirely different "mechanics"
/// (see `SalaryCalculator` doc): `fixed` splits the nominal amount between
/// parts by percentage/fixed value, independent of attendance — a
/// single-part source implies the full amount, so it never asks for a
/// value at all. `byWorkingDays` does NOT use a percentage/fixed split;
/// instead each part is paid for attendance within its own
/// [IncomePartInput.coverageStartDay]-`coverageEndDay` range (e.g. an
/// advance covering the 1st-15th, a main payment covering the 16th-30th),
/// so that range is asked for instead — the actual amount depends on
/// attendance and isn't known until the payment is confirmed later.
///
/// When the payout currency differs from the contract currency, an
/// optional, never-persisted "preview rate" lets the user see roughly how
/// much a `fixed`-mode part converts to.
class IncomeCalculationStepScreen extends ConsumerStatefulWidget {
  const IncomeCalculationStepScreen({super.key});

  @override
  ConsumerState<IncomeCalculationStepScreen> createState() =>
      _IncomeCalculationStepScreenState();
}

class _IncomeCalculationStepScreenState extends ConsumerState<IncomeCalculationStepScreen> {
  IncomeCalculationMode _mode = IncomeCalculationMode.fixed;
  late final List<_PartFormState> _parts;
  _AmountMode _advanceAmountMode = _AmountMode.percentage;
  final _advancePercentageController = TextEditingController();
  final _advanceFixedController = TextEditingController();
  _RateFixingMode _rateFixingMode = _RateFixingMode.onPaymentDate;
  final _rateFixingDayController = TextEditingController();
  final _previewRateController = TextEditingController();
  _DeductionMode _deductionMode = _DeductionMode.none;
  final _deductionAmountController = TextEditingController();
  final _deductionPercentController = TextEditingController();

  bool get _hasTwoParts => _parts.length == 2;

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
    if (existing.rateFixingDay != null) {
      _rateFixingMode = _RateFixingMode.specificDay;
      _rateFixingDayController.text = existing.rateFixingDay.toString();
    }
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
      final existingPart = existing.parts[i];
      _parts[i].dayController.text = existingPart.paymentDay.toString();
      _parts[i].weekendShiftRule = existingPart.weekendShiftRule;
      _parts[i].paymentMonthOffset = existingPart.paymentMonthOffset;
      _parts[i].coverageStartController.text = existingPart.coverageStartDay.toString();
      _parts[i].coverageEndController.text = existingPart.coverageEndDay.toString();
    }
    if (_hasTwoParts && existing.parts.isNotEmpty) {
      switch (existing.parts.first.amount) {
        case PercentagePaymentPart(:final percentage):
          _advanceAmountMode = _AmountMode.percentage;
          _advancePercentageController.text = percentage.value.toString();
        case FixedPaymentPart(:final amount):
          _advanceAmountMode = _AmountMode.fixed;
          _advanceFixedController.text = amount.amount.toString();
        case null:
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final part in _parts) {
      part.dispose();
    }
    _advancePercentageController.dispose();
    _advanceFixedController.dispose();
    _rateFixingDayController.dispose();
    _previewRateController.dispose();
    _deductionAmountController.dispose();
    _deductionPercentController.dispose();
    super.dispose();
  }

  void _markIncomplete() {
    ref
        .read(onboardingControllerProvider.notifier)
        .setStepData(OnboardingStepIds.incomeCalculation, null, completed: false);
  }

  /// The advance's amount, and (for a two-part source) the main payment's
  /// amount — always "the rest" of the nominal amount, so the two parts
  /// are guaranteed to add up. Only meaningful in `fixed` mode. Returns
  /// `null` if the advance amount hasn't been entered (or doesn't parse).
  (PaymentPartAmount advance, PaymentPartAmount? mainPayment)? _resolveFixedAmounts(
    Money nominalAmount,
  ) {
    if (!_hasTwoParts) return (PaymentPartAmount.fixed(amount: nominalAmount), null);

    if (_advanceAmountMode == _AmountMode.percentage) {
      final percentage = Decimal.tryParse(_advancePercentageController.text);
      if (percentage == null) return null;
      return (
        PaymentPartAmount.percentage(percentage: Percentage(percentage)),
        PaymentPartAmount.percentage(
          percentage: Percentage(Decimal.fromInt(100) - percentage),
        ),
      );
    }

    final value = Decimal.tryParse(_advanceFixedController.text);
    if (value == null) return null;
    return (
      PaymentPartAmount.fixed(amount: Money(value, nominalAmount.currency)),
      PaymentPartAmount.fixed(
        amount: Money(nominalAmount.amount - value, nominalAmount.currency),
      ),
    );
  }

  void _apply() {
    final incomeData = _incomeData;
    if (incomeData == null) return _markIncomplete();

    int? rateFixingDay;
    if (_rateFixingMode == _RateFixingMode.specificDay) {
      rateFixingDay = int.tryParse(_rateFixingDayController.text);
      if (rateFixingDay == null || rateFixingDay < 1 || rateFixingDay > 31) {
        return _markIncomplete();
      }
    }

    List<PaymentPartAmount?>? fixedAmounts;
    if (_mode == IncomeCalculationMode.fixed) {
      final resolved = _resolveFixedAmounts(incomeData.nominalAmount);
      if (resolved == null) return _markIncomplete();
      fixedAmounts = [resolved.$1, if (_hasTwoParts) resolved.$2];
    }

    final parts = <IncomePartInput>[];
    for (var i = 0; i < _parts.length; i++) {
      final part = _parts[i];
      final day = int.tryParse(part.dayController.text);
      if (day == null || day < 1 || day > 31) return _markIncomplete();

      var coverageStart = 1;
      var coverageEnd = 31;
      if (_hasTwoParts && _mode == IncomeCalculationMode.byWorkingDays) {
        final start = int.tryParse(part.coverageStartController.text);
        final end = int.tryParse(part.coverageEndController.text);
        if (start == null || start < 1 || start > 31) return _markIncomplete();
        if (end == null || end < 1 || end > 31 || end < start) return _markIncomplete();
        coverageStart = start;
        coverageEnd = end;
      }

      parts.add(
        IncomePartInput(
          coverageStartDay: coverageStart,
          coverageEndDay: coverageEnd,
          paymentDay: day,
          paymentMonthOffset: part.paymentMonthOffset,
          weekendShiftRule: part.weekendShiftRule,
          amount: _mode == IncomeCalculationMode.fixed ? fixedAmounts![i] : null,
        ),
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
            rateFixingDay: rateFixingDay,
          ),
          completed: true,
        );
  }

  String _weekendShiftLabel(AppLocalizations l10n, WeekendShiftRule rule) => switch (rule) {
    WeekendShiftRule.none => l10n.weekendShiftRuleNone,
    WeekendShiftRule.moveToPreviousBusinessDay => l10n.weekendShiftRuleMoveToPreviousBusinessDay,
    WeekendShiftRule.moveToNextBusinessDay => l10n.weekendShiftRuleMoveToNextBusinessDay,
  };

  String? _dayFieldError(AppLocalizations l10n, String text) {
    if (text.isEmpty) return l10n.onboardingIncomeFieldRequired;
    final day = int.tryParse(text);
    if (day == null || day < 1 || day > 31) return l10n.onboardingIncomeFieldInvalidDay;
    return null;
  }

  String? _numberFieldError(AppLocalizations l10n, String text) {
    if (text.isEmpty) return l10n.onboardingIncomeFieldRequired;
    if (Decimal.tryParse(text) == null) return l10n.onboardingIncomeFieldInvalidNumber;
    return null;
  }

  String? _coverageEndError(AppLocalizations l10n, String startText, String endText) {
    final dayError = _dayFieldError(l10n, endText);
    if (dayError != null) return dayError;
    final start = int.tryParse(startText);
    final end = int.tryParse(endText);
    if (start != null && end != null && end < start) {
      return l10n.onboardingIncomeCoverageRangeInvalid;
    }
    return null;
  }

  /// A human-readable preview of the main payment's auto-computed amount,
  /// e.g. "50%" or "2 750.00 USD" — shown read-only so the user can see
  /// what "the rest" resolves to instead of it being a black box.
  /// `fixed` mode only.
  String? _mainPaymentPreview(IncomeStepData incomeData) {
    final amounts = _resolveFixedAmounts(incomeData.nominalAmount);
    if (amounts == null) return null;
    return switch (amounts.$2) {
      PercentagePaymentPart(:final percentage) => '${percentage.value}%',
      FixedPaymentPart(:final amount) => amount.toCanonicalString(),
      null => null,
    };
  }

  /// A rough, never-persisted conversion of [amount] (in the contract
  /// currency) to the payout currency, using whatever the user typed into
  /// [_previewRateController] — `fixed` mode only (no proration/deduction
  /// applied), unlike the real forecast (E3.T4).
  Widget _buildAmountPreview(
    BuildContext context,
    AppLocalizations l10n,
    PaymentPartAmount amount,
    IncomeStepData incomeData,
  ) {
    final contractCurrency = incomeData.nominalAmount.currency;
    final payoutCurrency = incomeData.payoutCurrency;
    if (contractCurrency == payoutCurrency) return const SizedBox.shrink();

    final grossInContract = switch (amount) {
      FixedPaymentPart(:final amount) => amount,
      PercentagePaymentPart(:final percentage) => percentage.of(incomeData.nominalAmount),
    };
    final rate = Decimal.tryParse(_previewRateController.text);
    final text = rate == null
        ? l10n.onboardingIncomePartPreviewMissingRate(payoutCurrency.value)
        : l10n.onboardingIncomePartPreviewAmount(
            Money(grossInContract.amount * rate, payoutCurrency).toCanonicalString(),
          );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildPart(BuildContext context, AppLocalizations l10n, int index, IncomeStepData incomeData) {
    final part = _parts[index];
    final isAdvance = index == 0;
    final byWorkingDays = _mode == IncomeCalculationMode.byWorkingDays;
    final amounts = _mode == IncomeCalculationMode.fixed
        ? _resolveFixedAmounts(incomeData.nominalAmount)
        : null;
    final partAmount = amounts == null ? null : (isAdvance ? amounts.$1 : amounts.$2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasTwoParts)
            Text(
              isAdvance ? l10n.onboardingIncomePartAdvanceTitle : l10n.onboardingIncomePartMainTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: part.dayController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingIncomePartPaymentDayLabel,
                    errorText: _dayFieldError(l10n, part.dayController.text),
                  ),
                  onChanged: (_) => setState(_apply),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.onboardingIncomePartWeekendShiftLabel,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<WeekendShiftRule>(
                      value: part.weekendShiftRule,
                      isExpanded: true,
                      items: [
                        for (final rule in WeekendShiftRule.values)
                          DropdownMenuItem(
                            value: rule,
                            child: Text(_weekendShiftLabel(l10n, rule)),
                          ),
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
                ),
              ),
            ],
          ),
          Text(
            l10n.onboardingIncomePartWeekendShiftHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_hasTwoParts) ...[
            const SizedBox(height: 12),
            Text(
              l10n.onboardingIncomePartMonthLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.paymentMonthOffsetSameMonth)),
                ButtonSegment(value: 1, label: Text(l10n.paymentMonthOffsetNextMonth)),
              ],
              selected: {part.paymentMonthOffset},
              onSelectionChanged: (selection) {
                setState(() {
                  part.paymentMonthOffset = selection.first;
                  _apply();
                });
              },
            ),
            Text(
              l10n.onboardingIncomePartMonthHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_hasTwoParts && byWorkingDays) ...[
            const SizedBox(height: 12),
            Text(
              l10n.onboardingIncomePartCoverageLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: part.coverageStartController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.onboardingIncomePartCoverageFromLabel,
                      errorText: _dayFieldError(l10n, part.coverageStartController.text),
                    ),
                    onChanged: (_) => setState(_apply),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: part.coverageEndController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.onboardingIncomePartCoverageToLabel,
                      errorText: _coverageEndError(
                        l10n,
                        part.coverageStartController.text,
                        part.coverageEndController.text,
                      ),
                    ),
                    onChanged: (_) => setState(_apply),
                  ),
                ),
              ],
            ),
            Text(
              l10n.onboardingIncomePartCoverageHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!byWorkingDays) ...[
            if (_hasTwoParts && isAdvance) ...[
              const SizedBox(height: 12),
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
                selected: {_advanceAmountMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _advanceAmountMode = selection.first;
                    _apply();
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _advanceAmountMode == _AmountMode.percentage
                    ? _advancePercentageController
                    : _advanceFixedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _advanceAmountMode == _AmountMode.percentage
                      ? l10n.onboardingIncomePartPercentageLabel
                      : l10n.onboardingIncomePartFixedAmountLabel,
                  errorText: _numberFieldError(
                    l10n,
                    _advanceAmountMode == _AmountMode.percentage
                        ? _advancePercentageController.text
                        : _advanceFixedController.text,
                  ),
                ),
                onChanged: (_) => setState(_apply),
              ),
            ],
            if (_hasTwoParts && !isAdvance) ...[
              const SizedBox(height: 12),
              Text(
                l10n.onboardingIncomeMainPaymentAuto(_mainPaymentPreview(incomeData) ?? '—'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (partAmount != null) _buildAmountPreview(context, l10n, partAmount, incomeData),
          ] else if (_hasTwoParts) ...[
            const SizedBox(height: 12),
            Text(
              l10n.onboardingIncomePartAmountDependsOnAttendance,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final incomeData = _incomeData;
    final needsPreviewRate =
        _mode == IncomeCalculationMode.fixed &&
        incomeData != null &&
        incomeData.nominalAmount.currency != incomeData.payoutCurrency;

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
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _mode == IncomeCalculationMode.fixed
                  ? l10n.onboardingIncomeCalculationModeFixedHint
                  : l10n.onboardingIncomeCalculationModeByWorkingDaysHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_hasTwoParts) ...[
            const SizedBox(height: 24),
            Text(
              l10n.onboardingIncomeRateFixingLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              l10n.onboardingIncomeRateFixingHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<_RateFixingMode>(
              segments: [
                ButtonSegment(
                  value: _RateFixingMode.onPaymentDate,
                  label: Text(l10n.rateFixingModeOnPaymentDate),
                ),
                ButtonSegment(
                  value: _RateFixingMode.specificDay,
                  label: Text(l10n.rateFixingModeSpecificDay),
                ),
              ],
              selected: {_rateFixingMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _rateFixingMode = selection.first;
                  _apply();
                });
              },
            ),
            if (_rateFixingMode == _RateFixingMode.specificDay) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _rateFixingDayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.onboardingIncomeRateFixingDayLabel,
                  errorText: _dayFieldError(l10n, _rateFixingDayController.text),
                ),
                onChanged: (_) => setState(_apply),
              ),
            ],
          ],
          if (needsPreviewRate) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _previewRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.onboardingIncomePreviewRateLabel(
                  incomeData.nominalAmount.currency.value,
                  incomeData.payoutCurrency.value,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Text(
              l10n.onboardingIncomePreviewRateHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          if (incomeData != null)
            for (var i = 0; i < _parts.length; i++) _buildPart(context, l10n, i, incomeData),
          Text(l10n.onboardingIncomeDeductionLabel, style: Theme.of(context).textTheme.labelLarge),
          Text(l10n.onboardingIncomeDeductionHint, style: Theme.of(context).textTheme.bodySmall),
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
              decoration: InputDecoration(
                labelText: l10n.onboardingIncomeDeductionAmountLabel,
                errorText: _numberFieldError(l10n, _deductionAmountController.text),
              ),
              onChanged: (_) => setState(_apply),
            ),
          ],
          if (_deductionMode == _DeductionMode.percentage) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _deductionPercentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.onboardingIncomeDeductionPercentageLabel,
                errorText: _numberFieldError(l10n, _deductionPercentController.text),
              ),
              onChanged: (_) => setState(_apply),
            ),
          ],
        ],
      ),
    );
  }
}
