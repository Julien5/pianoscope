import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'report.dart';
import 'rust/api/report.dart' show UploadSession;
import 'widgets/feedback_dialog.dart';

class _UploadHandler extends UploadHandler {
  final AppLocalizations l10n;
  final List<String> filenames;

  bool stopped = false;
  int sent = 0;
  int failed = 0;

  _UploadHandler({
    required super.session,
    required this.l10n,
    required this.filenames,
  });

  @override
  Future<void> onSubmit(FeedbackRequest request) async {
    for (var i = 0; i < filenames.length; i++) {
      final name = filenames[i];
      if (super.reportCallback != null) {
        super.reportCallback!(_progressText(name, i + 1));
      }
      final outcome = await uploadReport(session, name);
      if (outcome.cancelled) {
        debugPrint("stopped before $name");
        stopped = true;
        return;
      }
      if (outcome.sent) {
        debugPrint("good");
        sent++;
      } else {
        debugPrint("bad: ${outcome.error}");
        failed++;
      }
    }
  }

  String _progressText(String filename, int position) {
    return filename.contains('feedback')
        ? l10n.uploadingFeedback(position)
        : l10n.uploadingCrashReport(position);
  }
}

/// Offers to send everything still cached, then uploads it one file at a
/// time while the dialog shows the progress. Does nothing when the cache is
/// empty. Files that fail to upload stay on disk and will be offered again on
/// the next launch, and so do the ones the user stops: [UploadSession.cancel]
/// cuts the request that is in flight as well as the loop.
Future<void> flushPendingReports(BuildContext context) async {
  final filenames = await pendingReportNames();
  if (filenames.isEmpty || !context.mounted) {
    return;
  }
  final l10n = AppLocalizations.of(context)!;
  final uploadHandler = _UploadHandler(
    session: UploadSession(),
    l10n: l10n,
    filenames: filenames,
  );

  await FeedbackDialog.show(
    context,
    mode: FeedbackMode.crashReport,
    filenames: filenames,
    handler: uploadHandler,
  );

  if (!context.mounted) {
    return;
  }
  debugPrint(
    "reports uploaded: ${uploadHandler.sent} sent, ${uploadHandler.failed} failed, stopped=${uploadHandler.stopped}",
  );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        uploadHandler.stopped
            ? l10n.uploadStopped(uploadHandler.sent)
            : l10n.uploadSummary(uploadHandler.failed, uploadHandler.sent),
      ),
    ),
  );
}
