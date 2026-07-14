import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import '../../core/money/percentage.dart';

part 'living_expense_preference.freezed.dart';

/// How the user estimates monthly living expenses — doc.md §2.8, entered in
/// onboarding step 4 (§3.3). Aggregated only, never a per-transaction
/// budget (§1.5 — this app is not an expense tracker).
@freezed
sealed class LivingExpensePreference with _$LivingExpensePreference {
  const factory LivingExpensePreference.fixed({required Money amount}) = FixedLivingExpense;

  const factory LivingExpensePreference.percentOfIncome({required Percentage percentage}) =
      PercentLivingExpense;

  const factory LivingExpensePreference.range({required Money min, required Money max}) =
      RangeLivingExpense;
}
