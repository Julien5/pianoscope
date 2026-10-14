import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../report.dart';
import 'feedback_dialog.dart';

/// Floating button that opens [FeedbackDialog] in [FeedbackMode.feedback] and
/// sends what the user wrote. Meant to be placed in the `floatingActionButton`
/// slot of a Scaffold so that it stays visible on top of the content of every
/// screen.
class FeedbackHeroButton extends StatelessWidget {
  const FeedbackHeroButton({super.key});

  Future<void> _send(BuildContext context) async {
    final request = await FeedbackDialog.show(
      context,
      mode: FeedbackMode.feedback,
      filenames: [],
    );
    if (request == null || !context.mounted) return;

    final outcome = await submitFeedback(
      email: request.email,
      message: request.message,
    );
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final String status;
    if (outcome == null) {
      status = l10n.feedbackNotSaved;
    } else if (outcome.uploaded) {
      status = l10n.feedbackSent;
    } else {
      status = l10n.feedbackQueued;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'feedback',
      tooltip: AppLocalizations.of(context)!.feedbackTitle,
      onPressed: () => _send(context),
      child: const Icon(Icons.feedback_outlined),
    );
  }
}
