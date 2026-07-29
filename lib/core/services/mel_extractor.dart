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
      
      // Slaney area normalization (matches Librosa default norm='slaney')
      final double enorm = (hzPoints[m + 2] > hzPoints[m]) 
          ? 2.0 / (hzPoints[m + 2] - hzPoints[m]) 
          : 1.0;
      
      if (center > left) {
        for (int k = left; k < center; k++) {
          melBank[m][k] = ((k - left) / (center - left)) * enorm;
        }
      }
      if (right > center) {
        for (int k = center; k < right; k++) {
          melBank[m][k] = ((right - k) / (right - center)) * enorm;
        }
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

    // 1. Spectral Noise Equalization (Background Noise Subtraction)
    // Compute median energy per mel channel across frames
    final noiseFloor = Float64List(nMels);
    for (int m = 0; m < nMels; m++) {
      final channelEnergies = List<double>.from(mel[m]);
      channelEnergies.sort();
      final double medianVal = channelEnergies[nFrames ~/ 2];
      noiseFloor[m] = medianVal;
    }

    final melClean = List<Float64List>.generate(nMels, (_) => Float64List(nFrames));
    for (int m = 0; m < nMels; m++) {
      final double sub = 0.8 * noiseFloor[m];
      for (int f = 0; f < nFrames; f++) {
        final double val = mel[m][f] - sub;
        melClean[m][f] = val > 1e-10 ? val : 1e-10;
      }
    }

    // 2. Per-Channel Energy Normalization (PCEN)
    // Formula matches librosa.pcen(mel_clean, sr=16000, time_constant=0.4, gain=0.8, bias=10.0, power=0.25, eps=1e-6)
    const double timeConstant = 0.4;
    const double gain = 0.8;
    const double bias = 10.0;
    const double power = 0.25;
    const double eps = 1e-6;

    final double tFrames = timeConstant * sampleRate / hopLength;
    final double b = (math.sqrt(1.0 + 4.0 * tFrames * tFrames) - 1.0) / (2.0 * tFrames * tFrames);
    final double biasPow = math.pow(bias, power).toDouble();

    final pcen = List<Float64List>.generate(nMels, (_) => Float64List(nFrames));

    for (int m = 0; m < nMels; m++) {
      double smooth = melClean[m][0];
      for (int f = 0; f < nFrames; f++) {
        final double x = melClean[m][f];
        if (f == 0) {
          smooth = x;
        } else {
          smooth = b * x + (1.0 - b) * smooth;
        }

        final double smoothVal = math.exp(-gain * (math.log(eps) + math.log(1.0 + smooth / eps)));
        final double out = biasPow * (math.exp(power * math.log(1.0 + x * smoothVal / bias)) - 1.0);
        pcen[m][f] = out;
      }
    }

    // Transpose to [time][mel] to match model input shape [1, nFrames, nMels, 1] or [1, nMels, nFrames, 1]
    final pcenTransposed = List<List<double>>.generate(nFrames, (f) {
      return List<double>.generate(nMels, (m) {
        return pcen[m][f];
      });
    });

    return pcenTransposed;
  }
}
