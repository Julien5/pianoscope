import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'rust/api/report.dart';

const reportDirName = 'reports';

Directory? _reportDir;

Future<Directory?> reportDirectory() async {
  if (_reportDir != null) {
    return _reportDir;
  }
  try {
    final cacheDir = await getApplicationCacheDirectory();
    final dir = Directory('${cacheDir.path}/$reportDirName');
    await dir.create(recursive: true);
    _reportDir = dir;
    return dir;
  } catch (e) {
    debugPrint("report directory not available: $e");
    return null;
  }
}

Future<void> initReportDir() async {
  final dir = await reportDirectory();
  if (dir == null) {
    return;
  }
  final error = setReportDir(dir: dir.path);
  if (error.isNotEmpty) {
    debugPrint("report directory not set: $error");
  }
}

/// Names of the reports and feedback still waiting to be sent.
Future<List<String>> pendingReportNames() async {
  try {
    return await reportsList();
  } catch (e) {
    debugPrint("pending reports not listed: $e");
    return [];
  }
}

/// [UploadOutcome] comes from the Rust side; this adds the one thing the UI
/// asks most often, which is whether the server took the file.
extension UploadOutcomeX on UploadOutcome {
  /// True when the server accepted the file and it was deleted from the cache.
  bool get sent => !cancelled && error.isEmpty;
}

/// Sends one pending file through [session], mapping a transport failure to the
/// same three-way outcome the Rust side uses. A file that was not sent stays on
/// disk, which is what lets the next launch offer it again.
Future<UploadOutcome> uploadReport(
  UploadSession session,
  String filename,
) async {
  try {
    return await session.upload(filename: filename);
  } catch (e) {
    debugPrint("upload of $filename failed: $e");
    return UploadOutcome(cancelled: false, error: '$e');
  }
}

/// Where a submitted feedback ended up.
class FeedbackOutcome {
  /// Name of the file in the cache directory.
  final String filename;

  /// False when the server could not be reached. The file then stays on disk
  /// and is offered again on the next launch.
  final bool uploaded;

  /// True when the user stopped the upload. The file stays on disk, like when
  /// the server is unreachable, but for a different reason.
  final bool cancelled;

  const FeedbackOutcome({
    required this.filename,
    required this.uploaded,
    this.cancelled = false,
  });
}

/// Stores the feedback in the cache, then tries to send it on [session].
/// Returns null when it could not be written at all.
///
/// [screenshot] is still always null: the dialog collects the intent to send
/// one, but nothing captures the screen yet.
Future<FeedbackOutcome?> submitFeedback({
  required String email,
  required String message,
  Uint8List? screenshot,
  required UploadSession session,
}) async {
  final feedback = Feedback(
    email: email,
    message: message,
    screenshot: screenshot ?? Uint8List(0),
  );
  final String filename;
  try {
    filename = writeFeedback(feedback: feedback);
  } catch (e) {
    debugPrint("feedback not saved: $e");
    return null;
  }
  debugPrint("feedback saved as $filename");
  final outcome = await uploadReport(session, filename);
  return FeedbackOutcome(
    filename: filename,
    uploaded: outcome.sent,
    cancelled: outcome.cancelled,
  );
}

void setupReportHandlers() {
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    presentError?.call(details);
    writeDartReport(
      errorMessage: details.exceptionAsString(),
      stack: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    writeDartReport(errorMessage: error.toString(), stack: stack);
    return true;
  };
}

void writeDartReport({required String errorMessage, StackTrace? stack}) {
  try {
    writeCrashreport(
      report: CrashReport(
        datetime: reportDatetime(),
        location: _location(stack) ?? 'unknown',
        errorMessage: errorMessage,
        stacktrace: stack?.toString() ?? '',
      ),
    );
  } catch (e) {
    debugPrint("crash report not written: $e");
  }
}

/// RFC 3339 in UTC with second precision, matching what Rust writes in
/// `backend/src/report.rs`. Pinned by `report_datetime_test.dart`.
String reportDatetime() {
  return '${DateTime.now().toUtc().toIso8601String().substring(0, 19)}Z';
}

String? _location(StackTrace? stack) {
  if (stack == null) {
    return null;
  }
  final frame = RegExp(r'\((.+):(\d+):\d+\)\s*$');
  for (final line in stack.toString().split('\n')) {
    final match = frame.firstMatch(line.trim());
    if (match == null) {
      continue;
    }
    final file = match.group(1)!;
    if (file.startsWith('dart:')) {
      continue;
    }
    return '${file.split('/').last}:${match.group(2)}';
  }
  return null;
}
