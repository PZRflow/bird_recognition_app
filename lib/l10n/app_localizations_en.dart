// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZamZam';

  @override
  String get discoverNature => 'Discover\nNature';

  @override
  String get identifyInstantly => 'Identify bird songs instantly.';

  @override
  String get recordButton => 'Record';

  @override
  String get importButton => 'Import';

  @override
  String get speciesButton => 'Species';

  @override
  String get creditsButton => 'Credits';

  @override
  String topKTitle(int k) {
    return 'Top $k matches';
  }

  @override
  String confidence(int pct) {
    return '$pct% confident';
  }

  @override
  String get noSoundDetected => 'No sound detected --- try closer.';

  @override
  String get creditsTitle => 'Credits & Species';

  @override
  String get listening => 'Listening...';

  @override
  String get processing => 'Processing...';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get habitatLabel => 'Habitat';

  @override
  String get dietLabel => 'Diet';

  @override
  String get historyTitle => 'History of Detections';

  @override
  String get clearHistoryTitle => 'Clear History';

  @override
  String get clearHistoryConfirm =>
      'Are you sure you want to clear all history?';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get noHistory => 'No history yet. Start detecting!';

  @override
  String get confidenceLabel => 'Confidence';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageSection => 'Interface Language';

  @override
  String get aiEngineSection => 'AI Architecture';

  @override
  String get modelInfoSection => 'Model Information';

  @override
  String get modelType => 'Model Type';

  @override
  String get modelFormat => 'Format';

  @override
  String get modelSize => 'File Size';

  @override
  String get numClasses => 'Classes';

  @override
  String get sampleRateLabel => 'Sample Rate';

  @override
  String get historyButton => 'History';

  @override
  String get settingsButton => 'Settings';
}
