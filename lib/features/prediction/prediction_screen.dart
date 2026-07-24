import 'package:flutter/material.dart';
import '../../core/services/recognition_service.dart';
import '../../core/services/database_service.dart';
import '../../models/bird_prediction.dart';
import '../../models/detection_history.dart';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';

class PredictionScreen extends StatefulWidget {
  final String audioPath;
  const PredictionScreen({super.key, required this.audioPath});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final RecognitionService _recognitionService = RecognitionService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  bool _isPlaying = false;
  List<BirdPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _runPrediction();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(widget.audioPath));
    }
  }

  Future<void> _runPrediction() async {
    debugPrint("Starting prediction for: ${widget.audioPath}");
    final results = await _recognitionService.predictFromAudio(widget.audioPath);
    debugPrint("Prediction Results Count: ${results.length}");
    for (var r in results) {
      debugPrint("   -> ${r.commonName} (${(r.score * 100).toStringAsFixed(1)}%)");
    }
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _isLoading = false;
    });

    if (results.isNotEmpty && 
        results.first.score >= 0.60 && 
        results.first.commonName != 'Modèle TFLite Absent' &&
        results.first.commonName != 'Unknown species' &&
        results.first.commonName != 'Espèce inconnue' &&
        results.first.commonName != 'Silence' &&
        results.first.commonName != 'Erreur') {
      try {
        await DatabaseService.insertDetection(
          DetectionHistory(
            commonName: results.first.commonName,
            scientificName: results.first.scientificName,
            score: results.first.score,
            timestamp: DateTime.now().toIso8601String(),
            audioPath: widget.audioPath,
          ),
        );
      } catch (e) {
        // Silent fail
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSilenceOrUnknown = _predictions.isNotEmpty &&
        (_predictions.first.commonName == 'Silence' ||
         _predictions.first.commonName == 'Unknown species' ||
         _predictions.first.commonName == 'Espèce inconnue' ||
         _predictions.first.commonName == 'Modèle TFLite Absent');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Results', style: TextStyle(color: Colors.white)),
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
        child: _isLoading 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  const Text('Analyzing by neural network...', style: TextStyle(color: Colors.white70)),
                ],
              )
            : Column(
                children: [
                  const SizedBox(height: 100),
                  // Audio Playback Bar
                  _buildAudioHeader(),
                  Expanded(
                    child: isSilenceOrUnknown
                        ? _buildSilenceCard(_predictions.first)
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 40),
                            itemCount: _predictions.length,
                            itemBuilder: (context, index) {
                              final pred = _predictions[index];
                              return _buildPredictionCard(pred, index);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAudioHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            onPressed: _toggleAudio,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPlaying ? 'Playing recording...' : 'Listen to submitted audio',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.audioPath.split('/').last,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSilenceCard(BirdPrediction pred) {
    final bool isSilence = pred.commonName == 'Silence';
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSilence ? Icons.volume_off_rounded : Icons.help_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                isSilence ? 'Silence or Ambient Noise' : 'No Bird Call Recognized',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isSilence 
                    ? 'The recording volume is too quiet or contains only ambient background noise.'
                    : 'The audio does not match any of the 20 known bird species with high confidence.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _toggleAudio,
                icon: Icon(_isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_isPlaying ? 'Stop Playback' : 'Listen to Audio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionCard(BirdPrediction pred, int index) {
    final isTop = index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTop 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) 
              : Colors.white.withValues(alpha: 0.1),
          width: isTop ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: pred.imageUrl.startsWith('assets/')
                        ? AssetImage(pred.imageUrl) as ImageProvider
                        : NetworkImage(pred.imageUrl) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pred.commonName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTop)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Best Choice', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pred.scientificName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: pred.score,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              color: isTop ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                              minHeight: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(pred.score * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pred.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
