import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

class LocalFaceDatabase {
  static Database? _database;
  static const String _tableName = 'registered_faces';

  // Khởi tạo database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'face_recognition.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            face_id TEXT UNIQUE,
            name TEXT NOT NULL,
            phone TEXT,
            face_image TEXT NOT NULL,
            face_features TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      },
    );
  }

  // Tạo hash từ ảnh khuôn mặt để so sánh
  static String _generateImageHash(Uint8List imageData) {
    return sha256.convert(imageData).toString();
  }

  // Tính toán độ tương đồng giữa hai ảnh (đơn giản)
  static double _calculateSimilarity(Uint8List image1, Uint8List image2) {
    if (image1.length != image2.length) return 0.0;

    int differences = 0;
    int totalPixels = image1.length;

    for (int i = 0; i < totalPixels; i++) {
      if ((image1[i] - image2[i]).abs() > 10) {
        differences++;
      }
    }

    return 1.0 - (differences / totalPixels);
  }

  // Đăng ký khuôn mặt mới
  static Future<bool> registerFace({
    required String name,
    required String phone,
    required Uint8List faceImage,
    String? faceId,
  }) async {
    try {
      final db = await database;
      final String imageHash = _generateImageHash(faceImage);
      final String imageBase64 = base64Encode(faceImage);
      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      // Tạo faceId nếu không có
      final String finalFaceId = faceId ?? 'face_${timestamp}_${name.hashCode}';

      await db.insert(_tableName, {
        'face_id': finalFaceId,
        'name': name,
        'phone': phone,
        'face_image': imageBase64,
        'face_features': imageHash,
        'created_at': timestamp,
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return true;
    } catch (e) {
      print('[LocalFaceDatabase] Error registering face: $e');
      return false;
    }
  }

  // Nhận diện khuôn mặt
  static Future<Map<String, dynamic>?> recognizeFace(
    Uint8List faceImage,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> allFaces = await db.query(_tableName);

      double bestSimilarity = 0.0;
      Map<String, dynamic>? bestMatch;

      for (final face in allFaces) {
        final String storedImageBase64 = face['face_image'];
        final Uint8List storedImage = base64Decode(storedImageBase64);

        final double similarity = _calculateSimilarity(faceImage, storedImage);

        if (similarity > bestSimilarity && similarity > 0.7) {
          // Ngưỡng 70%
          bestSimilarity = similarity;
          bestMatch = {
            'face_id': face['face_id'],
            'name': face['name'],
            'phone': face['phone'],
            'similarity': similarity,
          };
        }
      }

      return bestMatch;
    } catch (e) {
      print('[LocalFaceDatabase] Error recognizing face: $e');
      return null;
    }
  }

  // Lấy danh sách tất cả khuôn mặt đã đăng ký
  static Future<List<Map<String, dynamic>>> getAllRegisteredFaces() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> faces = await db.query(
        _tableName,
        orderBy: 'created_at DESC',
      );

      return faces.map((face) {
        return {
          'face_id': face['face_id'],
          'name': face['name'],
          'phone': face['phone'],
          'created_at': face['created_at'],
        };
      }).toList();
    } catch (e) {
      print('[LocalFaceDatabase] Error getting all faces: $e');
      return [];
    }
  }

  // Xóa khuôn mặt theo face_id
  static Future<bool> deleteFace(String faceId) async {
    try {
      final db = await database;
      final int result = await db.delete(
        _tableName,
        where: 'face_id = ?',
        whereArgs: [faceId],
      );
      return result > 0;
    } catch (e) {
      print('[LocalFaceDatabase] Error deleting face: $e');
      return false;
    }
  }

  // Cập nhật thông tin khuôn mặt
  static Future<bool> updateFace({
    required String faceId,
    String? name,
    String? phone,
    Uint8List? faceImage,
  }) async {
    try {
      final db = await database;
      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (faceImage != null) {
        updateData['face_image'] = base64Encode(faceImage);
        updateData['face_features'] = _generateImageHash(faceImage);
      }

      final int result = await db.update(
        _tableName,
        updateData,
        where: 'face_id = ?',
        whereArgs: [faceId],
      );

      return result > 0;
    } catch (e) {
      print('[LocalFaceDatabase] Error updating face: $e');
      return false;
    }
  }

  // Kiểm tra xem khuôn mặt đã tồn tại chưa
  static Future<bool> isFaceRegistered(String faceId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _tableName,
        where: 'face_id = ?',
        whereArgs: [faceId],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('[LocalFaceDatabase] Error checking face existence: $e');
      return false;
    }
  }

  // Đóng database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
