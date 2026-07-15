// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/recognition_service.dart';
import 'dart:ui';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
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
            _buildSectionHeader(context, "Active model / modèle actif".toUpperCase()),
            const SizedBox(height: 8),
            _buildModelSelectionCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader(context, AppLocalizations.of(context)!.modelInfoSection),
            const SizedBox(height: 8),
            _buildModelInfoCard(context),
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String name, Locale locale, bool isSelected) {
    return ListTile(
      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: isSelected 
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        BirdRecognitionApp.of(context)?.setLocale(locale);
      },
    );
  }

  Widget _buildModelSelectionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text('Compact CNN', style: TextStyle(color: Colors.white, fontSize: 16)),
                subtitle: const Text('Standard Model (128x128)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: 'compact_cnn',
                groupValue: RecognitionService.activeModel,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      RecognitionService.activeModel = val;
                    });
                  }
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              RadioListTile<String>(
                title: const Text('MynaNet', style: TextStyle(color: Colors.white, fontSize: 16)),
                subtitle: const Text('Specialized Inverted Residuals (64x300)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: 'mynanet',
                groupValue: RecognitionService.activeModel,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      RecognitionService.activeModel = val;
                    });
                  }
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              RadioListTile<String>(
                title: const Text('Ensemble (MynaNet + CNN)', style: TextStyle(color: Colors.white, fontSize: 16)),
                subtitle: const Text('Combines both models for maximum accuracy (81.29%)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: 'ensemble',
                groupValue: RecognitionService.activeModel,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      RecognitionService.activeModel = val;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelInfoCard(BuildContext context) {
    final String modelTypeVal;
    final String modelSizeVal;
    final String inputShapeVal;
    
    if (RecognitionService.activeModel == 'ensemble') {
      modelTypeVal = 'Ensemble (MynaNet + CNN)';
      modelSizeVal = '758 KB';
      inputShapeVal = 'Multi-input';
    } else if (RecognitionService.activeModel == 'mynanet') {
      modelTypeVal = 'MynaNet (MBV3-SE)';
      modelSizeVal = '267 KB';
      inputShapeVal = '[1, 64, 300, 1]';
    } else {
      modelTypeVal = 'Compact CNN';
      modelSizeVal = '491 KB';
      inputShapeVal = '[1, 128, 128, 1]';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              _buildInfoRow(AppLocalizations.of(context)!.modelType, modelTypeVal),
              const SizedBox(height: 12),
              _buildInfoRow(AppLocalizations.of(context)!.modelFormat, 'TensorFlow Lite (FP16)'),
              const SizedBox(height: 12),
              _buildInfoRow(AppLocalizations.of(context)!.modelSize, modelSizeVal),
              const SizedBox(height: 12),
              _buildInfoRow(AppLocalizations.of(context)!.numClasses, '20 species'),
              const SizedBox(height: 12),
              _buildInfoRow('Input shape', inputShapeVal),
              const SizedBox(height: 12),
              _buildInfoRow(AppLocalizations.of(context)!.sampleRateLabel, '16 kHz Mono'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
