import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import '../api_face/api_camera.dart';
import '../api_face/api_face.dart';
import 'face_detector_painter.dart';
import 'face_management_screen.dart';

class CameraScreen extends StatefulWidget {
  final RootIsolateToken rootIsolateToken;

  const CameraScreen({super.key, required this.rootIsolateToken});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late APICamera _apiCamera;
  late APIFace _apiFace;
  bool _isCameraInitialized = false;
  List<Face> _faces = [];
  imglib.Image? _currentImage;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  // Thông tin nhận diện
  String _recognizedName = '';
  String _recognizedPhone = '';
  double _similarity = 0.0;
  bool _isRecognized = false;
  bool _showRecognitionInfo = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _apiCamera = APICamera(CameraLensDirection.front);
    _apiFace = APIFace();

    await _apiCamera.init(widget.rootIsolateToken);
    _apiFace.init(widget.rootIsolateToken);
    await _apiCamera.start();
    await _apiFace.start();

    // Listen to face detection results
    _apiCamera.streamDetectFaceController.stream.listen((data) {
      if (data is List && data.length == 2) {
        setState(() {
          _faces = data[0] as List<Face>;
          _currentImage = data[1] as imglib.Image;
          // Cập nhật góc xoay dựa trên hướng camera
          if (_apiCamera.controller != null) {
            final sensorOrientation =
                _apiCamera.controller!.description.sensorOrientation;
            switch (sensorOrientation) {
              case 0:
                _rotation = InputImageRotation.rotation0deg;
                break;
              case 90:
                _rotation = InputImageRotation.rotation90deg;
                break;
              case 180:
                _rotation = InputImageRotation.rotation180deg;
                break;
              case 270:
                _rotation = InputImageRotation.rotation270deg;
                break;
              default:
                _rotation = InputImageRotation.rotation0deg;
            }
          }
        });
      }
    });

    // Listen to recognition results
    _apiFace.streamRecognitionController.stream.listen((data) {
      if (data['type'] == 'recognized') {
        final person = data['person'] as InfoPerson;
        setState(() {
          _recognizedName = person.name;
          _recognizedPhone = person.phone;
          _similarity = data['similarity'];
          _isRecognized = true;
          _showRecognitionInfo = true;
        });

        // Ẩn thông tin sau 3 giây
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showRecognitionInfo = false;
            });
          }
        });
      } else if (data['type'] == 'unknown') {
        setState(() {
          _isRecognized = false;
          _showRecognitionInfo = true;
        });

        // Ẩn thông tin sau 2 giây
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showRecognitionInfo = false;
            });
          }
        });
      }
    });

    setState(() {
      _isCameraInitialized = true;
    });
  }

  @override
  void dispose() {
    _apiCamera.stop();
    _apiFace.stop();
    _apiFace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => FaceManagementScreen(
                        rootIsolateToken: widget.rootIsolateToken,
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_apiCamera.controller != null)
            CameraPreview(_apiCamera.controller!),

          // Face Detection Overlay
          if (_apiCamera.controller != null)
            CustomPaint(
              painter: FaceDetectorPainter(
                faces: _faces,
                absoluteImageSize: Size(
                  _apiCamera.controller!.value.previewSize!.height,
                  _apiCamera.controller!.value.previewSize!.width,
                ),
                rotation: _rotation,
              ),
              size: Size.infinite,
            ),

          // Recognition Info Overlay
          if (_showRecognitionInfo)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _isRecognized
                          ? Colors.green.withOpacity(0.9)
                          : Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRecognized ? Icons.check_circle : Icons.help,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecognized ? 'Recognized!' : 'Unknown Face',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isRecognized) ...[
                      const SizedBox(height: 4),
                      Text(
                        _recognizedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (_recognizedPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _recognizedPhone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Similarity: ${(_similarity * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Toggle camera direction
          _apiCamera.stop();
          _apiFace.stop();
          _apiCamera = APICamera(
            _apiCamera.controller?.description.lensDirection ==
                    CameraLensDirection.front
                ? CameraLensDirection.back
                : CameraLensDirection.front,
          );
          _apiFace = APIFace();
          _initializeCamera();
        },
        child: const Icon(Icons.flip_camera_ios),
      ),
    );
  }
}
