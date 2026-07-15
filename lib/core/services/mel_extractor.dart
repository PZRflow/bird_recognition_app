import 'dart:math' as math;
import 'package:fftea/fftea.dart';
import 'dart:typed_data';

class MelExtractor {
  static const int sampleRate = 16000;
  static const int nFft = 1024;
  static const double fMin = 300.0;
  static const double fMax = 8000.0;

  final int hopLength;
  final int nMels;
  final int winLength;

  final FFT _fft;
  late final Float64List _window;
  late final List<Float64List> _melBank;

  MelExtractor({
    this.hopLength = 512,
    this.nMels = 128,
    this.winLength = 1024,
  }) : _fft = FFT(nFft) {
    _window = _hannWindow(winLength);
    _melBank = _buildMelFilterBank(nFft, nMels, sampleRate, fMin, fMax);
  }

  Float64List _hannWindow(int n) {
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
    }
    return w;
  }

  double _hzToMel(double hz) => 2595.0 * math.log(1.0 + hz / 700.0) / math.ln10;
  double _melToHz(double mel) => 700.0 * (math.pow(10, mel / 2595.0) - 1.0);

  List<Float64List> _buildMelFilterBank(int nFft, int nMels, int sr, double fMin, double fMax) {
    final melBank = List.generate(nMels, (_) => Float64List(nFft ~/ 2 + 1));
    final melMin = _hzToMel(fMin);
    final melMax = _hzToMel(fMax);
    
    final melPoints = Float64List(nMels + 2);
    for (int i = 0; i < nMels + 2; i++) {
      melPoints[i] = melMin + i * (melMax - melMin) / (nMels + 1);
    }
    
    final hzPoints = Float64List(nMels + 2);
    for (int i = 0; i < nMels + 2; i++) {
      hzPoints[i] = _melToHz(melPoints[i]);
    }
    
    final binPoints = Int32List(nMels + 2);
    for (int i = 0; i < nMels + 2; i++) {
      binPoints[i] = (nFft * hzPoints[i] / sr).floor();
    }
    
    for (int m = 0; m < nMels; m++) {
      final left = binPoints[m];
      final center = binPoints[m + 1];
      final right = binPoints[m + 2];
      
      for (int k = left; k < center; k++) {
        melBank[m][k] = (k - left) / (center - left);
      }
      for (int k = center; k < right; k++) {
        melBank[m][k] = (right - k) / (right - center);
      }
    }
    return melBank;
  }

  /// Returns a log-Mel spectrogram as [time][mel] (transposed to match training).
  /// Uses ABSOLUTE dB reference (10 * log10(mel + 1e-10)) matching Python train_local.py.
  /// Output shape: [nFrames][nMels], where nFrames depends on input length.
  List<List<double>> logMel(Float32List pcm) {
    final nFrames = 1 + (pcm.length - nFft) ~/ hopLength;
    
    // Compute mel spectrogram: mel[melBin][frame]
    final mel = List<Float64List>.generate(nMels, (_) => Float64List(nFrames));

    final frame = Float64List(nFft);
    for (int f = 0; f < nFrames; f++) {
      final start = f * hopLength;
      for (int i = 0; i < nFft; i++) {
        if (i < winLength) {
          frame[i] = pcm[start + i] * _window[i];
        } else {
          frame[i] = 0.0;
        }
      }
      
      final spectrum = _fft.realFft(frame);
      for (int m = 0; m < nMels; m++) {
        double energy = 0;
        final row = _melBank[m];
        
        for (int k = 0; k < row.length; k++) {
          final re = spectrum[k].x;
          final im = spectrum[k].y;
          energy += (re * re + im * im) * row[k];
        }
        mel[m][f] = energy;
      }
    }

    // Convert to log dB with ABSOLUTE reference (matches Python: 10 * log10(mel + 1e-10))
    // Then TRANSPOSE to [time][mel] to match training pipeline (logmel.T in Python)
    final logmelTransposed = List<List<double>>.generate(nFrames, (f) {
      return List<double>.generate(nMels, (m) {
        return 10.0 * math.log(mel[m][f] + 1e-10) / math.ln10;
      });
    });
    
    return logmelTransposed;
  }
}
