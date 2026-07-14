import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';
import '../../../core/l10n/gen/app_localizations.dart';

/// §3.13 doc.md — built out in E9.T2.
class DecisionsScreen extends StatelessWidget {
  const DecisionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(title: AppLocalizations.of(context).navDecisions);
  }
}
