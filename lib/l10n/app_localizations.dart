import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ms.dart';

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
    Locale('en'),
    Locale('fr'),
    Locale('ms')
  ];

  /// App name; do not translate.
  ///
  /// In en, this message translates to:
  /// **'ZamZam'**
  String get appTitle;

  /// Hero title on home screen.
  ///
  /// In en, this message translates to:
  /// **'Discover\nNature'**
  String get discoverNature;

  /// Subtitle on home screen.
  ///
  /// In en, this message translates to:
  /// **'Identify bird songs instantly.'**
  String get identifyInstantly;

  /// Main CTA on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordButton;

  /// Secondary CTA on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importButton;

  /// Button to view species list.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get speciesButton;

  /// Button to view credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get creditsButton;

  /// Header above the ranked species list.
  ///
  /// In en, this message translates to:
  /// **'Top {k} matches'**
  String topKTitle(int k);

  /// Confidence badge on each species card.
  ///
  /// In en, this message translates to:
  /// **'{pct}% confident'**
  String confidence(int pct);

  /// Silence guard message.
  ///
  /// In en, this message translates to:
  /// **'No sound detected --- try closer.'**
  String get noSoundDetected;

  /// Title for the credits screen.
  ///
  /// In en, this message translates to:
  /// **'Credits & Species'**
  String get creditsTitle;

  /// Status text while recording.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// Status text while running inference.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// Generic error message.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// Label for habitat section.
  ///
  /// In en, this message translates to:
  /// **'Habitat'**
  String get habitatLabel;

  /// Label for diet section.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get dietLabel;

  /// Title for the history screen.
  ///
  /// In en, this message translates to:
  /// **'History of Detections'**
  String get historyTitle;

  /// Dialog title for clearing history.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistoryTitle;

  /// Dialog text for clearing history confirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history?'**
  String get clearHistoryConfirm;

  /// Cancel button text.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Clear button text.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Message displayed when the history is empty.
  ///
  /// In en, this message translates to:
  /// **'No history yet. Start detecting!'**
  String get noHistory;

  /// Label for confidence metric.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidenceLabel;

  /// Title for the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Header for language selection section.
  ///
  /// In en, this message translates to:
  /// **'Interface Language'**
  String get languageSection;

  /// Header for AI model section.
  ///
  /// In en, this message translates to:
  /// **'AI Architecture'**
  String get aiEngineSection;

  /// Header for model info section.
  ///
  /// In en, this message translates to:
  /// **'Model Information'**
  String get modelInfoSection;

  /// Label for model type info.
  ///
  /// In en, this message translates to:
  /// **'Model Type'**
  String get modelType;

  /// Label for model format info.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get modelFormat;

  /// Label for model file size info.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get modelSize;

  /// Label for number of classes in model.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get numClasses;

  /// Label for target sample rate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get sampleRateLabel;

  /// Button to view history screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyButton;

  /// Button to view settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButton;
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
      <String>['en', 'fr', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ms':
      return AppLocalizationsMs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
