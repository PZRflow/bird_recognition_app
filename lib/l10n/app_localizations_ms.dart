// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appTitle => 'ZamZam';

  @override
  String get discoverNature => 'Temui\nAlam Semula Jadi';

  @override
  String get identifyInstantly => 'Kenal pasti bunyi burung serta-merta.';

  @override
  String get recordButton => 'Rakam';

  @override
  String get importButton => 'Import';

  @override
  String get speciesButton => 'Spesies';

  @override
  String get creditsButton => 'Kredit';

  @override
  String topKTitle(int k) {
    return '$k padanan teratas';
  }

  @override
  String confidence(int pct) {
    return '$pct% yakin';
  }

  @override
  String get noSoundDetected => 'Tiada bunyi dikesan --- cuba dekat sedikit.';

  @override
  String get creditsTitle => 'Kredit & Spesies';

  @override
  String get listening => 'Merakam...';

  @override
  String get processing => 'Memproses...';

  @override
  String get errorOccurred => 'Ralat berlaku';

  @override
  String get habitatLabel => 'Habitat';

  @override
  String get dietLabel => 'Diet';

  @override
  String get historyTitle => 'Rekod Detections';

  @override
  String get clearHistoryTitle => 'Padam Rekod';

  @override
  String get clearHistoryConfirm =>
      'Adakah anda pasti mahu memadamkan semua rekod?';

  @override
  String get cancel => 'Batal';

  @override
  String get clear => 'Padam';

  @override
  String get noHistory => 'Tiada rekod lagi. Mula merakam!';

  @override
  String get confidenceLabel => 'Keyakinan';

  @override
  String get settingsTitle => 'Tetapan';

  @override
  String get languageSection => 'Bahasa Antara Muka';

  @override
  String get aiEngineSection => 'Seni Bina AI';

  @override
  String get modelInfoSection => 'Maklumat Model';

  @override
  String get modelType => 'Jenis Model';

  @override
  String get modelFormat => 'Format';

  @override
  String get modelSize => 'Saiz Fail';

  @override
  String get numClasses => 'Spesies';

  @override
  String get sampleRateLabel => 'Kadar Sampel';

  @override
  String get historyButton => 'Rekod';

  @override
  String get settingsButton => 'Tetapan';
}
