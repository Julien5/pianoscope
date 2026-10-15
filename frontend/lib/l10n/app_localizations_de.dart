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

  @override
  String get languages => 'Sprachen';

  @override
  String get feedbackTitle => 'Rückmeldung';

  @override
  String get crashReportTitle => 'Absturzberichte';

  @override
  String reportsNotice(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Berichte könnten gesendet werden, um die Anwendung zu verbessern.',
      one:
          'Ein Bericht könnte gesendet werden, um die Anwendung zu verbessern.',
      zero: 'Es konnte kein Bericht gesendet werden.',
    );
    return '$_temp0';
  }

  @override
  String get feedbackEmail => 'Ihre E-Mail-Adresse (optional)';

  @override
  String get feedbackEmailInvalid =>
      'Dies sieht nicht nach einer E-Mail-Adresse aus';

  @override
  String get feedbackMessage => 'Ihre Nachricht';

  @override
  String get feedbackMessageRequired => 'Bitte beschreiben Sie das Problem';

  @override
  String get feedbackMessageHint => 'Beschreiben Sie, was passiert ist';

  @override
  String get feedbackScreenshot =>
      'Einen Screenshot des aktuellen Bildschirms senden';

  @override
  String get feedbackSent => 'Rückmeldung gesendet. Vielen Dank!';

  @override
  String get feedbackQueued =>
      'Rückmeldung gespeichert und später gesendet, sobald der Server erreichbar ist.';

  @override
  String get feedbackNotSaved =>
      'Die Rückmeldung konnte nicht gespeichert werden.';

  @override
  String get feedbackCancel => 'Abbrechen';

  @override
  String uploadingCrashReport(Object index) {
    return 'Absturzbericht #$index wird gesendet…';
  }

  @override
  String uploadingFeedback(Object index) {
    return 'Rückmeldung #$index wird gesendet…';
  }

  @override
  String uploadSummary(Object failed, Object sent) {
    return '$sent gesendet, $failed fehlgeschlagen';
  }

  @override
  String uploadStopped(Object sent) {
    return '$sent gesendet, Upload angehalten';
  }

  @override
  String get feedbackStopped =>
      'Upload angehalten. Die Rückmeldung ist gespeichert und geht mit dem nächsten Stapel raus.';

  @override
  String get feedbackSubmit => 'Senden';

  @override
  String get uploadStop => 'Anhalten';

  @override
  String get feedbackSending => 'Rückmeldung wird gesendet…';
}
