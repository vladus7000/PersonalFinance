import 'package:flutter/material.dart';

import '../../../app/router/placeholder_screen.dart';
import '../../../core/l10n/gen/app_localizations.dart';

/// §3.9 doc.md — built out in E5.T2.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(title: AppLocalizations.of(context).navAccounts);
  }
}
