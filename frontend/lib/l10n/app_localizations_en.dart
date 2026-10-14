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

  @override
  String get languages => 'Languages';

  @override
  String get feedbackTitle => 'Feedback';

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
  String get feedbackSubmit => 'Send';
}
