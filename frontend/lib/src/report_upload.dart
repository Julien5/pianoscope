import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'report.dart';
import 'widgets/feedback_dialog.dart';

/// Offers to send everything still cached, then uploads it one file at a
/// time while the dialog shows the progress. Does nothing when the cache is
/// empty. Files that fail to upload stay on disk and will be offered again on
/// the next launch.
Future<void> flushPendingReports(BuildContext context) async {
  final names = await pendingReportNames();
  if (names.isEmpty || !context.mounted) {
    return;
  }
  final l10n = AppLocalizations.of(context)!;
  var sent = 0;
  var failed = 0;

  await FeedbackDialog.show(
    context,
    mode: FeedbackMode.crashReport,
    crashReportCount: names.length,
    onApproved: (reportProgress) async {
      for (var i = 0; i < names.length; i++) {
        final name = names[i];
        reportProgress(_progressText(l10n, name, i + 1));
        if (await uploadReport(name)) {
          debugPrint("good");
          sent++;
        } else {
          debugPrint("bad");
          failed++;
        }
      }
    },
  );

  if (!context.mounted) {
    return;
  }
  debugPrint("reports uploaded: $sent sent, $failed failed");
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.uploadSummary(failed, sent))));
}

String _progressText(AppLocalizations l10n, String filename, int position) {
  return filename.contains('feedback')
      ? l10n.uploadingFeedback(position)
      : l10n.uploadingCrashReport(position);
}
