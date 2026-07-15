import 'package:flutter/material.dart';
import '../../core/services/recognition_service.dart';
import '../../core/services/database_service.dart';
import '../../models/bird_prediction.dart';
import '../../models/detection_history.dart';
import 'dart:ui';

class PredictionScreen extends StatefulWidget {
  final String audioPath;
  const PredictionScreen({super.key, required this.audioPath});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final RecognitionService _recognitionService = RecognitionService();
  bool _isLoading = true;
  List<BirdPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _runPrediction();
  }

  Future<void> _runPrediction() async {
    final results = await _recognitionService.predictFromAudio(widget.audioPath);
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _isLoading = false;
    });

    if (results.isNotEmpty && 
        results.first.score >= 0.15 && 
        results.first.commonName != 'Modèle TFLite Absent' &&
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Results (Top 3)', style: TextStyle(color: Colors.white)),
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
            : _predictions.isNotEmpty 
                ? ListView.builder(
                    padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 40),
                    itemCount: _predictions.length,
                    itemBuilder: (context, index) {
                      final pred = _predictions[index];
                      return _buildPredictionCard(pred, index);
                    },
                  )
                : const Center(child: Text('Analysis failed.', style: TextStyle(color: Colors.white))),
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
