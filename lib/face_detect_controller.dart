import 'dart:async';
import 'dart:ui' as imglib;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:real_time_face_detection/app_config.dart';

import 'api_face.dart';
import 'face_detector_painter.dart';
import 'main.dart';

class FaceDetectController extends ChangeNotifier {
  final APIFace _apiFace = APIFace();

  bool _isInitialized = false;
  List<InfoPerson> _detectedPersons = [];
  String _statusText = 'Initializing...';

  List<Face> _currentFaces = [];
  CustomPaint? _customPaint;
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  StreamSubscription? _faceStreamSub;

  // Getters
  bool get isInitialized => _isInitialized;

  List<InfoPerson> get detectedPersons => _detectedPersons;

  String get statusText => _statusText;

  List<Face> get currentFaces => _currentFaces;

  CustomPaint? get customPaint => _customPaint;

  Size? get imageSize => _imageSize;

  InputImageRotation get rotation => _rotation;

  CameraController? get controller => _apiFace.camera.cameraController;

  Future<void> init() async {
    try {
      _statusText = 'Initializing...';
      notifyListeners();

      _apiFace.init(rootIsolateToken!);
      _apiFace.streamPersonController.stream.listen((persons) {
        _detectedPersons = persons;
        _statusText = 'Detected ${persons.length} person(s)';
        notifyListeners();
      });

      _isInitialized = true;
      _statusText = 'Ready - Tap to start detection';
      notifyListeners();
    } catch (e) {
      _statusText = 'Error: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  void _listenFaceStream() {
    _faceStreamSub?.cancel();
    _faceStreamSub = _apiFace.streamFaceController.stream.listen((event) {
      if (event is List && event.length == 4) {
        if (event[0] is List<Face> &&
            event[1] is imglib.Image &&
            event[2] is Size &&
            event[3] is InputImageRotation) {
          List<Face> faces = event[0];
          imglib.Image img = event[1];
          Size size = event[2];
          InputImageRotation rotation = event[3];
          _currentFaces = faces;
          _statusText = 'Processing ${faces.length} face(s)';
          _imageSize = size;
          _rotation = rotation;
          _customPaint = CustomPaint(
            painter: FaceDetectorPainter(faces, size, rotation),
          );
          notifyListeners();
        }
      }
    });
    notifyListeners();
  }

  Future<void> startDetection() async {
    try {
      _customPaint = null;
      _currentFaces = [];
      _imageSize = Size.zero;
      _rotation = InputImageRotation.rotation0deg;
      _statusText = 'Starting detection...';

      await _apiFace.start();

      _listenFaceStream();

      _statusText = 'Detection started';

      notifyListeners();
    } catch (e) {
      _statusText = 'Error starting detection: $e';
      notifyListeners();
    }
  }

  Future<void> stopDetection() async {
    try {
      _apiFace.stop();
      await _faceStreamSub?.cancel();
      _customPaint = null;
      _currentFaces = [];
      _imageSize = Size.zero;
      _rotation = InputImageRotation.rotation0deg;
      _statusText = 'Detection stopped';
      notifyListeners();
    } catch (e) {
      _statusText = 'Error stopping detection: $e';
      notifyListeners();
    }
  }

  void stop() {
    app_config.printLog(
      'i',
      '[Debug face] : FaceDetectController: stop() called',
    );
    _apiFace.stop();
    _faceStreamSub?.cancel();
    _faceStreamSub = null;
    _customPaint = null;
    _currentFaces = [];
    _imageSize = Size.zero;
    _rotation = InputImageRotation.rotation0deg;
    app_config.printLog(
      'i',
      '[Debug face] : FaceDetectController: stop() completed',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    app_config.printLog(
      'i',
      '[Debug face] : FaceDetectController: dispose() called',
    );
    stop();
    super.dispose();
  }
}
