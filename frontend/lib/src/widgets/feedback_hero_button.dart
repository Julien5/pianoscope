import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'feedback_dialog.dart';

/// Floating button that opens [FeedbackDialog] in [FeedbackMode.feedback].
/// Meant to be placed in the `floatingActionButton` slot of a Scaffold so
/// that it stays visible on top of the content of every screen.
class FeedbackHeroButton extends StatelessWidget {
  const FeedbackHeroButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'feedback',
      tooltip: AppLocalizations.of(context)!.feedbackTitle,
      onPressed: () =>
          FeedbackDialog.show(context, mode: FeedbackMode.feedback),
      child: const Icon(Icons.feedback_outlined),
    );
  }
}
