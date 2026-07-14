import 'package:flutter/material.dart';

/// Semantic color tokens for financial state, per doc.md §6.2.
///
/// UI code must reference these tokens (via [PfaColors.of]) instead of raw
/// [Color] values, so the palette can be swapped in one place.
@immutable
class PfaColors extends ThemeExtension<PfaColors> {
  const PfaColors({
    required this.positive,
    required this.planInfo,
    required this.pending,
    required this.goals,
    required this.negative,
    required this.neutral,
  });

  /// Done, growth, income, positive status.
  final Color positive;

  /// Plan, investments, neutral action.
  final Color planInfo;

  /// Emergency fund, waiting, warning.
  final Color pending;

  /// Goals, long-term plans.
  final Color goals;

  /// Error, overdue, negative event.
  final Color negative;

  /// Inactive or unknown state.
  final Color neutral;

  static const dark = PfaColors(
    positive: Color(0xFF4ADE80),
    planInfo: Color(0xFF60A5FA),
    pending: Color(0xFFFBBF24),
    goals: Color(0xFFA78BFA),
    negative: Color(0xFFF87171),
    neutral: Color(0xFF9CA3AF),
  );

  static const light = PfaColors(
    positive: Color(0xFF16A34A),
    planInfo: Color(0xFF2563EB),
    pending: Color(0xFFD97706),
    goals: Color(0xFF7C3AED),
    negative: Color(0xFFDC2626),
    neutral: Color(0xFF6B7280),
  );

  static PfaColors of(BuildContext context) =>
      Theme.of(context).extension<PfaColors>() ?? dark;

  @override
  PfaColors copyWith({
    Color? positive,
    Color? planInfo,
    Color? pending,
    Color? goals,
    Color? negative,
    Color? neutral,
  }) {
    return PfaColors(
      positive: positive ?? this.positive,
      planInfo: planInfo ?? this.planInfo,
      pending: pending ?? this.pending,
      goals: goals ?? this.goals,
      negative: negative ?? this.negative,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  PfaColors lerp(ThemeExtension<PfaColors>? other, double t) {
    if (other is! PfaColors) return this;
    return PfaColors(
      positive: Color.lerp(positive, other.positive, t)!,
      planInfo: Color.lerp(planInfo, other.planInfo, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      goals: Color.lerp(goals, other.goals, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}
