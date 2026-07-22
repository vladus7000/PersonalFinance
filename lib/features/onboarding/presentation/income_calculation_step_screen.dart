import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/money/percentage.dart';
import '../../../domain/entities/deduction_rule.dart';
import '../../../domain/entities/payment_part_amount.dart';
import '../../../domain/entities/weekend_shift_rule.dart';
import '../application/income_calculation_step_data.dart';
import '../application/income_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

enum _AmountMode { percentage, byWorkingDays }

enum _DeductionMode { none, fixed, percentage }

enum _RateFixingMode { onPaymentDate, specificDay }

class _PartFormState {
  final dayController = TextEditingController();
  WeekendShiftRule weekendShiftRule = WeekendShiftRule.none;

  void dispose() => dayController.dispose();
}

/// Onboarding step 3 (doc.md §3.3, §8.20): [IncomeCalculationStepData] — how
/// many parts to render is fixed by [IncomeStepData.payoutsPerMonth] (set
/// in the previous step).
///
/// A single-part source never asks about the amount at all — it's
/// implicitly the full nominal amount. A two-part source (advance + main
/// payment) only asks the *advance* how it's computed: either a percentage
/// of the nominal amount, or "by working days" (a daily rate times working
/// days in a date range the user picks — never asking for actual
/// attendance, always assuming the full range was worked, per the
/// 2026-07-22 simplification: this app is not for logging sick days). The
/// main payment always mirrors the advance's choice automatically — a
/// percentage advance leaves main "the rest"; a by-working-days advance
/// leaves main the rest of the month's date range — so there is exactly
/// one decision to make for a two-part source, not two.
///
/// Neither part asks which calendar month it's paid in: the advance
/// defaults to the same month as the period, the main payment to the
/// following month (doc.md §8.18/§8.20) — editable later via a dedicated
/// income source editor once one exists, not during onboarding.
///
/// When the payout currency differs from the contract currency, an
/// optional, never-persisted "preview rate" lets the user see roughly how
/// much a percentage-mode part converts to.
class IncomeCalculationStepScreen extends ConsumerStatefulWidget {
  const IncomeCalculationStepScreen({super.key});

  @override
  ConsumerState<IncomeCalculationStepScreen> createState() =>
      _IncomeCalculationStepScreenState();
}

