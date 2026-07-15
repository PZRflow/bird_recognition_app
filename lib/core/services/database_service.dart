import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/detection_history.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bird_detections.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE detections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            commonName TEXT,
            scientificName TEXT,
            score REAL,
            timestamp TEXT,
            audioPath TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insertDetection(DetectionHistory detection) async {
    final db = await database;
    return await db.insert(
      'detections',
      detection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<DetectionHistory>> getDetections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'detections',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => DetectionHistory.fromMap(maps[i]));
  }

  static Future<int> deleteDetection(int id) async {
    final db = await database;
    return await db.delete(
      'detections',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearDetections() async {
    final db = await database;
    await db.delete('detections');
  }
}
