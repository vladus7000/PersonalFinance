import 'package:flutter/material.dart';

/// Typography tokens for financial figures, per doc.md §6.3:
/// large primary amounts, less-contrast secondary text, small labels for
/// percentage/change figures shown next to an amount.
@immutable
class PfaTextStyles extends ThemeExtension<PfaTextStyles> {
  const PfaTextStyles({
    required this.amountDisplay,
    required this.amountLarge,
    required this.amountMedium,
    required this.changeLabel,
    required this.secondaryLabel,
  });

  /// The single largest figure on a screen (e.g. total net worth on Dashboard).
  final TextStyle amountDisplay;

  /// Prominent amount on a card (e.g. account balance, holding value).
  final TextStyle amountLarge;

  /// Amount in a list row or compact context.
  final TextStyle amountMedium;

  /// Small label next to an amount showing absolute/percentage change.
  final TextStyle changeLabel;

  /// Lower-contrast supporting text (captions, dates, secondary metadata).
  final TextStyle secondaryLabel;

  factory PfaTextStyles.fromBase(TextTheme base, {required Color onSurface, required Color onSurfaceMuted}) {
    return PfaTextStyles(
      amountDisplay: (base.displaySmall ?? const TextStyle(fontSize: 36))
          .copyWith(fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.5),
      amountLarge: (base.headlineMedium ?? const TextStyle(fontSize: 28))
          .copyWith(fontWeight: FontWeight.w700, color: onSurface),
      amountMedium: (base.titleLarge ?? const TextStyle(fontSize: 20))
          .copyWith(fontWeight: FontWeight.w600, color: onSurface),
      changeLabel: (base.labelLarge ?? const TextStyle(fontSize: 14))
          .copyWith(fontWeight: FontWeight.w600),
      secondaryLabel: (base.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(color: onSurfaceMuted),
    );
  }

  static PfaTextStyles of(BuildContext context) =>
      Theme.of(context).extension<PfaTextStyles>() ??
      PfaTextStyles.fromBase(
        Theme.of(context).textTheme,
        onSurface: Theme.of(context).colorScheme.onSurface,
        onSurfaceMuted: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  @override
  PfaTextStyles copyWith({
    TextStyle? amountDisplay,
    TextStyle? amountLarge,
    TextStyle? amountMedium,
    TextStyle? changeLabel,
    TextStyle? secondaryLabel,
  }) {
    return PfaTextStyles(
      amountDisplay: amountDisplay ?? this.amountDisplay,
      amountLarge: amountLarge ?? this.amountLarge,
      amountMedium: amountMedium ?? this.amountMedium,
      changeLabel: changeLabel ?? this.changeLabel,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
    );
  }

  @override
  PfaTextStyles lerp(ThemeExtension<PfaTextStyles>? other, double t) {
    if (other is! PfaTextStyles) return this;
    return PfaTextStyles(
      amountDisplay: TextStyle.lerp(amountDisplay, other.amountDisplay, t)!,
      amountLarge: TextStyle.lerp(amountLarge, other.amountLarge, t)!,
      amountMedium: TextStyle.lerp(amountMedium, other.amountMedium, t)!,
      changeLabel: TextStyle.lerp(changeLabel, other.changeLabel, t)!,
      secondaryLabel: TextStyle.lerp(secondaryLabel, other.secondaryLabel, t)!,
    );
  }
}
