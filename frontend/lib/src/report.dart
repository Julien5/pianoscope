import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'rust/api/init.dart';

const reportDirName = 'reports';
const reportFilePrefix = 'report-';
const reportFileSuffix = '.json';
const reportFileDigits = 4;
const reportFileAttempts = 1000;

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
    unawaited(
      writeDartReport(
        errorMessage: details.exceptionAsString(),
        stack: details.stack,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(writeDartReport(errorMessage: error.toString(), stack: stack));
    return true;
  };
}

Future<void> writeDartReport({
  required String errorMessage,
  StackTrace? stack,
}) async {
  try {
    final dir = await reportDirectory();
    if (dir == null) {
      debugPrint(
        "crash report not written (no report directory): $errorMessage",
      );
      return;
    }
    final report = jsonEncode({
      'datetime': _datetime(),
      'location': _location(stack) ?? 'unknown',
      'error_message': errorMessage,
      'stacktrace': stack?.toString() ?? '',
    });
    final file = await _createReportFile(dir, report);
    debugPrint(
      file == null
          ? "crash report not written (no free file name): $errorMessage"
          : "crash report written to ${file.path}",
    );
  } catch (e) {
    debugPrint("crash report not written: $e");
  }
}

Future<File?> _createReportFile(Directory dir, String content) async {
  var index = await _lastReportIndex(dir) + 1;
  for (var attempt = 0; attempt < reportFileAttempts; attempt++) {
    final digits = index.toString().padLeft(reportFileDigits, '0');
    final file = File('${dir.path}/$reportFilePrefix$digits$reportFileSuffix');
    try {
      await file.create(exclusive: true);
      await file.writeAsString(content, flush: true);
      return file;
    } on FileSystemException {
      index++;
    }
  }
  return null;
}

Future<int> _lastReportIndex(Directory dir) async {
  var last = 0;
  await for (final entity in dir.list()) {
    if (entity is! File) {
      continue;
    }
    final segments = entity.uri.pathSegments;
    if (segments.isEmpty) {
      continue;
    }
    final name = segments.last;
    if (!name.startsWith(reportFilePrefix) ||
        !name.endsWith(reportFileSuffix)) {
      continue;
    }
    final index = int.tryParse(
      name.substring(
        reportFilePrefix.length,
        name.length - reportFileSuffix.length,
      ),
    );
    if (index != null && index > last) {
      last = index;
    }
  }
  return last;
}

String _datetime() {
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
