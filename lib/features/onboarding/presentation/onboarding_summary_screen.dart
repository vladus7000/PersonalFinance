import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/money/common_currencies.dart';
import '../application/currency_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';

/// Onboarding «Завершение» (doc.md §3.3): a brief summary of what was
/// entered, plus the button that persists the profile and opens Dashboard.
class OnboardingSummaryScreen extends ConsumerWidget {
  const OnboardingSummaryScreen({super.key, required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stepData = ref.watch(onboardingControllerProvider).stepData;
    final currencyData = stepData[OnboardingStepIds.currency] as CurrencyStepData?;
    final primaryCurrency = currencyData?.primary ?? commonCurrencyCodes.first;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.onboardingSummaryTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_money),
              title: Text(l10n.onboardingSummaryPrimaryCurrency),
              subtitle: Text(primaryCurrency.value),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenDashboard,
                child: Text(l10n.onboardingSummaryOpenDashboard),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
