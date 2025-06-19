import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import 'api_face.dart';
import 'face_detector_painter.dart';
import 'main.dart';

class AdvancedFaceDetectorScreen extends StatefulWidget {
  const AdvancedFaceDetectorScreen({super.key});

  @override
  State<AdvancedFaceDetectorScreen> createState() =>
      _AdvancedFaceDetectorScreenState();
}

class _AdvancedFaceDetectorScreenState
    extends State<AdvancedFaceDetectorScreen> {
  late APIFace _apiFace;
  bool _isInitialized = false;
  List<InfoPerson> _detectedPersons = [];
  String _statusText = 'Initializing...';

  // Camera controller
  CameraController? _controller;
  int _cameraIndex = 0;

  // Face detection và painting
  List<Face> _currentFaces = [];
  CustomPaint? _customPaint;
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetection();
  }

  Future<void> _initializeFaceDetection() async {
    try {
      _apiFace = APIFace();
      _apiFace.init(rootIsolateToken!);

      // Lắng nghe stream từ API Face để cập nhật UI
      _apiFace.streamPersonController.stream.listen((persons) {
        if (persons is List<InfoPerson>) {
          setState(() {
            _detectedPersons = persons;
            _statusText = 'Detected ${persons.length} person(s)';
          });
        }
      });

      // Lắng nghe stream face detection để cập nhật painter
      _apiFace.streamFaceController.stream.listen((event) {
        if (event is List && event.length == 4) {
          if (event[0] is List<Face> &&
              event[1] is imglib.Image &&
              event[2] is Size &&
              event[3] is InputImageRotation) {
            List<Face> faces = event[0];
            imglib.Image img = event[1];
            Size size = event[2];
            InputImageRotation rotation = event[3];
            setState(() {
              _currentFaces = faces;
              _statusText = 'Processing ${faces.length} face(s)';
              _imageSize = size;
              _rotation = rotation;
              _customPaint = CustomPaint(
                painter: FaceDetectorPainter(faces, size, rotation),
              );
            });
          }
        }
      });

      setState(() {
        _isInitialized = true;
        _statusText = 'Ready - Tap to start detection';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _apiFace.stop();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      // Tìm camera front
      if (cameras.any(
        (element) =>
            element.lensDirection == CameraLensDirection.front &&
            element.sensorOrientation == 90,
      )) {
        _cameraIndex = cameras.indexOf(
          cameras.firstWhere(
            (element) =>
                element.lensDirection == CameraLensDirection.front &&
                element.sensorOrientation == 90,
          ),
        );
      } else {
        _cameraIndex = cameras.indexOf(
          cameras.firstWhere(
            (element) => element.lensDirection == CameraLensDirection.front,
          ),
        );
      }

      final camera = cameras[_cameraIndex];
      _controller = CameraController(
        camera,
        ResolutionPreset.low, // Sử dụng resolution thấp để tối ưu hiệu suất
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.nv21, // Sử dụng format tương thích với api_camera
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error starting camera: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Face Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $_statusText',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Camera: ${_controller?.value.isInitialized == true ? "Running" : "Stopped"}',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        _controller?.value.isInitialized == true
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
                Text(
                  'Faces detected: ${_currentFaces.length}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isInitialized ? _startDetection : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isInitialized ? _stopDetection : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Camera preview with face detection overlay
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    _controller?.value.isInitialized == true
                        ? _buildCameraPreview()
                        : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Camera not started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
            ),
          ),

          // Detected persons list
          Expanded(
            flex: 1,
            child:
                _detectedPersons.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.face, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No faces detected',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Detected Persons (${_detectedPersons.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _detectedPersons.length,
                              itemBuilder: (context, index) {
                                final person = _detectedPersons[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading:
                                        person.image.isNotEmpty
                                            ? Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey[300]!,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  person.image,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                            : Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.face,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    title: Text(
                                      'Face ID: ${person.faceId}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Position: (${person.x.toStringAsFixed(1)}, ${person.y.toStringAsFixed(1)})',
                                        ),
                                        Text(
                                          'Size: ${person.w.toStringAsFixed(1)} x ${person.h.toStringAsFixed(1)}',
                                        ),
                                        if (person.name.isNotEmpty)
                                          Text(
                                            'Name: ${person.name}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        if (person.phone.isNotEmpty)
                                          Text(
                                            'Phone: ${person.phone}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            person.busy
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
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
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),
          if (_customPaint != null) _customPaint!,
        ],
      ),
    );
  }

  Future<void> _startDetection() async {
    try {
      // Khởi động camera trước
      await _startCamera();

      // Sau đó khởi động face detection
      await _apiFace.start();

      setState(() {
        _statusText = 'Detection started';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error starting detection: $e';
      });
    }
  }

  Future<void> _stopDetection() async {
    try {
      _apiFace.stop();
      await _controller?.dispose();
      _controller = null;

      setState(() {
        _statusText = 'Detection stopped';
        _currentFaces = [];
        _customPaint = null;
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error stopping detection: $e';
      });
    }
  }
}
