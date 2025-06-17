import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:real_time_face_detection/face_detector_painter.dart';

import 'camera_preview.dart';

class FaceDetectorScreen extends StatefulWidget {
  const FaceDetectorScreen({super.key});

  @override
  State<FaceDetectorScreen> createState() => _FaceDetectorScreenState();
}

class _FaceDetectorScreenState extends State<FaceDetectorScreen> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      // enableLandmarks: true,
      enableContours: true,
      // enableTracking: true,
    ),
  );

  bool _canProcess = true;
  bool _isBysy = false;
  CustomPaint? _customPaint;
  String? _text;

  @override
  Widget build(BuildContext context) {
    return Camerapreview(
      title: 'Face Detector',
      cameraLensDirection: CameraLensDirection.front,
      onImage: (inputImage) {
        processImage(inputImage);
      },
      customPaint: _customPaint,
      text: _text,
    );
  }

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBysy) return;
    _isBysy = true;
    setState(() {
      _text = '';
    });
    final faces = await _faceDetector.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Face found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      _text = text;
      _customPaint = null;
    }
    _isBysy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