class _IncomeCalculationStepScreenState extends ConsumerState<IncomeCalculationStepScreen> {
  late final List<_PartFormState> _parts;
  _AmountMode _advanceAmountMode = _AmountMode.percentage;
  final _advancePercentageController = TextEditingController();
  final _advanceCoverageStartController = TextEditingController();
  final _advanceCoverageEndController = TextEditingController();
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
      _parts[i].dayController.text = existing.parts[i].paymentDay.toString();
      _parts[i].weekendShiftRule = existing.parts[i].weekendShiftRule;
    }
    if (_hasTwoParts && existing.parts.isNotEmpty) {
      switch (existing.parts.first.amount) {
        case PercentagePaymentPart(:final percentage):
          _advanceAmountMode = _AmountMode.percentage;
          _advancePercentageController.text = percentage.value.toString();
        case FixedPaymentPart():
          // No longer offered by this screen, but tolerate old saved data.
          _advanceAmountMode = _AmountMode.percentage;
        case null:
          _advanceAmountMode = _AmountMode.byWorkingDays;
          _advanceCoverageStartController.text = existing.parts.first.coverageStartDay.toString();
          _advanceCoverageEndController.text = existing.parts.first.coverageEndDay.toString();
      }
    }
  }

  @override
  void dispose() {
    for (final part in _parts) {
      part.dispose();
    }
    _advancePercentageController.dispose();
    _advanceCoverageStartController.dispose();
    _advanceCoverageEndController.dispose();
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

    final parts = <IncomePartInput>[];

    if (!_hasTwoParts) {
      final day = int.tryParse(_parts[0].dayController.text);
      if (day == null || day < 1 || day > 31) return _markIncomplete();
      parts.add(
        IncomePartInput(
          coverageStartDay: 1,
          coverageEndDay: 31,
          paymentDay: day,
          weekendShiftRule: _parts[0].weekendShiftRule,
          amount: PaymentPartAmount.fixed(amount: incomeData.nominalAmount),
        ),
      );
    } else {
      final advanceDay = int.tryParse(_parts[0].dayController.text);
      if (advanceDay == null || advanceDay < 1 || advanceDay > 31) return _markIncomplete();
      final mainDay = int.tryParse(_parts[1].dayController.text);
      if (mainDay == null || mainDay < 1 || mainDay > 31) return _markIncomplete();

      PaymentPartAmount? advanceAmount;
      PaymentPartAmount? mainAmount;
      var advanceCoverageStart = 1;
      var advanceCoverageEnd = 31;
      var mainCoverageStart = 1;
      var mainCoverageEnd = 31;

      if (_advanceAmountMode == _AmountMode.percentage) {
        final percentage = Decimal.tryParse(_advancePercentageController.text);
        if (percentage == null) return _markIncomplete();
        advanceAmount = PaymentPartAmount.percentage(percentage: Percentage(percentage));
        mainAmount = PaymentPartAmount.percentage(
          percentage: Percentage(Decimal.fromInt(100) - percentage),
        );
      } else {
        final start = int.tryParse(_advanceCoverageStartController.text);
        final end = int.tryParse(_advanceCoverageEndController.text);
        if (start == null || start < 1 || start > 31) return _markIncomplete();
        if (end == null || end < 1 || end > 31 || end < start || end >= 31) {
          return _markIncomplete();
        }
        advanceCoverageStart = start;
        advanceCoverageEnd = end;
        mainCoverageStart = end + 1;
        mainCoverageEnd = 31;
      }

      parts.add(
        IncomePartInput(
          coverageStartDay: advanceCoverageStart,
          coverageEndDay: advanceCoverageEnd,
          paymentDay: advanceDay,
          weekendShiftRule: _parts[0].weekendShiftRule,
          amount: advanceAmount,
        ),
      );
      parts.add(
        IncomePartInput(
          coverageStartDay: mainCoverageStart,
          coverageEndDay: mainCoverageEnd,
          paymentDay: mainDay,
          paymentMonthOffset: 1,
          weekendShiftRule: _parts[1].weekendShiftRule,
          amount: mainAmount,
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

  /// The advance's coverage-end field must also leave at least one day of
  /// the month for the main payment's automatically-derived range.
  String? _advanceCoverageEndError(AppLocalizations l10n) {
    final startText = _advanceCoverageStartController.text;
    final endText = _advanceCoverageEndController.text;
    final dayError = _dayFieldError(l10n, endText);
    if (dayError != null) return dayError;
    final start = int.tryParse(startText);
    final end = int.tryParse(endText);
    if (start != null && end != null && end < start) {
      return l10n.onboardingIncomeCoverageRangeInvalid;
    }
    if (end != null && end >= 31) return l10n.onboardingIncomePartCoverageEndTooLate;
    return null;
  }

  Widget _buildAdvanceAmountSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(l10n.onboardingIncomePartAmountModeLabel, style: Theme.of(context).textTheme.labelLarge),
        SegmentedButton<_AmountMode>(
          segments: [
            ButtonSegment(
              value: _AmountMode.percentage,
              label: Text(l10n.paymentPartAmountModePercentage),
            ),
            ButtonSegment(
              value: _AmountMode.byWorkingDays,
              label: Text(l10n.paymentPartAmountModeByWorkingDays),
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
        if (_advanceAmountMode == _AmountMode.percentage)
          TextField(
            controller: _advancePercentageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.onboardingIncomePartPercentageLabel,
              errorText: _numberFieldError(l10n, _advancePercentageController.text),
            ),
            onChanged: (_) => setState(_apply),
          )
        else ...[
          Text(
            l10n.onboardingIncomePartCoverageLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _advanceCoverageStartController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingIncomePartCoverageFromLabel,
                    errorText: _dayFieldError(l10n, _advanceCoverageStartController.text),
                  ),
                  onChanged: (_) => setState(_apply),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _advanceCoverageEndController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingIncomePartCoverageToLabel,
                    errorText: _advanceCoverageEndError(l10n),
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
      ],
    );
  }

  /// A human-readable preview of the main payment's auto-computed share —
  /// either "60%" or "for the 16-31" depending on the advance's mode.
  String _mainPaymentPreview(AppLocalizations l10n) {
    if (_advanceAmountMode == _AmountMode.percentage) {
      final percentage = Decimal.tryParse(_advancePercentageController.text);
      return l10n.onboardingIncomeMainPaymentAuto(
        percentage == null ? '—' : '${Decimal.fromInt(100) - percentage}%',
      );
    }
    final end = int.tryParse(_advanceCoverageEndController.text);
    if (end == null || end >= 31) {
      return l10n.onboardingIncomeMainPaymentAutoCoverage(0, 0);
    }
    return l10n.onboardingIncomeMainPaymentAutoCoverage(end + 1, 31);
  }

  /// A rough, never-persisted conversion of a percentage-mode part's amount
  /// (in the contract currency) to the payout currency, using whatever the
  /// user typed into [_previewRateController].
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
          if (_hasTwoParts && isAdvance) _buildAdvanceAmountSection(context, l10n),
          if (_hasTwoParts && !isAdvance) ...[
            const SizedBox(height: 12),
            Text(_mainPaymentPreview(l10n), style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (_previewAmountFor(index, incomeData) case final previewAmount?)
            _buildAmountPreview(context, l10n, previewAmount, incomeData)
          else if (_hasTwoParts && _advanceAmountMode == _AmountMode.byWorkingDays)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.onboardingIncomePartAmountDependsOnAttendance,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  /// This part's amount, for the currency preview — `null` when it can't
  /// be known without a full forecast (by-working-days mode).
  PaymentPartAmount? _previewAmountFor(int index, IncomeStepData incomeData) {
    if (!_hasTwoParts) return PaymentPartAmount.fixed(amount: incomeData.nominalAmount);
    if (_advanceAmountMode != _AmountMode.percentage) return null;
    final advancePercentage = Decimal.tryParse(_advancePercentageController.text);
    if (advancePercentage == null) return null;
    return index == 0
        ? PaymentPartAmount.percentage(percentage: Percentage(advancePercentage))
        : PaymentPartAmount.percentage(
            percentage: Percentage(Decimal.fromInt(100) - advancePercentage),
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final incomeData = _incomeData;
    final needsPreviewRate =
        incomeData != null &&
        incomeData.nominalAmount.currency != incomeData.payoutCurrency &&
        (!_hasTwoParts || _advanceAmountMode == _AmountMode.percentage);

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
          if (_hasTwoParts) ...[
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
            const SizedBox(height: 24),
          ],
          if (needsPreviewRate) ...[
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
            const SizedBox(height: 24),
          ],
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
