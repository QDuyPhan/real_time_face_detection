import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:real_time_face_detection/app_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _isDetecting = false;
  List<Face> _face = [];
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _requestPermissions();
    _initializeCameras();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _controller?.dispose();
    _faceDetector.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      app_config.printLog('e', 'Permissions Denied');
    }
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        app_config.printLog('e', 'No Cameras Found');
        return;
      }
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }
      await _initializeCamera(cameras[_selectedCameraIndex]);
    } catch (e) {
      app_config.printLog('e', 'Permissions Denied');
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    _initializeControllerFuture = controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _startFaceDetection();
          });
        })
        .catchError((error) {
          app_config.printLog('e', error);
        });
  }

  void _toggleCamera() async {
    if (cameras.isEmpty || cameras.length < 2) {
      app_config.printLog(
        'e',
        'Can not toggle camera. Not enough cameras available',
      );
      return;
    }
  }
}
