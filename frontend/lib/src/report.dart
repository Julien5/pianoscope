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
