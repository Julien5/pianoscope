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

Future<void> showFeedbackDialog(BuildContext context) async {
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
    // cancelled by user before sent
    return;
  } else if (result.uploaded) {
    status = l10n.feedbackSent;
  } else if (result.cancelled) {
    // Saved, just not sent: it goes out with the next pending batch.
    status = l10n.feedbackStopped;
  } else {
    status = l10n.feedbackQueued;
  }
  debugPrint("result:$result status=$status");
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
}
