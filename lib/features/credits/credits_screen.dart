import 'package:flutter/material.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Credits & Research', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            _buildCreditCard(
              title: 'Dataset & Audio Providers',
              icon: Icons.graphic_eq_rounded,
              items: [
                'Xeno-canto v3 API (Malaysia Collection - CC BY-NC-SA Licenses)',
                'Prof. Munim\'s MyGardenBird Dataset (Universiti Malaya / Zenodo)',
                'Contributions from global bioacoustic recordists and ornithologists',
              ],
            ),
            const SizedBox(height: 16),
            _buildCreditCard(
              title: 'AI & Machine Learning Architecture',
              icon: Icons.auto_awesome_rounded,
              items: [
                'Quad-Ensemble PCEN Architecture (90.57% Historic Record)',
                'MynaNet (Dense Conv), Compact CNN (4-Block Swish)',
                'EfficientNet-B0 Lite & ResNet34-Lite (FP16 Quantized)',
              ],
            ),
            const SizedBox(height: 16),
            _buildCreditCard(
              title: 'Core Technology Stack',
              icon: Icons.code_rounded,
              items: [
                'Flutter Framework & Dart SDK',
                'TensorFlow Lite Mobile Engine (tflite_flutter)',
                'FFmpegKit Audio Processing & Resampling Engine',
                'Butterworth DSP Bandpass Filter (300-8000 Hz)',
              ],
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'ZamZam Bird Recognition • Version 3.0',
                style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard({required String title, required IconData icon, required List<String> items}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF183226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2ECC71), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
