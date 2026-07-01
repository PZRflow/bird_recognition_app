import '../models/bird_prediction.dart';

class RecognitionService {
  Future<BirdPrediction> predictFromAudio(String path) async {
    // Fictional result
    await Future.delayed(const Duration(seconds: 2)); // Simulate ML processing time
    
    return BirdPrediction(
      commonName: 'Coucou koël (Asian Koel)',
      scientificName: 'Eudynamys scolopaceus',
      score: 0.92,
      description: 'Le Coucou koël est un grand coucou d\'Asie et d\'Australasie. Ses appels sonores et résonnants sont familiers dans toute son aire de répartition, en particulier pendant la saison de reproduction.',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Asian_koel_%28Eudynamys_scolopaceus%29_male_2.jpg/800px-Asian_koel_%28Eudynamys_scolopaceus%29_male_2.jpg',
    );
  }
}
