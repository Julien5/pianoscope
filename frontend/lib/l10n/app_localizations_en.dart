// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get selectClef => 'Select Clef';

  @override
  String get selectInput => 'Select input';

  @override
  String get noteC => 'C';

  @override
  String get noteD => 'D';

  @override
  String get noteE => 'E';

  @override
  String get noteF => 'F';

  @override
  String get noteG => 'G';

  @override
  String get noteA => 'A';

  @override
  String get noteB => 'B';

  @override
  String get noteSharp => 'sharp';

  @override
  String get noteFlat => 'flat';

  @override
  String sharp(Object noteName) {
    return '$noteName sharp';
  }

  @override
  String flat(Object noteName) {
    return '$noteName flat';
  }

  @override
  String get microphone => 'Microphone';
}
