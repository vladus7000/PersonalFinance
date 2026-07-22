import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/common_currencies.dart';
import '../../../core/money/currency_code.dart';
import '../application/currency_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

/// Onboarding step 1 (§3.3 doc.md): the currency all capital/summary
/// figures are totaled in (doc.md §8.17) — each account/income still keeps
/// its own real currency, this is only the aggregation currency for the
/// Dashboard. Selection is held in [OnboardingState.stepData] until
/// onboarding completes (E2.T4 persists it into [UserProfile]).
///
/// No "additional currencies" question here (removed 2026-07-22, see
/// doc.md §8.20): `UserProfile.additionalCurrencies` isn't read by any
/// feature yet, so asking for it during onboarding was just friction with
/// no payoff — the field stays in the schema (always empty from onboarding)
/// for whenever a concrete use appears.
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
      Future(() => _update(commonCurrencyCodes.first));
    }
  }

  void _update(CurrencyCode primary) {
    ref
        .read(onboardingControllerProvider.notifier)
        .setStepData(
          OnboardingStepIds.currency,
          CurrencyStepData(primary: primary, additional: const []),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingCurrencyTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.onboardingCurrencyHint, style: Theme.of(context).textTheme.bodySmall),
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
              _update(value);
            },
          ),
        ],
      ),
    );
  }
}
