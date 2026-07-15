import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class AudioProcessingService {
  
  static Future<Float32List> getAudioFloat32(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Fichier audio introuvable');
    }
    
    // Création d'un fichier de sortie temporaire pour le WAV converti
    final tempDir = await getTemporaryDirectory();
    final tempOutputPath = '${tempDir.path}/temp_converted_${DateTime.now().millisecondsSinceEpoch}.wav';
    
    // Commande FFmpeg :
    // -y : écraser si existe
    // -i "$path" : fichier source (MP3, WAV, etc.)
    // -t 30 : Limiter aux 30 premières secondes
    // -ac 1 : Mono
    // -ar 16000 : 16 kHz
    // -acodec pcm_s16le : PCM 16-bit Brut
    final command = '-y -i "$path" -t 30 -ac 1 -ar 16000 -acodec pcm_s16le "$tempOutputPath"';
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (returnCode!.isValueSuccess()) {
      final wavFile = File(tempOutputPath);
      final bytes = await wavFile.readAsBytes();
      
      // Nettoyer
      await wavFile.delete();
      
      // On skippe l'en-tête WAV (44 octets) pour récupérer que les données PCM 16 bit
      final int16List = bytes.buffer.asInt16List(44);
      final float32List = Float32List(int16List.length);
      
      // Normalisation entre -1.0 et 1.0
      for (int i = 0; i < int16List.length; i++) {
        float32List[i] = int16List[i] / 32768.0;
      }
      
      return float32List;
    } else {
      throw Exception('Erreur lors de la conversion FFmpeg');
    }
  }

  /// Select the 3-second chunk with the highest energy from the audio,
  /// then apply peak normalization. This matches the Python training pipeline.
  static Float32List selectBestChunk(Float32List audio) {
    const int sampleRate = 16000;
    const int chunkSamples = sampleRate * 3; // 48000 samples = 3 seconds
    const int stepSamples = sampleRate;      // 1 second step

    // Pad if too short
    Float32List padded = audio;
    if (audio.length < chunkSamples) {
      padded = Float32List(chunkSamples);
      for (int i = 0; i < audio.length; i++) {
        padded[i] = audio[i];
      }
      // Rest is already 0.0
    }

    // Find the chunk with the highest energy
    double maxEnergy = -1.0;
    int bestStart = 0;

    for (int i = 0; i <= padded.length - chunkSamples; i += stepSamples) {
      double energy = 0.0;
      for (int j = i; j < i + chunkSamples; j++) {
        energy += padded[j] * padded[j];
      }
      if (energy > maxEnergy) {
        maxEnergy = energy;
        bestStart = i;
      }
    }

    // Extract the best chunk
    final chunk = Float32List(chunkSamples);
    for (int i = 0; i < chunkSamples; i++) {
      chunk[i] = padded[bestStart + i];
    }

    // Peak normalization (match Python: best_chunk / (max_amp + 1e-7))
    double maxAmp = 0.0;
    for (int i = 0; i < chunk.length; i++) {
      final absVal = chunk[i].abs();
      if (absVal > maxAmp) maxAmp = absVal;
    }
    if (maxAmp > 0.0) {
      final scale = 1.0 / (maxAmp + 1e-7);
      for (int i = 0; i < chunk.length; i++) {
        chunk[i] = chunk[i] * scale;
      }
    }

    return chunk;
  }
}
