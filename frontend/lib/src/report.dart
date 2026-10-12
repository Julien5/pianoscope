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

/// Sends one pending file. False means it failed and stays on disk for the
/// next launch.
Future<bool> uploadReport(String filename) async {
  try {
    final error = await upload(filename: filename);
    if (error.isNotEmpty) {
      debugPrint("upload of $filename failed: $error");
      return false;
    }
    return true;
  } catch (e) {
    debugPrint("upload of $filename failed: $e");
    return false;
  }
}

/// Where a submitted feedback ended up.
class FeedbackOutcome {
  /// Name of the file in the cache directory.
  final String filename;

  /// False when the server could not be reached. The file then stays on disk
  /// and is offered again on the next launch.
  final bool uploaded;

  const FeedbackOutcome({required this.filename, required this.uploaded});
}

/// Writes the feedback to the cache, then immediately tries to send it.
/// Returns null when it could not be written at all.
Future<FeedbackOutcome?> submitFeedback({
  required String email,
  required String message,
  Uint8List? screenshot,
}) async {
  final feedback = Feedback(
    email: email,
    message: message,
    screenshot: screenshot ?? Uint8List(0),
  );
  final String filename;
  try {
    filename = saveFeedback(feedback: feedback);
  } catch (e) {
    debugPrint("feedback not saved: $e");
    return null;
  }
  debugPrint("feedback saved as $filename");
  return FeedbackOutcome(
    filename: filename,
    uploaded: await uploadReport(filename),
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
    final error = writeReport(
      report: CrashReport(
        datetime: reportDatetime(),
        location: _location(stack) ?? 'unknown',
        errorMessage: errorMessage,
        stacktrace: stack?.toString() ?? '',
      ),
    );
    if (error.isNotEmpty) {
      debugPrint("crash report not written: $error");
    }
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
