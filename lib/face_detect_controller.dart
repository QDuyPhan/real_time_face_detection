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
  // API giao tiếp với backend nhận diện khuôn mặt
  final APIFace _apiFace = APIFace();

  // ==== Biến trạng thái quản lý vòng đời và UI ====
  bool _isInitialized = false; // Đã khởi tạo controller hay chưa
  bool _isInitializing = false; // Đang trong quá trình khởi tạo
  bool _isDetecting = false; // Đang nhận diện khuôn mặt hay không
  List<InfoPerson> _detectedPersons = []; // Danh sách người đã nhận diện được
  String _statusText = 'Initializing...'; // Trạng thái hiển thị trên UI

  // ==== Biến lưu trữ dữ liệu nhận diện và vẽ bounding box ====
  List<Face> _currentFaces = []; // Danh sách khuôn mặt hiện tại
  CustomPaint? _customPaint; // Widget vẽ bounding box lên camera preview
  Size? _imageSize; // Kích thước ảnh camera
  InputImageRotation _rotation =
      InputImageRotation.rotation0deg; // Góc xoay ảnh

  // ==== Quản lý stream, timer, flag cho mock detection ====
  StreamSubscription?
  _faceStreamSub; // Lắng nghe stream khuôn mặt để vẽ bounding box
  StreamSubscription?
  _personStreamSub; // Lắng nghe stream danh sách người nhận diện
  Timer? _mockDetectionTimer; // Timer giả lập nhận diện khuôn mặt sau 5s
  bool _disposed = false; // Đánh dấu controller đã dispose chưa
  bool _mockDetectionStarted =
      false; // Đảm bảo chỉ mock detection 1 lần cho mỗi lần nhận diện

  // ==== Getter cho các biến trạng thái và dữ liệu ====
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isDetecting => _isDetecting;
  List<InfoPerson> get detectedPersons => _detectedPersons;
  String get statusText => _statusText;
  List<Face> get currentFaces => _currentFaces;
  CustomPaint? get customPaint => _customPaint;
  Size? get imageSize => _imageSize;
  InputImageRotation get rotation => _rotation;
  CameraController? get controller => _apiFace.camera.cameraController;

  // Hàm khởi tạo controller, stream và trạng thái ban đầu
  Future<void> init() async {
    if (_disposed) {
      app_config.printLog(
        'i',
        '[Debug face] : init() cancelled - controller disposed',
      );
      return;
    }

    try {
      _isInitializing = true;
      _statusText = 'Initializing...';
      notifyListeners();

      // Khởi tạo camera và stream nhận diện
      _apiFace.init(rootIsolateToken!);

      // Lắng nghe stream danh sách khuôn mặt nhận diện được
      _personStreamSub = _apiFace.streamPersonController.stream.listen((
        persons,
      ) {
        if (_disposed) return;

        _detectedPersons = persons;
        _statusText = 'Detected ${persons.length} person(s)';

        // Khi có khuôn mặt, bắt đầu mock detection (giả lập API nhận diện sau 5s)
        if (persons.isNotEmpty && _isDetecting) {
          _startMockDetection();
        } else if (persons.isEmpty) {
          _mockDetectionStarted = false; // reset flag nếu không còn ai
        }

        notifyListeners();
      });

      _isInitialized = true;
      _isInitializing = false;
      _statusText = 'Ready - Tap to start detection';
      notifyListeners();

      app_config.printLog('i', '[Debug face] : init() completed successfully');
    } catch (e) {
      if (_disposed) return;

      _statusText = 'Error: $e';
      _isInitialized = false;
      _isInitializing = false;
      notifyListeners();
      app_config.printLog('e', '[Debug face] : init() error: $e');
    }
  }

  // Hàm giả lập API nhận diện khuôn mặt sau 5 giây (dùng cho demo/test)
  void _startMockDetection() {
    if (_mockDetectionStarted) return;
    _mockDetectionStarted = true;
    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed || !_isDetecting) return;

      app_config.printLog(
        'i',
        '[Debug face] : Mock detection completed - stopping detection',
      );
      _statusText = 'Face recognition completed!';
      notifyListeners();

      // Dừng camera và nhận diện sau khi nhận diện thành công
      stopDetection();
      _mockDetectionStarted = false; // reset flag cho lần sau
    });
  }

  // Lắng nghe stream khuôn mặt để cập nhật bounding box overlay
  void _listenFaceStream() {
    app_config.printLog(
      'i',
      '[BoundingBox Debug] _listenFaceStream() subscribed',
    );
    _faceStreamSub?.cancel();
    _faceStreamSub = _apiFace.streamFaceController.stream.listen((event) {
      app_config.printLog(
        'i',
        '[BoundingBox Debug] Controller: received event: type=${event.runtimeType}, value=$event',
      ); // Log toàn bộ event nhận được
      if (_disposed) return;

      if (event is List && event.length == 4) {
        if (event[0] is List<Face> &&
            event[1] is imglib.Image &&
            event[2] is Size &&
            event[3] is InputImageRotation) {
          List<Face> faces = event[0];
          imglib.Image img = event[1];
          Size size = event[2];
          InputImageRotation rotation = event[3];
          // Log debug để kiểm tra dữ liệu truyền vào FaceDetectorPainter
          app_config.printLog(
            'i',
            '[BoundingBox Debug] faces: ${faces.length}, size: ${size.width}x${size.height}, rotation: ${rotation.index}',
          );
          _currentFaces = faces;
          _statusText = 'Processing ${faces.length} face(s)';
          _imageSize = size;
          _rotation = rotation;
          // Sử dụng FaceDetectorPainter để vẽ bounding box lên camera preview
          _customPaint = CustomPaint(
            painter: FaceDetectorPainter(faces, size, rotation),
          );
          app_config.printLog(
            'i',
            '[BoundingBox Debug] Controller: set customPaint, faces=${faces.length}',
          );
          notifyListeners();
        }
      }
    });
    notifyListeners();
  }

  // Bắt đầu quá trình nhận diện khuôn mặt
  Future<void> startDetection() async {
    if (_disposed) {
      app_config.printLog(
        'i',
        '[Debug face] : startDetection() cancelled - controller disposed',
      );
      return;
    }

    try {
      _customPaint = null;
      _currentFaces = [];
      _imageSize = Size.zero;
      _rotation = InputImageRotation.rotation0deg;
      _statusText = 'Starting detection...';
      _isDetecting = true;
      notifyListeners();

      await _apiFace.start();
      _listenFaceStream(); // Đảm bảo luôn lắng nghe stream để vẽ bounding box
      app_config.printLog(
        'i',
        '[BoundingBox Debug] _listenFaceStream() called in startDetection',
      );

      _statusText = 'Detection started - Waiting for face recognition...';
      notifyListeners();

      app_config.printLog('i', '[Debug face] : startDetection() completed');
    } catch (e) {
      if (_disposed) return;

      _statusText = 'Error starting detection: $e';
      _isDetecting = false;
      notifyListeners();
      app_config.printLog('e', '[Debug face] : startDetection() error: $e');
    }
  }

  // Dừng quá trình nhận diện khuôn mặt và dọn dẹp tài nguyên liên quan
  Future<void> stopDetection() async {
    if (_disposed) return; // Prevent further actions if disposed
    try {
      _isDetecting = false;
      _mockDetectionTimer?.cancel();
      _mockDetectionStarted = false;
      _apiFace.stop();
      await _faceStreamSub?.cancel();
      _faceStreamSub = null; // Nullify after cancel
      _customPaint = null;
      _currentFaces = [];
      _imageSize = Size.zero;
      _rotation = InputImageRotation.rotation0deg;
      _statusText = 'Detection stopped';
      notifyListeners();

      app_config.printLog('i', '[Debug face] : stopDetection() completed');
    } catch (e) {
      if (_disposed) return;

      _statusText = 'Error stopping detection: $e';
      notifyListeners();
      app_config.printLog('e', '[Debug face] : stopDetection() error: $e');
    }
  }

  // Dừng toàn bộ quá trình nhận diện, hủy stream, reset trạng thái
  void stop() {
    if (_disposed) return; // Prevent further actions if disposed
    app_config.printLog(
      'i',
      '[Debug face] : FaceDetectController: stop() called',
    );
    _isDetecting = false;
    _mockDetectionTimer?.cancel();
    _mockDetectionStarted = false;
    _apiFace.stop();
    _faceStreamSub?.cancel();
    _personStreamSub?.cancel();
    _faceStreamSub = null;
    _personStreamSub = null;
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

  // Hủy quá trình khởi tạo nếu đang khởi tạo
  void cancelInitialization() {
    if (_isInitializing) {
      app_config.printLog('i', '[Debug face] : cancelInitialization() called');
      _isInitializing = false;
      _isInitialized = false;
      _statusText = 'Initialization cancelled';
      notifyListeners();
    }
  }

  // Hàm dọn dẹp tài nguyên khi controller bị dispose (bắt buộc của ChangeNotifier)
  @override
  void dispose() {
    app_config.printLog(
      'i',
      '[Debug face] : FaceDetectController: dispose() called',
    );
    _disposed = true;
    _mockDetectionTimer?.cancel();
    _mockDetectionStarted = false;
    _faceStreamSub?.cancel();
    _personStreamSub?.cancel();
    _faceStreamSub = null;
    _personStreamSub = null;
    _customPaint = null;
    _currentFaces = [];
    _imageSize = Size.zero;
    _rotation = InputImageRotation.rotation0deg;
    super.dispose();
  }
}
