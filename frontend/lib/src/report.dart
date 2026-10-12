import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'rust/api/init.dart';

const reportDirName = 'reports';

Future<Directory?> reportDirectory() async {
  try {
    final cacheDir = await getApplicationCacheDirectory();
    return Directory('${cacheDir.path}/$reportDirName');
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