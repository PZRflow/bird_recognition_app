import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:file_selector/file_selector.dart';
import '../services/audio_recorder_service.dart';
import '../services/database_service.dart';
import '../models/detection.dart';
import 'result_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  bool _isRecording = false;

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      try {
        await _recorderService.startRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    } else {
      final path = await _recorderService.stopRecording();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        _identify(path);
      }
    }
  }

  Future<void> _uploadAudio() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'audio',
      extensions: <String>['mp3', 'wav', 'm4a', 'aac', 'flac'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    
    if (file != null) {
      _identify(file.path);
    }
  }

  void _identify(String path) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(audioPath: path),
      ),
    ).then((prediction) async {
      // Si on revient de ResultScreen avec une prediction (succès de la simulation)
      if (prediction != null) {
        final detection = Detection(
          commonName: prediction.commonName,
          scientificName: prediction.scientificName,
          score: prediction.score,
          description: prediction.description,
          imageUrl: prediction.imageUrl,
          audioPath: path,
          date: DateTime.now(),
        );
        await DatabaseService.instance.create(detection);
      }
    });
  }

  @override
  void dispose() {
    _recorderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BirdSound',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            AvatarGlow(
              animate: _isRecording,
              glowColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(milliseconds: 2000),
              repeat: true,
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 5,
                          )
                        ]
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _isRecording ? "Écoute en cours..." : "Touchez pour identifier",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: TextButton.icon(
                onPressed: _isRecording ? null : _uploadAudio,
                icon: const Icon(Icons.upload_file),
                label: const Text("Importer un fichier audio"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
