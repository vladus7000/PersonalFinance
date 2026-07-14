import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:personal_finance_assistant/app/theme/app_theme.dart';
import 'package:personal_finance_assistant/core/l10n/gen/app_localizations.dart';

/// Pumps [child] wrapped in the same ancestors every real screen has —
/// [ProviderScope] (with optional [overrides] for fakes/mocks),
/// localization, and the app theme — without a real [GoRouter].
///
/// Use this for isolated screen/widget tests (BUILD_PLAN.md §0.6). Tests
/// that need real navigation should pump `PfaApp` itself instead — see
/// test/main_test.dart.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: child,
      ),
    ),
  );
}
