// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get selectClef => 'Changer la clef';

  @override
  String get selectInput => 'Choisir une entrée';

  @override
  String get noteC => 'Do';

  @override
  String get noteD => 'Ré';

  @override
  String get noteE => 'Mi';

  @override
  String get noteF => 'Fa';

  @override
  String get noteG => 'Sol';

  @override
  String get noteA => 'La';

  @override
  String get noteB => 'Si';

  @override
  String get noteSharp => 'dièse';

  @override
  String get noteFlat => 'bémol';

  @override
  String sharp(Object noteName) {
    return '$noteName dièse';
  }

  @override
  String flat(Object noteName) {
    return '$noteName bémol';
  }
}
