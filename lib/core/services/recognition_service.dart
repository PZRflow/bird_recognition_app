import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../models/bird_prediction.dart';
import 'audio_processing_service.dart';
import 'mel_extractor.dart';

class RecognitionService {
  static String activeModel = 'ensemble'; // 'compact_cnn', 'mynanet' or 'ensemble'
  Interpreter? _interpreterCompact;
  Interpreter? _interpreterMyna;
  List<String>? _labels;
  bool _modelNotFound = false;
  List<dynamic>? _speciesProfiles;

  Interpreter? get _interpreter => (activeModel == 'mynanet') ? _interpreterMyna : _interpreterCompact;

  Future<void> _loadModel() async {
    try {
      final needCompact = activeModel == 'compact_cnn' || activeModel == 'ensemble';
      final needMyna = activeModel == 'mynanet' || activeModel == 'ensemble';

      if (needCompact && _interpreterCompact == null) {
        _interpreterCompact = await Interpreter.fromAsset('assets/model/bird_classifier_v2.tflite');
      } else if (!needCompact && _interpreterCompact != null) {
        _interpreterCompact!.close();
        _interpreterCompact = null;
      }

      if (needMyna && _interpreterMyna == null) {
        _interpreterMyna = await Interpreter.fromAsset('assets/model/mynanet_classifier_v2.tflite');
      } else if (!needMyna && _interpreterMyna != null) {
        _interpreterMyna!.close();
        _interpreterMyna = null;
      }

      _modelNotFound = false;
      
      try {
        final labelsData = await rootBundle.loadString('assets/model/labels.txt');
        _labels = labelsData.split('\n').where((s) => s.trim().isNotEmpty).toList();
      } catch (e) {
        _labels = ['Unknown Bird'];
      }
      
      try {
        final profilesData = await rootBundle.loadString('assets/species.json');
        _speciesProfiles = jsonDecode(profilesData);
      } catch (e) {
        _speciesProfiles = [];
      }
      _warmup();
    } catch (e) {
      _modelNotFound = true;
    }
  }

  void _warmup() {
    try {
      if (_interpreterCompact != null && _labels != null) {
        final input = List.generate(
          1,
          (_) => List.generate(
            128,
            (_) => List.generate(128, (_) => -100.0).map((v) => [v]).toList(),
          ),
        );
        var output = List.generate(1, (i) => List.filled(_labels!.length, 0.0));
        _interpreterCompact!.run(input, output);
      }
      if (_interpreterMyna != null && _labels != null) {
        final input = List.generate(
          1,
          (_) => List.generate(
            64,
            (_) => List.generate(300, (_) => 0.0).map((v) => [v]).toList(),
          ),
        );
        var output = List.generate(1, (i) => List.filled(_labels!.length, 0.0));
        _interpreterMyna!.run(input, output);
      }
    } catch (e) {
      // silent fail
    }
  }

  Map<String, String> _getNames(int index, String fallbackLabel) {
    if (_speciesProfiles != null) {
      for (var profile in _speciesProfiles!) {
        if (profile['id'] == index) {
          return {
            'malay': profile['malay'] ?? fallbackLabel,
            'english': profile['english'] ?? fallbackLabel,
            'scientific': profile['scientific'] ?? fallbackLabel,
            'imageUrl': profile['imageUrl'] ?? 'https://images.unsplash.com/photo-1552728089-57168da7c29e?w=800',
          };
        }
      }
    }
    return {
      'malay': fallbackLabel,
      'english': fallbackLabel,
      'scientific': fallbackLabel,
      'imageUrl': 'https://images.unsplash.com/photo-1552728089-57168da7c29e?w=800',
    };
  }

