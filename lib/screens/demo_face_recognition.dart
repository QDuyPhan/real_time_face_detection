import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../api_face/api_face.dart';

/// Demo class để test hệ thống nhận diện khuôn mặt
class DemoFaceRecognition {
  late APIFace _apiFace;
  late RootIsolateToken _rootIsolateToken;

  /// Khởi tạo demo
  Future<void> initialize() async {
    _rootIsolateToken = RootIsolateToken.instance!;
    _apiFace = APIFace();
    _apiFace.init(_rootIsolateToken);

    print('[Demo] Face recognition system initialized');
  }

  /// Test đăng ký khuôn mặt
  Future<bool> testRegisterFace(String name, String phone) async {
    try {
      await _apiFace.start();

      print('[Demo] Starting face registration for: $name');

      // Lắng nghe kết quả nhận diện
      bool registered = false;
      _apiFace.streamRecognitionController.stream.listen((data) async {
        if (data['type'] == 'unknown' && !registered) {
          final person = data['person'] as InfoPerson;

          final success = await _apiFace.registerNewFace(
            person.faceId,
            name,
            phone,
          );

          if (success) {
            registered = true;
            _apiFace.stop();
            print('[Demo] ✅ Face registered successfully for: $name');
          } else {
            _apiFace.stop();
            print('[Demo] ❌ Failed to register face for: $name');
          }
        }
      });

      // Timeout sau 10 giây
      await Future.delayed(const Duration(seconds: 10));
      if (!registered) {
        _apiFace.stop();
        print('[Demo] ⏰ Registration timeout for: $name');
        return false;
      }

      return registered;
    } catch (e) {
      print('[Demo] Error during registration: $e');
      return false;
    }
  }

  /// Test nhận diện khuôn mặt
  Future<void> testRecognition() async {
    try {
      await _apiFace.start();

      print('[Demo] Starting face recognition test...');

      _apiFace.streamRecognitionController.stream.listen((data) {
        if (data['type'] == 'recognized') {
          final person = data['person'] as InfoPerson;
          final similarity = data['similarity'];

          print('[Demo] ✅ Recognized: ${person.name} (${person.phone})');
          print(
            '[Demo] 📊 Similarity: ${(similarity * 100).toStringAsFixed(1)}%',
          );
        } else if (data['type'] == 'unknown') {
          print('[Demo] ❓ Unknown face detected');
        }
      });

      // Chạy test trong 30 giây
      await Future.delayed(const Duration(seconds: 30));
      _apiFace.stop();
      print('[Demo] Recognition test completed');
    } catch (e) {
      print('[Demo] Error during recognition: $e');
    }
  }

  /// Test lấy danh sách khuôn mặt
  Future<void> testGetAllFaces() async {
    try {
      final faces = await _apiFace.getAllRegisteredFaces();

      print('[Demo] 📋 Registered faces (${faces.length}):');
      for (final face in faces) {
        print(
          '  - ${face['name']} (${face['phone']}) - ID: ${face['face_id']}',
        );
      }
    } catch (e) {
      print('[Demo] Error getting faces: $e');
    }
  }

  /// Test xóa khuôn mặt
  Future<bool> testDeleteFace(String faceId) async {
    try {
      final success = await _apiFace.deleteRegisteredFace(faceId);

      if (success) {
        print('[Demo] ✅ Face deleted successfully: $faceId');
      } else {
        print('[Demo] ❌ Failed to delete face: $faceId');
      }

      return success;
    } catch (e) {
      print('[Demo] Error deleting face: $e');
      return false;
    }
  }

  /// Chạy tất cả test
  Future<void> runAllTests() async {
    print('[Demo] 🚀 Starting all tests...');

    await initialize();

    // Test 1: Đăng ký khuôn mặt
    print('\n[Demo] Test 1: Face Registration');
    await testRegisterFace('John Doe', '0123456789');

    // Test 2: Lấy danh sách
    print('\n[Demo] Test 2: Get All Faces');
    await testGetAllFaces();

    // Test 3: Nhận diện
    print('\n[Demo] Test 3: Face Recognition');
    await testRecognition();

    print('\n[Demo] 🎉 All tests completed!');
  }

  /// Cleanup
  void dispose() {
    _apiFace.dispose();
    print('[Demo] Demo cleaned up');
  }
}

/// Widget demo để chạy test trong UI
class DemoWidget extends StatefulWidget {
  const DemoWidget({super.key});

  @override
  State<DemoWidget> createState() => _DemoWidgetState();
}

class _DemoWidgetState extends State<DemoWidget> {
  final DemoFaceRecognition _demo = DemoFaceRecognition();
  bool _isRunning = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _demo.initialize();
  }

  Future<void> _runTest(String testName, Future<void> Function() test) async {
    setState(() {
      _isRunning = true;
      _status = 'Running $testName...';
    });

    try {
      await test();
      setState(() {
        _status = '$testName completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRunning ? Colors.orange[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isRunning ? Colors.orange : Colors.green,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isRunning ? Icons.hourglass_empty : Icons.check_circle,
                    color: _isRunning ? Colors.orange : Colors.green,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          _isRunning ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test Buttons
            Expanded(
              child: ListView(
                children: [
                  _buildTestButton(
                    'Register New Face',
                    Icons.person_add,
                    Colors.blue,
                    () => _runTest('Registration', () async {
                      await _demo.testRegisterFace('Test User', '0987654321');
                    }),
                  ),

                  const SizedBox(height: 12),

                  _buildTestButton(
                    'Face Recognition',
                    Icons.face,
                    Colors.green,
                    () => _runTest('Recognition', () async {
                      await _demo.testRecognition();
                    }),
                  ),

                  const SizedBox(height: 12),

                  _buildTestButton(
                    'Get All Faces',
                    Icons.list,
                    Colors.purple,
                    () => _runTest('Get Faces', () async {
                      await _demo.testGetAllFaces();
                    }),
                  ),

                  const SizedBox(height: 12),

                  _buildTestButton(
                    'Run All Tests',
                    Icons.play_arrow,
                    Colors.red,
                    () => _runTest('All Tests', () async {
                      await _demo.runAllTests();
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _isRunning ? null : onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _demo.dispose();
    super.dispose();
  }
}
