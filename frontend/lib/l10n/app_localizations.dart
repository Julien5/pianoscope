import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @selectClef.
  ///
  /// In en, this message translates to:
  /// **'Select Clef'**
  String get selectClef;

  /// No description provided for @selectInput.
  ///
  /// In en, this message translates to:
  /// **'Select input'**
  String get selectInput;

  /// No description provided for @noteC.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get noteC;

  /// No description provided for @noteD.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get noteD;

  /// No description provided for @noteE.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get noteE;

  /// No description provided for @noteF.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get noteF;

  /// No description provided for @noteG.
  ///
  /// In en, this message translates to:
  /// **'G'**
  String get noteG;

  /// No description provided for @noteA.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get noteA;

  /// No description provided for @noteB.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get noteB;

  /// No description provided for @noteSharp.
  ///
  /// In en, this message translates to:
  /// **'sharp'**
  String get noteSharp;

  /// No description provided for @noteFlat.
  ///
  /// In en, this message translates to:
  /// **'flat'**
  String get noteFlat;

  /// No description provided for @moveToTrebleClef.
  ///
  /// In en, this message translates to:
  /// **'Treble Clef'**
  String get moveToTrebleClef;

  /// No description provided for @moveToBassClef.
  ///
  /// In en, this message translates to:
  /// **'Bass Clef'**
  String get moveToBassClef;

  /// No description provided for @changeKeySignature.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get changeKeySignature;

  /// No description provided for @sharps.
  ///
  /// In en, this message translates to:
  /// **'Sharps'**
  String get sharps;

  /// No description provided for @flats.
  ///
  /// In en, this message translates to:
  /// **'Flats'**
  String get flats;

  /// No description provided for @cMajor.
  ///
  /// In en, this message translates to:
  /// **'C Major'**
  String get cMajor;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'{noteName} sharp'**
  String sharp(Object noteName);

  /// No description provided for @flat.
  ///
  /// In en, this message translates to:
  /// **'{noteName} flat'**
  String flat(Object noteName);

  /// No description provided for @microphone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphone;

  /// No description provided for @microphoneWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone input'**
  String get microphoneWarningTitle;

  /// No description provided for @microphoneWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'The microphone can only detect one note at a time. Chords will not be recognized. Play single notes for best results.'**
  String get microphoneWarningMessage;

  /// No description provided for @microphoneWarningDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this warning again'**
  String get microphoneWarningDontShowAgain;

  /// No description provided for @microphoneWarningContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get microphoneWarningContinue;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback to the developer'**
  String get sendFeedback;

  /// No description provided for @crashReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get crashReportTitle;

  /// No description provided for @reportsNotice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No report could be sent.} =1{One report could be sent to help improve the application.} other{{count} reports could be sent to help improve the application.}}'**
  String reportsNotice(num count);

  /// No description provided for @feedbackEmail.
  ///
  /// In en, this message translates to:
  /// **'Your email (optional)'**
  String get feedbackEmail;

  /// No description provided for @feedbackEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'This does not look like an email address'**
  String get feedbackEmailInvalid;

  /// No description provided for @feedbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get feedbackMessage;

  /// No description provided for @feedbackMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe the problem'**
  String get feedbackMessageRequired;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Send a screenshot of the current screen'**
  String get feedbackScreenshot;

  /// No description provided for @feedbackSent.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent. Thank you!'**
  String get feedbackSent;

  /// No description provided for @feedbackQueued.
  ///
  /// In en, this message translates to:
  /// **'Feedback saved and sent later, when the server is reachable.'**
  String get feedbackQueued;

  /// No description provided for @feedbackNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Feedback could not be saved.'**
  String get feedbackNotSaved;

  /// No description provided for @feedbackCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get feedbackCancel;

  /// No description provided for @uploadingCrashReport.
  ///
  /// In en, this message translates to:
  /// **'Uploading crash report #{index}…'**
  String uploadingCrashReport(Object index);

  /// No description provided for @uploadingFeedback.
  ///
  /// In en, this message translates to:
  /// **'Uploading feedback #{index}…'**
  String uploadingFeedback(Object index);

  /// No description provided for @uploadSummary.
  ///
  /// In en, this message translates to:
  /// **'{sent} sent, {failed} failed'**
  String uploadSummary(Object failed, Object sent);

  /// No description provided for @uploadStopped.
  ///
  /// In en, this message translates to:
  /// **'{sent} sent, upload stopped'**
  String uploadStopped(Object sent);

  /// No description provided for @feedbackStopped.
  ///
  /// In en, this message translates to:
  /// **'Upload stopped. Your feedback is saved and goes out with the next batch.'**
  String get feedbackStopped;

  /// No description provided for @feedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSubmit;

  /// No description provided for @uploadStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get uploadStop;

  /// No description provided for @feedbackSending.
  ///
  /// In en, this message translates to:
  /// **'Sending feedback…'**
  String get feedbackSending;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
