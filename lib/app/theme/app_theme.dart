import 'package:flutter/material.dart';

import 'pfa_colors.dart';
import 'pfa_text_styles.dart';

/// Builds the app's [ThemeData]. Dark is the default per doc.md §6.1
/// ("премиальный финансовый интерфейс", dark theme, card-based layout).
///
/// All screens must read colors/text styles through [PfaColors.of] and
/// [PfaTextStyles.of] rather than hardcoding [Color]/[TextStyle] values,
/// so the palette can be changed here without touching feature code.
abstract final class AppTheme {
  static ThemeData get dark => _build(brightness: Brightness.dark, tokens: PfaColors.dark);

  static ThemeData get light => _build(brightness: Brightness.light, tokens: PfaColors.light);

  static ThemeData _build({required Brightness brightness, required PfaColors tokens}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.planInfo,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      extensions: [
        tokens,
        PfaTextStyles.fromBase(
          base.textTheme,
          onSurface: colorScheme.onSurface,
          onSurfaceMuted: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
