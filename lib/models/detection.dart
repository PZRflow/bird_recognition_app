class Detection {
  final int? id;
  final String commonName;
  final String scientificName;
  final double score;
  final String description;
  final String imageUrl;
  final String audioPath;
  final DateTime date;

  Detection({
    this.id,
    required this.commonName,
    required this.scientificName,
    required this.score,
    required this.description,
    required this.imageUrl,
    required this.audioPath,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'score': score,
      'description': description,
      'imageUrl': imageUrl,
      'audioPath': audioPath,
      'date': date.toIso8601String(),
    };
  }

  factory Detection.fromMap(Map<String, dynamic> map) {
    return Detection(
      id: map['id'],
      commonName: map['commonName'],
      scientificName: map['scientificName'],
      score: map['score'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      audioPath: map['audioPath'],
      date: DateTime.parse(map['date']),
    );
  }
}
