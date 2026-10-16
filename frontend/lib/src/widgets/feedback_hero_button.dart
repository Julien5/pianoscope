import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../report.dart';
import '../rust/api/report.dart' show UploadSession;
import 'feedback_dialog.dart';

class _UploadHandler extends UploadHandler {
  final String feedbackSending;
  FeedbackOutcome? outcome;

  _UploadHandler({required super.session, required this.feedbackSending});

  @override
  Future<void> onSubmit(FeedbackRequest request) async {
    if (super.reportCallback != null) {
      super.reportCallback!(feedbackSending);
    }
    outcome = await submitFeedback(
      email: request.email,
      message: request.message,
      session: super.session,
      screenshot: request.withScreenshot ? request.screenshot : null,
    );
  }
}

class FeedbackHeroButton extends StatelessWidget {
  const FeedbackHeroButton({super.key});

  /// The dialog owns the whole exchange: it collects the answer, stores it and
  /// sends it while staying on screen with progress and a stop button, which is
  /// the same shape [flushPendingReports] uses for a batch.
  Future<void> _send(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final handler = _UploadHandler(
      session: UploadSession(),
      feedbackSending: l10n.feedbackSending,
    );

    await FeedbackDialog.show(
      context,
      mode: FeedbackMode.feedback,
      filenames: const [],
      handler: handler,
    );

    if (!context.mounted) return;
    // Read once into a final: the handler writes `outcome` from inside
    // `onSubmit`, so the analyzer will not promote it on its own.
    final result = handler.outcome;
    final String status;
    if (result == null) {
      status = l10n.feedbackNotSaved;
    } else if (result.uploaded) {
      status = l10n.feedbackSent;
    } else if (result.cancelled) {
      // Saved, just not sent: it goes out with the next pending batch.
      status = l10n.feedbackStopped;
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
