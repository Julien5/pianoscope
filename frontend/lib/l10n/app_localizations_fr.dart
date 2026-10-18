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
  String get selectInput => 'Microphone/MIDI';

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
  String get moveToTrebleClef => 'Clé de sol';

  @override
  String get moveToBassClef => 'Clé de fa';

  @override
  String get changeKeySignature => 'Tonalité';

  @override
  String get sharps => 'Dièse';

  @override
  String get flats => 'Bémol';

  @override
  String get cMajor => 'Do majeur';

  @override
  String sharp(Object noteName) {
    return '$noteName dièse';
  }

  @override
  String flat(Object noteName) {
    return '$noteName bémol';
  }

  @override
  String get microphone => 'Microphone';

  @override
  String get languages => 'Langues';

  @override
  String get sendFeedback => 'Contacter le développeur';

  @override
  String get crashReportTitle => 'Rapports de plantage';

  @override
  String reportsNotice(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rapports pourraient être envoyés pour améliorer l\'application.',
      one: 'Un rapport pourrait être envoyé pour améliorer l\'application.',
      zero: 'Aucun rapport de plantage ne pourrait être envoyé.',
    );
    return '$_temp0';
  }

  @override
  String get feedbackEmail => 'Votre adresse e-mail (facultatif)';

  @override
  String get feedbackEmailInvalid =>
      'Cela ne ressemble pas à une adresse e-mail';

  @override
  String get feedbackMessage => 'Votre message';

  @override
  String get feedbackMessageRequired => 'Veuillez décrire le problème';

  @override
  String get feedbackMessageHint => 'Dites-nous ce qui s\'est passé';

  @override
  String get feedbackScreenshot =>
      'Envoyer une capture d\'écran de l\'écran actuel';

  @override
  String get feedbackSent => 'Retour envoyé. Merci !';

  @override
  String get feedbackQueued =>
      'Retour enregistré et envoyé plus tard, dès que le serveur est joignable.';

  @override
  String get feedbackNotSaved => 'Le retour n\'a pas pu être enregistré.';

  @override
  String get feedbackCancel => 'Annuler';

  @override
  String uploadingCrashReport(Object index) {
    return 'Envoi du rapport de plantage n°$index…';
  }

  @override
  String uploadingFeedback(Object index) {
    return 'Envoi du retour n°$index…';
  }

  @override
  String uploadSummary(Object failed, Object sent) {
    return '$sent envoyés, $failed en échec';
  }

  @override
  String uploadStopped(Object sent) {
    return '$sent envoyés, envoi arrêté';
  }

  @override
  String get feedbackStopped =>
      'Envoi arrêté. Votre retour est enregistré et partira avec le prochain lot.';

  @override
  String get feedbackSubmit => 'Envoyer';

  @override
  String get uploadStop => 'Arrêter';

  @override
  String get feedbackSending => 'Envoi du retour…';
}
