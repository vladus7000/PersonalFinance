import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../application/onboarding_controller.dart';

/// Hosts the current onboarding step's content plus a progress bar and
/// back/skip/next navigation, wired to [onboardingControllerProvider].
/// BUILD_PLAN.md E2.T2.
///
/// Content-agnostic: [stepBuilder] renders whatever the current step needs
/// (E2.T3 adds the real step widgets). [onFinish] is called instead of
/// advancing once the user completes the last step — E2.T4 wires the real
/// "save profile, go to Dashboard" behavior; until then it is `null` and
/// the button on the last step stays a no-op.
class OnboardingShell extends ConsumerWidget {
  const OnboardingShell({super.key, required this.stepBuilder, this.onFinish});

  final Widget Function(BuildContext context, String stepId) stepBuilder;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final step = state.currentStep;

    if (step == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        leading: state.isFirstStep
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: notifier.back),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: state.progress),
          Expanded(child: stepBuilder(context, step.id)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Not shown on the last step: [OnboardingController.skip] only
            // advances the step index, so on the last step it has nowhere
            // to advance to and would silently no-op. An optional last step
            // is already reachable via the primary button below (its
            // `onPressed` is enabled for optional steps regardless of
            // completion), so Skip would be redundant there anyway.
            if (state.canSkipCurrentStep && !state.isLastStep)
              TextButton(onPressed: notifier.skip, child: Text(l10n.onboardingSkip)),
            const Spacer(),
            FilledButton(
              onPressed: !state.canProceed
                  ? null
                  : state.isLastStep
                  ? onFinish
                  : notifier.next,
              child: Text(state.isLastStep ? l10n.onboardingFinish : l10n.onboardingNext),
            ),
          ],
        ),
      ),
    );
  }
}
