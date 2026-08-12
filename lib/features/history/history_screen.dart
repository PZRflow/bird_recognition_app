import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../models/detection_history.dart';
import '../../l10n/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<DetectionHistory> _history = [];
  bool _isLoading = true;
  int? _playingId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state != PlayerState.playing) {
        if (mounted) {
          setState(() {
            _playingId = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseService.getDetections();
    if (mounted) {
      setState(() {
        _history = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _playAudio(int id, String path) async {
    if (_playingId == id) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _playingId = null;
        });
      }
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      if (mounted) {
        setState(() {
          _playingId = id;
        });
      }
    }
  }

  Future<void> _deleteEntry(int id) async {
    await DatabaseService.deleteDetection(id);
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132B20),
        title: Text(AppLocalizations.of(context)!.clearHistoryTitle, style: const TextStyle(color: Colors.white)),
        content: Text(AppLocalizations.of(context)!.clearHistoryConfirm, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.clear, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.clearDetections();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.historyTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: _clearHistory,
              tooltip: AppLocalizations.of(context)!.clearHistoryTitle,
            ),
        ],
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
            : _history.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
                            ),
                            child: const Icon(
                              Icons.history_toggle_off_rounded,
                              size: 64,
                              color: Color(0xFF2ECC71),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(context)!.noHistory,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your recognized bird detections will appear here automatically.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 40),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final dateTime = DateTime.parse(item.timestamp);
                      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            item.commonName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.scientificName,
                                style: const TextStyle(color: Color(0xFF2ECC71), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalizations.of(context)!.confidenceLabel}: ${(item.score * 100).toStringAsFixed(1)}% • $formattedDate',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.audioPath != null)
                                IconButton(
                                  icon: Icon(
                                    _playingId == item.id ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                    color: const Color(0xFF2ECC71),
                                    size: 32,
                                  ),
                                  onPressed: () => _playAudio(item.id!, item.audioPath!),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () => _deleteEntry(item.id!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
