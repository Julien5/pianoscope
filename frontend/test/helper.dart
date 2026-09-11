import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadFonts() async {
  const fontDir = 'assets/fonts';
  final bravura = ByteData.sublistView(
    await File('$fontDir/Bravura.otf').readAsBytes(),
  );
  final petaluma = ByteData.sublistView(
    await File('$fontDir/Petaluma.otf').readAsBytes(),
  );
  final bravuraLoader = FontLoader('Bravura')..addFont(Future.value(bravura));
  final petalumaLoader = FontLoader('Petaluma')
    ..addFont(Future.value(petaluma));
  await bravuraLoader.load();
  await petalumaLoader.load();
}
