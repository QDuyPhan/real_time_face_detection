import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_face.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kiểm tra quyền camera
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
    if (!status.isGranted) {
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Camera permission is required to use this app'),
            ),
          ),
        ),
      );
      return;
    }
  }

  // Khởi tạo RootIsolateToken
  RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
  // Khởi tạo APIFace
  APIFace apiFace = APIFace();
  apiFace.init(rootIsolateToken);
  runApp(
    ChangeNotifierProvider(
      create: (context) => FaceProvider(apiFace),
      child: MyApp(),
    ),
  );
}

class FaceProvider extends ChangeNotifier {
  final APIFace apiFace;
  List<String> detectedFaceIds = [];
  List<String> largestFace = [];
  int faceCount = 0;

  FaceProvider(this.apiFace) {
    // Lắng nghe streamPersonController để cập nhật faceId
    apiFace.streamPersonController.stream.listen((event) {
      if (event is List && event.isNotEmpty && event[0] is String) {
        detectedFaceIds.add(event[0]);
        if (detectedFaceIds.length > 10) {
          detectedFaceIds.removeAt(0); // Giới hạn danh sách để tránh tràn
        }
        faceCount = apiFace.persons.length;
        largestFace = apiFace.findPerson();
        notifyListeners();
      }
    });
  }

  Future<void> startCamera() async {
    await apiFace.start();
    notifyListeners();
  }

  void stopCamera() {
    apiFace.stop();
    detectedFaceIds.clear();
    faceCount = 0;
    largestFace = [];
    notifyListeners();
  }

  bool get cameraState => apiFace.state();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FaceDetectionScreen(),
    );
  }
}

class FaceDetectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final faceProvider = Provider.of<FaceProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Face Detection')),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child:
                  faceProvider.cameraState &&
                          faceProvider.apiFace.camera.controller != null
                      ? Stack(
                        children: [
                          CameraPreview(
                            faceProvider.apiFace.camera.controller!,
                          ),
                          if (faceProvider.faceCount == 0)
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(16),
                                color: Colors.black54,
                                child: Text(
                                  'No face detected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 48,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Camera not started',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
            ),
          ),
          // Face information
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Number of Faces: ${faceProvider.faceCount}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Largest Face ID: ${faceProvider.largestFace.isNotEmpty ? faceProvider.largestFace[0] : "None"}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Detected Face IDs:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child:
                        faceProvider.detectedFaceIds.isEmpty
                            ? Center(
                              child: Text(
                                'No faces detected yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: faceProvider.detectedFaceIds.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  child: ListTile(
                                    leading: Icon(Icons.face),
                                    title: Text(
                                      faceProvider.detectedFaceIds[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
          // Buttons
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      faceProvider.cameraState
                          ? null
                          : () => faceProvider.startCamera(),
                  icon: Icon(Icons.play_arrow),
                  label: Text('Start Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      faceProvider.cameraState
                          ? () => faceProvider.stopCamera()
                          : null,
                  icon: Icon(Icons.stop),
                  label: Text('Stop Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