  Future<List<BirdPrediction>> predictFromAudio(String path) async {
    await _loadModel();
    
    if (_modelNotFound) {
      return [const BirdPrediction(
        commonName: 'TFLite Model Missing',
        scientificName: 'Please run the Python pipeline',
        score: 0.0,
        description: 'The bird_classifier.tflite model was not found. You must import it first.',
        imageUrl: 'https://images.unsplash.com/photo-1555169062-0133c8dc7c76?w=800',
      ),];
    }

    if (_interpreter == null || _labels == null || _labels!.isEmpty) {
       return [const BirdPrediction(
         commonName: 'Error',
         scientificName: 'Model not loaded',
         score: 0.0,
         description: 'Unable to load model or labels.',
         imageUrl: 'https://images.unsplash.com/photo-1555169062-0133c8dc7c76?w=800',
       ),];
    }

    // Step 1: Load raw audio as Float32 (mono, 16kHz)
    final Float32List rawAudio = await AudioProcessingService.getAudioFloat32(path);
    const int segmentSize = 48000;
    const int stepSize = 8000; // 0.5s step scan matching Python
    final List<Float32List> segments = [];
    final List<Float32List> rawSegments = [];

    if (rawAudio.length <= segmentSize) {
      final padded = Float32List(segmentSize);
      padded.setRange(0, rawAudio.length, rawAudio);
      segments.add(padded);
      rawSegments.add(padded);
    } else {
      // Energy scan matching Python train_v2 pipeline (Top 5 non-overlapping active chunks)
      final List<Map<String, dynamic>> chunkCandidates = [];
      for (int i = 0; i <= rawAudio.length - segmentSize; i += stepSize) {
        double energy = 0.0;
        for (int j = i; j < i + segmentSize; j++) {
          energy += rawAudio[j] * rawAudio[j];
        }
        chunkCandidates.add({'energy': energy, 'idx': i});
      }
      chunkCandidates.sort((a, b) => (b['energy'] as double).compareTo(a['energy'] as double));
      
      if (chunkCandidates.isNotEmpty) {
        final double maxEnergy = chunkCandidates[0]['energy'];
        final double threshold = maxEnergy * 0.1;
        final List<int> selectedIndices = [];
        
        for (final cand in chunkCandidates) {
          if (selectedIndices.length >= 5) break;
          if ((cand['energy'] as double) < threshold) continue;
          
          final int idx = cand['idx'];
          bool overlap = false;
          for (final sel in selectedIndices) {
            if ((idx - sel).abs() < segmentSize) {
              overlap = true;
              break;
            }
          }
          if (!overlap) {
            selectedIndices.add(idx);
          }
        }
        
        for (final idx in selectedIndices) {
          final seg = Float32List.fromList(rawAudio.sublist(idx, idx + segmentSize));
          segments.add(seg);
          rawSegments.add(Float32List.fromList(rawAudio.sublist(idx, idx + segmentSize)));
        }
      }
    }

    List<double>? bestProbs;
    double maxConfidence = -1.0;
    bool isClipped = false;
    int processedSegments = 0;

    for (int s = 0; s < segments.length; s++) {
      final chunk = segments[s];
      final rawChunk = rawSegments[s];

      // Check for silence (Silence Guard)
      double sumSq = 0.0;
      for (int i = 0; i < chunk.length; i++) {
        sumSq += chunk[i] * chunk[i];
      }
      double rms = sumSq / chunk.length;
      if (rms < 0.0001) {
        continue; // skip silent segments
      }

      // Peak normalize the segment
      double maxAmp = 0.0;
      for (int i = 0; i < chunk.length; i++) {
        final absVal = chunk[i].abs();
        if (absVal > maxAmp) maxAmp = absVal;
      }
      
      // Noise Floor Guard: If peak amplitude is under 0.1% (0.001),
      // it is silence. Do not process empty silence.
      if (maxAmp < 0.001) {
        continue;
      }

      if (maxAmp > 0.0) {
        for (int i = 0; i < chunk.length; i++) {
          chunk[i] /= (maxAmp + 1e-7);
        }
      }

      // Clipping Check on raw chunk (Clipping Guard)
      int clipCount = 0;
      for (int i = 0; i < rawChunk.length; i++) {
        if (rawChunk[i].abs() >= 0.99) {
          clipCount++;
        }
      }
      final bool chunkClipped = (clipCount / rawChunk.length) > 0.01;

      // Run inference on this segment
      List<double> segmentProbs;
      try {
        if (activeModel == 'ensemble') {
          // 1. Run MynaNet
          final melExtractorMyna = MelExtractor(hopLength: 160, nMels: 64, winLength: 400);
          final melMyna = melExtractorMyna.logMel(chunk);
          final tensorMyna = List.generate(
            1,
            (_) => List.generate(
              64,
              (m) => List.generate(300, (t) {
                double val = -100.0;
                if (t < melMyna.length && m < melMyna[t].length) {
                  val = melMyna[t][m];
                }
                double normVal = (val + 100.0) / 100.0;
                if (normVal < 0.0) normVal = 0.0;
                if (normVal > 1.0) normVal = 1.0;
                return normVal;
              }).map((v) => [v]).toList(),
            ),
          );
          var outputMyna = List.generate(1, (i) => List.filled(_labels!.length, 0.0));
          _interpreterMyna!.run(tensorMyna, outputMyna);

          // 2. Run Compact CNN
          final melExtractorCompact = MelExtractor(hopLength: 512, nMels: 128, winLength: 1024);
          final melCompact = melExtractorCompact.logMel(chunk);
          final tensorCompact = List.generate(
            1,
            (_) => List.generate(
              128,
              (t) => List.generate(128, (m) {
                if (t >= melCompact.length) return -100.0;
                if (m >= melCompact[t].length) return -100.0;
                return melCompact[t][m];
              }).map((v) => [v]).toList(),
            ),
          );
          var outputCompact = List.generate(1, (i) => List.filled(_labels!.length, 0.0));
          _interpreterCompact!.run(tensorCompact, outputCompact);

          // 3. Average them (Optimal v2 configuration: 0.4 MynaNet + 0.6 Compact CNN)
          segmentProbs = List.generate(_labels!.length, (idx) {
            return 0.4 * outputMyna[0][idx] + 0.6 * outputCompact[0][idx];
          });
        } else {
          // Standard run
          final bool isMyna = activeModel == 'mynanet';
          final melExtractor = isMyna 
              ? MelExtractor(hopLength: 160, nMels: 64, winLength: 400)
              : MelExtractor(hopLength: 512, nMels: 128, winLength: 1024);
              
          final mel = melExtractor.logMel(chunk);
          final dynamic tensor;
          
          if (isMyna) {
            tensor = List.generate(
              1,
              (_) => List.generate(
                64,
                (m) => List.generate(300, (t) {
                  double val = -100.0;
                  if (t < mel.length && m < mel[t].length) {
                    val = mel[t][m];
                  }
                  double normVal = (val + 100.0) / 100.0;
                  if (normVal < 0.0) normVal = 0.0;
                  if (normVal > 1.0) normVal = 1.0;
                  return normVal;
                }).map((v) => [v]).toList(),
              ),
            );
          } else {
            tensor = List.generate(
              1,
              (_) => List.generate(
                128,
                (t) => List.generate(128, (m) {
                  if (t >= mel.length) return -100.0;
                  if (m >= mel[t].length) return -100.0;
                  return mel[t][m];
                }).map((v) => [v]).toList(),
              ),
            );
          }
          
          var output = List.generate(1, (i) => List.filled(_labels!.length, 0.0));
          _interpreter!.run(tensor, output);
          segmentProbs = output[0];
        }

        processedSegments++;

        // Select the segment that yields the highest maximum prediction confidence (Max Pooling)
        double chunkMaxConf = 0.0;
        for (var score in segmentProbs) {
          if (score > chunkMaxConf) chunkMaxConf = score;
        }

        if (chunkMaxConf > maxConfidence) {
          maxConfidence = chunkMaxConf;
          bestProbs = segmentProbs;
          isClipped = chunkClipped;
        }
      } catch (e) {
        continue;
      }
    }

    if (processedSegments == 0 || bestProbs == null) {
      return [const BirdPrediction(
        commonName: 'Silence',
        scientificName: 'No sound',
        score: 1.0,
        description: 'The volume is too low, it is either silence or the analysis failed.',
        imageUrl: 'https://images.unsplash.com/photo-1555169062-0133c8dc7c76?w=800',
      ),];
    }

    final List<double> finalProbs = bestProbs;

    // Top 3 Logic
    List<Map<String, dynamic>> results = [];
    for (int i = 0; i < finalProbs.length; i++) {
      results.add({
        'index': i,
        'score': finalProbs[i],
      });
    }
    
    results.sort((a, b) => b['score'].compareTo(a['score']));
    
    // Strict Confidence & Out-of-Distribution Rejection Threshold:
    // Require at least 60% (0.60) score to confirm a valid bird call.
    // Human speech, music, or non-bird noises typically yield weak scores (30%-50%) and will be cleanly rejected.
    final double topScore = results[0]['score'];
    final double secondScore = results.length > 1 ? results[1]['score'] : 0.0;
    
    if (topScore < 0.60 || (topScore - secondScore < 0.10 && topScore < 0.70)) {
      return [BirdPrediction(
        commonName: 'Unknown species',
        scientificName: 'Unidentified',
        score: topScore,
        description: 'The audio (speech or ambient noise) does not match any of the 20 known bird species with high confidence.',
        imageUrl: 'https://images.unsplash.com/photo-1555169062-0133c8dc7c76?w=800',
      ),];
    }
    
    List<BirdPrediction> topPredictions = [];
    for (int i = 0; i < 3 && i < results.length; i++) {
      int idx = results[i]['index'];
      String labelName = _labels![idx].replaceAll('_', ' ');
      final names = _getNames(idx, labelName);
      
      final String image = names['imageUrl']!; 
      String description = names['english']!;
      if (isClipped && i == 0) {
        description = "Warning: Signal saturated (too loud). $description";
      }

      topPredictions.add(BirdPrediction(
        commonName: names['malay']!,
        scientificName: names['scientific']!,
        score: results[i]['score'],
        description: description,
        imageUrl: image,
      ),);
    }
    
    return topPredictions;
  }
}
