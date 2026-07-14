/// Canonical step ids — the single place both `onboardingStepsProvider`
/// (the ordered list) and each step's screen (which reads/writes its own
/// slice of `OnboardingState.stepData`) refer to, so neither has to import
/// the other.
abstract final class OnboardingStepIds {
  static const currency = 'currency';
  static const lifeExpenses = 'life_expenses';
}
