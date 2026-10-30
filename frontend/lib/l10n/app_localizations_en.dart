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
  String get moveToTrebleClef => 'Treble Clef';

  @override
  String get moveToBassClef => 'Bass Clef';

  @override
  String get changeKeySignature => 'Key';

  @override
  String get sharps => 'Sharps';

  @override
  String get flats => 'Flats';

  @override
  String get cMajor => 'C Major';

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

  @override
  String get microphoneWarningTitle => 'Microphone input';

  @override
  String get microphoneWarningMessage =>
      'The microphone can only detect one note at a time. Chords will not be recognized. Play single notes for best results.';

  @override
  String get microphoneWarningDontShowAgain => 'Don\'t show this warning again';

  @override
  String get microphoneWarningContinue => 'Continue';

  @override
  String get languages => 'Languages';

  @override
  String get sendFeedback => 'Feedback to the developer';

  @override
  String get crashReportTitle => 'Crash reports';

  @override
  String reportsNotice(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports could be sent to help improve the application.',
      one: 'One report could be sent to help improve the application.',
      zero: 'No report could be sent.',
    );
    return '$_temp0';
  }

  @override
  String get feedbackEmail => 'Your email (optional)';

  @override
  String get feedbackEmailInvalid => 'This does not look like an email address';

  @override
  String get feedbackMessage => 'Your message';

  @override
  String get feedbackMessageRequired => 'Please describe the problem';

  @override
  String get feedbackMessageHint => 'Tell us what happened';

  @override
  String get feedbackScreenshot => 'Send a screenshot of the current screen';

  @override
  String get feedbackSent => 'Feedback sent. Thank you!';

  @override
  String get feedbackQueued =>
      'Feedback saved and sent later, when the server is reachable.';

  @override
  String get feedbackNotSaved => 'Feedback could not be saved.';

  @override
  String get feedbackCancel => 'Cancel';

  @override
  String uploadingCrashReport(Object index) {
    return 'Uploading crash report #$index…';
  }

  @override
  String uploadingFeedback(Object index) {
    return 'Uploading feedback #$index…';
  }

  @override
  String uploadSummary(Object failed, Object sent) {
    return '$sent sent, $failed failed';
  }

  @override
  String uploadStopped(Object sent) {
    return '$sent sent, upload stopped';
  }

  @override
  String get feedbackStopped =>
      'Upload stopped. Your feedback is saved and goes out with the next batch.';

  @override
  String get feedbackSubmit => 'Send';

  @override
  String get uploadStop => 'Stop';

  @override
  String get feedbackSending => 'Sending feedback…';
}
