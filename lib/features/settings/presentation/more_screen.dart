import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

/// §3.1 doc.md — "Ещё" tab. Lists secondary sections that live outside the
/// 4 main tabs; each item becomes a real route as its owning epic lands
/// (Investments: E8, Documents: E10, Goals: E7, Analytics: E11, Planner: E12,
/// Settings: not yet scheduled as its own epic — settled alongside E12/E13).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <String>[
      l10n.moreInvestments,
      l10n.moreDocuments,
      l10n.moreGoals,
      l10n.moreAnalytics,
      l10n.morePlanner,
      l10n.moreSettings,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => ListTile(title: Text(items[index])),
      ),
    );
  }
}
