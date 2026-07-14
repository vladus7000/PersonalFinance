import 'package:flutter/material.dart';

import '../../../app/router/placeholder_screen.dart';
import '../../../core/l10n/gen/app_localizations.dart';

/// §3.4 doc.md — built out in E11.T2.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(title: AppLocalizations.of(context).navOverview);
  }
}
