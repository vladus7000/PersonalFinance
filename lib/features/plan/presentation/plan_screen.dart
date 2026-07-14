import 'package:flutter/material.dart';

import '../../../app/router/placeholder_screen.dart';
import '../../../core/l10n/gen/app_localizations.dart';

/// §3.5 / §3.6 doc.md (unified Plan/Cycle screen, §8.5) — built out in E6.T2.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(title: AppLocalizations.of(context).navPlan);
  }
}
