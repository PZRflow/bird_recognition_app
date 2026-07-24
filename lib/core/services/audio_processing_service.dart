import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class AudioProcessingService {
  
  static Future<Float32List> getAudioFloat32(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Audio file not found');
    }
    
    // Create a temporary output file for the converted WAV
    final tempDir = await getTemporaryDirectory();
    final tempOutputPath = '${tempDir.path}/temp_converted_${DateTime.now().millisecondsSinceEpoch}.wav';
    
    // FFmpeg command:
    // -y: overwrite if exists
    // -i "$path": source file (MP3, WAV, etc.)
    // -t 30: limit to the first 30 seconds
    // -ac 1: mono
    // -ar 16000: 16 kHz
    // -acodec pcm_s16le: raw 16-bit PCM
    final command = '-y -i "$path" -t 30 -ac 1 -ar 16000 -acodec pcm_s16le "$tempOutputPath"';
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (returnCode!.isValueSuccess()) {
      final wavFile = File(tempOutputPath);
      final bytes = await wavFile.readAsBytes();
      
      // Clean up
      await wavFile.delete();
      
      // Skip the WAV header (44 bytes) safely to extract 16-bit PCM data
      final headerOffset = bytes.length >= 44 ? 44 : 0;
      final byteData = ByteData.sublistView(bytes, headerOffset);
      final int numSamples = byteData.lengthInBytes ~/ 2;
      final float32List = Float32List(numSamples);
      
      // Normalize between -1.0 and 1.0 (Little Endian PCM)
      for (int i = 0; i < numSamples; i++) {
        final sample = byteData.getInt16(i * 2, Endian.little);
        float32List[i] = sample / 32768.0;
      }
      
      // Apply DSP Bandpass Filter (300 Hz - 5000 Hz) to match Python training
      return applyBandpassFilter(float32List);
    } else {
      throw Exception('Error during FFmpeg conversion');
    }
  }

  /// Applies a 2nd-order Butterworth Bandpass Filter (300 Hz - 8000 Hz) at 16 kHz.
  /// Eliminates wind & low-frequency rumble < 300 Hz while preserving full 8 kHz bioacoustic spectrum.
  static Float32List applyBandpassFilter(Float32List input, {double fLow = 300.0, double fHigh = 8000.0, double fs = 16000.0}) {
    final hp = _BiquadFilter()..setHighPass(fLow, fs, 0.7071);
    final lp = _BiquadFilter()..setLowPass(fHigh, fs, 0.7071);
    final output = Float32List(input.length);
    for (int i = 0; i < input.length; i++) {
      double s = hp.process(input[i].toDouble());
      s = lp.process(s);
      output[i] = s;
    }
    return output;
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

class _BiquadFilter {
  double b0 = 0, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;

  void setHighPass(double fc, double fs, double q) {
    double w0 = 2 * math.pi * fc / fs;
    double cosW0 = math.cos(w0);
    double alpha = math.sin(w0) / (2 * q);

    double a0 = 1 + alpha;
    b0 = ((1 + cosW0) / 2) / a0;
    b1 = (-(1 + cosW0)) / a0;
    b2 = ((1 + cosW0) / 2) / a0;
    a1 = (-2 * cosW0) / a0;
    a2 = (1 - alpha) / a0;
  }

  void setLowPass(double fc, double fs, double q) {
    double w0 = 2 * math.pi * fc / fs;
    double cosW0 = math.cos(w0);
    double alpha = math.sin(w0) / (2 * q);

    double a0 = 1 + alpha;
    b0 = ((1 - cosW0) / 2) / a0;
    b1 = (1 - cosW0) / a0;
    b2 = ((1 - cosW0) / 2) / a0;
    a1 = (-2 * cosW0) / a0;
    a2 = (1 - alpha) / a0;
  }

  double process(double x) {
    double y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}
