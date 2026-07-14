import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/common_currencies.dart';
import '../../../core/money/currency_code.dart';
import '../application/currency_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

/// Onboarding step 1 (§3.3 doc.md): primary + additional currencies.
/// Selection is held in [OnboardingState.stepData] until onboarding
/// completes (E2.T4 persists it into [UserProfile]).
///
/// A default primary currency is committed to state as soon as the step is
/// shown (see [initState]) — otherwise a user who agrees with the default
/// would see "Next" stay disabled despite a value already being displayed.
class CurrencyStepScreen extends ConsumerStatefulWidget {
  const CurrencyStepScreen({super.key});

  @override
  ConsumerState<CurrencyStepScreen> createState() => _CurrencyStepScreenState();
}

class _CurrencyStepScreenState extends ConsumerState<CurrencyStepScreen> {
  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(onboardingControllerProvider).stepData[OnboardingStepIds.currency]
            as CurrencyStepData?;
    if (existing == null) {
      // Riverpod forbids modifying provider state synchronously during
      // build/initState — defer to right after the first frame.
      Future(() => _update(primary: commonCurrencyCodes.first, additional: const []));
    }
  }

  void _update({required CurrencyCode primary, required List<CurrencyCode> additional}) {
    ref
        .read(onboardingControllerProvider.notifier)
        .setStepData(
          OnboardingStepIds.currency,
          CurrencyStepData(primary: primary, additional: additional),
          completed: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stepData =
        ref.watch(
              onboardingControllerProvider.select(
                (s) => s.stepData[OnboardingStepIds.currency],
              ),
            )
            as CurrencyStepData?;

    final primary = stepData?.primary ?? commonCurrencyCodes.first;
    final additional = stepData?.additional ?? const <CurrencyCode>[];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingCurrencyTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text(l10n.onboardingPrimaryCurrencyLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButton<CurrencyCode>(
            value: primary,
            isExpanded: true,
            items: [
              for (final currency in commonCurrencyCodes)
                DropdownMenuItem(value: currency, child: Text(currency.value)),
            ],
            onChanged: (value) {
              if (value == null) return;
              _update(primary: value, additional: additional.where((c) => c != value).toList());
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.onboardingAdditionalCurrenciesLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final currency in commonCurrencyCodes.where((c) => c != primary))
                FilterChip(
                  label: Text(currency.value),
                  selected: additional.contains(currency),
                  onSelected: (selected) {
                    final next = selected
                        ? [...additional, currency]
                        : additional.where((c) => c != currency).toList();
                    _update(primary: primary, additional: next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
