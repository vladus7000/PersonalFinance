import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

/// First-launch screen (doc.md §3.2): introduces the product philosophy
/// before onboarding starts. No auth/backend exists yet in MVP, so this
/// deliberately omits "I already have an account" and the Privacy Policy
/// link from the ТЗ — those return once E14.T3 (Privacy Policy) and an
/// account system exist.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.appTitle, style: textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(l10n.welcomeMessage, style: textTheme.bodyLarge),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onStart, child: Text(l10n.welcomeStart)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
