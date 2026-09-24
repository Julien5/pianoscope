// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get selectClef => 'Schlusselauswahl';

  @override
  String get selectInput => 'Eingang';

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
  String get noteB => 'H';

  @override
  String get noteSharp => 'is';

  @override
  String get noteFlat => 'es';

  @override
  String sharp(Object noteName) {
    return '${noteName}is';
  }

  @override
  String flat(Object noteName) {
    return '${noteName}es';
  }

  @override
  String get microphone => 'Mikrofon';
}
