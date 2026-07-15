import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router/app_router.dart';
import '../../../core/money/common_currencies.dart';
import '../../../domain/entities/income_schedule_rule.dart';
import '../../../domain/entities/income_source.dart';
import '../../../domain/entities/user_profile.dart';
import '../application/currency_step_data.dart';
import '../application/income_calculation_step_data.dart';
import '../application/income_step_data.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_step_ids.dart';
import 'currency_step_screen.dart';
import 'income_calculation_step_screen.dart';
import 'income_step_screen.dart';
import 'life_expenses_step_screen.dart';
import 'onboarding_shell.dart';
import 'onboarding_summary_screen.dart';
import 'welcome_screen.dart';

enum _OnboardingPhase { welcome, steps, summary }

/// Top-level onboarding flow (doc.md §3.2, §3.3): welcome → step engine →
/// summary → persist [UserProfile] and hand off to Dashboard.
/// BUILD_PLAN.md E2.T4.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  _OnboardingPhase _phase = _OnboardingPhase.welcome;

  Future<void> _completeOnboarding() async {
    final stepData = ref.read(onboardingControllerProvider).stepData;
    final currencyData = stepData[OnboardingStepIds.currency] as CurrencyStepData?;
    final now = ref.read(clockProvider).now();

    final incomeData = stepData[OnboardingStepIds.income] as IncomeStepData?;
    final incomeCalculation =
        stepData[OnboardingStepIds.incomeCalculation] as IncomeCalculationStepData?;
    if (incomeData != null && incomeCalculation != null) {
      await ref
          .read(incomeSourceRepositoryProvider)
          .create(
            IncomeSource(
              name: incomeData.name,
              type: incomeData.type,
              nominalAmount: incomeData.nominalAmount,
              payoutCurrency: incomeData.payoutCurrency,
              calculationMode: incomeCalculation.calculationMode,
              deductionRule: incomeCalculation.deductionRule,
              startDate: now,
              isActive: true,
              scheduleRules: [
                for (var i = 0; i < incomeCalculation.parts.length; i++)
                  IncomeScheduleRule(
                    partIndex: i,
                    paymentDay: incomeCalculation.parts[i].paymentDay,
                    amount: incomeCalculation.parts[i].amount,
                    weekendShiftRule: incomeCalculation.parts[i].weekendShiftRule,
                    isActive: true,
                  ),
              ],
              createdAt: now,
              updatedAt: now,
            ),
          );
      ref.invalidate(incomeSourcesProvider);
    }

    if (!mounted) return;
    final profile = UserProfile(
      // Not collected by any onboarding step yet — deliberate placeholders
      // until a later epic adds screens for them.
      displayName: '',
      countryCode: '',
      timezone: 'UTC',
      primaryCurrency: currencyData?.primary ?? commonCurrencyCodes.first,
      additionalCurrencies: currencyData?.additional ?? const [],
      locale: Localizations.localeOf(context).languageCode,
      dateFormat: 'dd.MM.yyyy',
      numberFormat: '#,##0.00',
      financialMonthStartDay: 1,
      onboardingCompleted: true,
      familyModeEnabled: false,
      biometricLockEnabled: false,
      hideBalancesEnabled: false,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(userProfileRepositoryProvider).saveProfile(profile);
    ref.invalidate(userProfileProvider);

    if (!mounted) return;
    context.go(AppRoutes.overview);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _OnboardingPhase.welcome => WelcomeScreen(
        onStart: () => setState(() => _phase = _OnboardingPhase.steps),
      ),
      _OnboardingPhase.steps => OnboardingShell(
        stepBuilder: (context, stepId) => switch (stepId) {
          OnboardingStepIds.currency => const CurrencyStepScreen(),
          OnboardingStepIds.income => const IncomeStepScreen(),
          OnboardingStepIds.incomeCalculation => const IncomeCalculationStepScreen(),
          OnboardingStepIds.lifeExpenses => const LifeExpensesStepScreen(),
          _ => const SizedBox.shrink(),
        },
        onFinish: () => setState(() => _phase = _OnboardingPhase.summary),
      ),
      _OnboardingPhase.summary => OnboardingSummaryScreen(onOpenDashboard: _completeOnboarding),
    };
  }
}
