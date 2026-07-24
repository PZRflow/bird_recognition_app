// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ZamZam';

  @override
  String get discoverNature => 'Découvrez\nla Nature';

  @override
  String get identifyInstantly =>
      'Identifiez les chants d\'oiseaux instantanément.';

  @override
  String get recordButton => 'Enregistrer';

  @override
  String get importButton => 'Importer';

  @override
  String get speciesButton => 'Espèces';

  @override
  String get creditsButton => 'Crédits';

  @override
  String topKTitle(int k) {
    return '$k meilleures correspondances';
  }

  @override
  String confidence(int pct) {
    return 'confiance de $pct%';
  }

  @override
  String get noSoundDetected => 'Aucun son détecté --- rapprochez-vous.';

  @override
  String get creditsTitle => 'Crédits & Espèces';

  @override
  String get listening => 'Écoute...';

  @override
  String get processing => 'Analyse...';

  @override
  String get errorOccurred => 'Une erreur est survenue';

  @override
  String get habitatLabel => 'Habitat';

  @override
  String get dietLabel => 'Alimentation';

  @override
  String get historyTitle => 'Historique des analyses';

  @override
  String get clearHistoryTitle => 'Effacer l\'historique';

  @override
  String get clearHistoryConfirm =>
      'Voulez-vous vraiment effacer tout l\'historique ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get clear => 'Effacer';

  @override
  String get noHistory =>
      'Aucun historique pour le moment. Commencez l\'analyse !';

  @override
  String get confidenceLabel => 'Confiance';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get languageSection => 'Langue de l\'interface';

  @override
  String get aiEngineSection => 'Architecture de l\'IA';

  @override
  String get modelInfoSection => 'Informations sur le modèle';

  @override
  String get modelType => 'Type de modèle';

  @override
  String get modelFormat => 'Format';

  @override
  String get modelSize => 'Taille du fichier';

  @override
  String get numClasses => 'Classes';

  @override
  String get sampleRateLabel => 'Taux d\'échantillonnage';

  @override
  String get historyButton => 'Historique';

  @override
  String get settingsButton => 'Paramètres';
}
