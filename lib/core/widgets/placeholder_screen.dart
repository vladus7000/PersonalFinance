import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../../app/theme/pfa_text_styles.dart';

/// Generic stub used by feature screens that have not been built yet by
/// their corresponding BUILD_PLAN epic. Replace with the real screen when
/// that epic's presentation task is done.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyles = PfaTextStyles.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(l10n.screenPlaceholder, style: textStyles.secondaryLabel),
      ),
    );
  }
}
