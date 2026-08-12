// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/recognition_service.dart';
import '../credits/credits_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _threshold = RecognitionService.userThreshold;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThreshold = prefs.getDouble('user_threshold') ?? RecognitionService.userThreshold;
    setState(() {
      _threshold = savedThreshold;
      RecognitionService.userThreshold = savedThreshold;
    });
  }

  Future<void> _saveThreshold(double val) async {
    setState(() {
      _threshold = val;
      RecognitionService.userThreshold = val;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_threshold', val);
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1A15), Color(0xFF132B20)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 40),
          children: [
            _buildSectionHeader(context, AppLocalizations.of(context)!.languageSection),
            const SizedBox(height: 8),
            _buildLanguageCard(context, currentLocale),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'DETLECTION CONFIDENCE THRESHOLD'),
            const SizedBox(height: 8),
            _buildThresholdCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader(context, AppLocalizations.of(context)!.aiEngineSection.toUpperCase()),
            const SizedBox(height: 8),
            _buildModelSelectionCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader(context, AppLocalizations.of(context)!.modelInfoSection),
            const SizedBox(height: 8),
            _buildModelInfoCard(context),
            const SizedBox(height: 24),
            _buildCreditsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF2ECC71),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, Locale currentLocale) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF183226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildLanguageOption(context, 'English', const Locale('en'), currentLocale.languageCode == 'en'),
            const Divider(color: Colors.white10, height: 1),
            _buildLanguageOption(context, 'Bahasa Melayu', const Locale('ms'), currentLocale.languageCode == 'ms'),
            const Divider(color: Colors.white10, height: 1),
            _buildLanguageOption(context, 'Français', const Locale('fr'), currentLocale.languageCode == 'fr'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String name, Locale locale, bool isSelected) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFF2ECC71).withValues(alpha: 0.1),
      title: Text(name, style: TextStyle(color: isSelected ? const Color(0xFF2ECC71) : Colors.white, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected 
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71))
          : null,
      onTap: () {
        BirdRecognitionApp.of(context)?.setLocale(locale);
      },
    );
  }

  Widget _buildThresholdCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF183226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Minimum Detection Confidence:',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${(_threshold * 100).toInt()}%',
                  style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Audio predictions below this threshold will be flagged as "Unknown Species" to prevent false positives.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _threshold,
              min: 0.30,
              max: 0.80,
              divisions: 10,
              activeColor: const Color(0xFF2ECC71),
              inactiveColor: Colors.white24,
              onChanged: (val) => _saveThreshold(val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelectionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF183226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFF2ECC71), size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quad-Engine AI Ensemble (90.57% Accuracy)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Combines MynaNet, Compact CNN, EfficientNet-B0, and ResNet34-Lite for maximum accuracy across 27 Malaysian species.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF183226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow(AppLocalizations.of(context)!.modelType, 'Quad-Ensemble (4 AI Networks)'),
          const SizedBox(height: 8),
          _buildInfoRow(AppLocalizations.of(context)!.modelFormat, 'TensorFlow Lite (FP16 PCEN)'),
          const SizedBox(height: 8),
          _buildInfoRow(AppLocalizations.of(context)!.modelSize, '10.3 MB Footprint'),
          const SizedBox(height: 8),
          _buildInfoRow(AppLocalizations.of(context)!.numClasses, '27 Malaysian Species'),
          const SizedBox(height: 8),
          _buildInfoRow('Overall Accuracy', '90.57% Record'),
          const SizedBox(height: 8),
          _buildInfoRow(AppLocalizations.of(context)!.sampleRateLabel, '16 kHz Mono'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2ECC71),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF183226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF2ECC71)),
        title: const Text('Credits & Research Acknowledgments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: const Text('Xeno-canto v3 API, Prof. Munim dataset, Open Source licenses', style: TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreditsScreen()),
          );
        },
      ),
    );
  }
}
