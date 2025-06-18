import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'camera_preview2.dart';
import 'face_detect_controller.dart';

class FaceDetectorScreen2 extends StatefulWidget {
  const FaceDetectorScreen2({super.key});

  @override
  State<FaceDetectorScreen2> createState() => _FaceDetectorScreen2State();
}

class _FaceDetectorScreen2State extends State<FaceDetectorScreen2> {
  final FaceDetectorController _faceDetectorController =
      FaceDetectorController();

  @override
  void dispose() {
    _faceDetectorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Camerapreview2(
      title: 'Face Detector',
      cameraLensDirection: CameraLensDirection.front,
      onImage: (inputImage) async {
        await _faceDetectorController.processImage(inputImage);
        setState(() {});
      },
      customPaint: _faceDetectorController.customPaint,
      text: _faceDetectorController.text,
    );
  }
}
