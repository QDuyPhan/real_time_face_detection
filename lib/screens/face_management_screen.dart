import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../api_face/api_face.dart';

class FaceManagementScreen extends StatefulWidget {
  final RootIsolateToken rootIsolateToken;

  const FaceManagementScreen({super.key, required this.rootIsolateToken});

  @override
  State<FaceManagementScreen> createState() => _FaceManagementScreenState();
}

class _FaceManagementScreenState extends State<FaceManagementScreen> {
  late APIFace _apiFace;
  List<Map<String, dynamic>> _registeredFaces = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiFace = APIFace();
    _apiFace.init(widget.rootIsolateToken);
    _loadRegisteredFaces();
  }

  Future<void> _loadRegisteredFaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final faces = await _apiFace.getAllRegisteredFaces();
      setState(() {
        _registeredFaces = faces;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading faces: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _registerNewFace() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Register New Face'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameController.text,
                    'phone': phoneController.text,
                  });
                }
              },
              child: const Text('Register'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _performRegistration(result['name']!, result['phone'] ?? '');
    }
  }

  Future<void> _performRegistration(String name, String phone) async {
    // Bắt đầu camera để chụp ảnh
    await _apiFace.start();

    // Hiển thị dialog chờ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Capturing Face'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Please look at the camera and stay still...'),
            ],
          ),
        );
      },
    );

    // Lắng nghe kết quả nhận diện
    bool registered = false;
    _apiFace.streamRecognitionController.stream.listen((data) async {
      if (data['type'] == 'unknown' && !registered) {
        // Có khuôn mặt mới, thực hiện đăng ký
        final person = data['person'] as InfoPerson;

        final success = await _apiFace.registerNewFace(
          person.faceId,
          name,
          phone,
        );

        if (success) {
          registered = true;
          Navigator.of(context).pop(); // Đóng dialog chờ
          _apiFace.stop();
          _loadRegisteredFaces();
          _showSnackBar('Face registered successfully!');
        } else {
          Navigator.of(context).pop(); // Đóng dialog chờ
          _apiFace.stop();
          _showSnackBar('Failed to register face. Please try again.');
        }
      }
    });

    // Timeout sau 10 giây
    Future.delayed(const Duration(seconds: 10), () {
      if (!registered) {
        Navigator.of(context).pop(); // Đóng dialog chờ
        _apiFace.stop();
        _showSnackBar('Registration timeout. Please try again.');
      }
    });
  }

  Future<void> _deleteFace(String faceId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Face'),
          content: Text('Are you sure you want to delete $name?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final success = await _apiFace.deleteRegisteredFace(faceId);
        if (success) {
          _loadRegisteredFaces();
          _showSnackBar('Face deleted successfully!');
        } else {
          _showSnackBar('Failed to delete face.');
        }
      } catch (e) {
        _showSnackBar('Error deleting face: $e');
      }
    }
  }

  Future<void> _editFace(Map<String, dynamic> face) async {
    final TextEditingController nameController = TextEditingController(
      text: face['name'],
    );
    final TextEditingController phoneController = TextEditingController(
      text: face['phone'] ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Face'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameController.text,
                    'phone': phoneController.text,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final success = await _apiFace.updateRegisteredFace(
          faceId: face['face_id'],
          name: result['name'],
          phone: result['phone'],
        );

        if (success) {
          _loadRegisteredFaces();
          _showSnackBar('Face updated successfully!');
        } else {
          _showSnackBar('Failed to update face.');
        }
      } catch (e) {
        _showSnackBar('Error updating face: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegisteredFaces,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _registeredFaces.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No registered faces',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to register a new face',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _registeredFaces.length,
                itemBuilder: (context, index) {
                  final face = _registeredFaces[index];
                  final createdAt = DateTime.fromMillisecondsSinceEpoch(
                    face['created_at'],
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.face)),
                      title: Text(face['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (face['phone']?.isNotEmpty == true)
                            Text('Phone: ${face['phone']}'),
                          Text(
                            'Registered: ${createdAt.toString().split('.')[0]}',
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editFace(face),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                () =>
                                    _deleteFace(face['face_id'], face['name']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _registerNewFace,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _apiFace.dispose();
    super.dispose();
  }
}
