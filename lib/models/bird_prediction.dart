class BirdPrediction {
  final String commonName;
  final String scientificName;
  final double score;
  final String description;
  final String imageUrl;

  const BirdPrediction({
    required this.commonName,
    required this.scientificName,
    required this.score,
    required this.description,
    required this.imageUrl,
  });
}
