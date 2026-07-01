import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<void> startRecording() async {
    if (await requestMicrophonePermission()) {
      final Directory tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/bird_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path ?? _recordingPath;
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
