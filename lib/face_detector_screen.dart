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
  ///khởi tạo một đối tượng FaceDetector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      /// Kích hoạt tính năng phân loại cảm xúc hoặc trạng thái khuôn mặt,
      /// chẳng hạn như phát hiện xem người đó đang cười hay nhắm mắt.
      /// Khi được bật, bộ phát hiện sẽ trả về thông tin bổ sung về trạng thái khuôn mặt
      /// (ví dụ: xác suất người đó đang cười).
      enableClassification: true,

      /// Kích hoạt phát hiện các điểm mốc (landmarks) trên khuôn mặt,
      /// chẳng hạn như vị trí của mắt, mũi, miệng, tai, v.v.
      /// Các điểm mốc này là các tọa độ cụ thể trên khuôn mặt,
      /// hữu ích cho các ứng dụng như nhận diện biểu cảm hoặc áp dụng hiệu ứng AR (thực tế tăng cường).
      enableLandmarks: true,

      /// Kích hoạt phát hiện các đường viền (contours) của khuôn mặt.
      /// Đường viền bao gồm các đường bao quanh các đặc điểm khuôn mặt (như viền mắt, viền môi, v.v.),
      /// giúp xác định hình dạng chi tiết của khuôn mặt.
      enableContours: true,

      /// Kích hoạt tính năng theo dõi khuôn mặt qua nhiều khung hình (frame) trong video hoặc luồng trực tiếp.
      /// Khi được bật, bộ phát hiện có thể gán một ID duy nhất cho mỗi khuôn mặt được phát hiện và theo dõi nó liên tục,
      /// thay vì coi mỗi khung hình là độc lập. Điều này hữu ích trong các ứng dụng thời gian thực như bộ lọc video.
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _canProcess = true;
  bool _isBusy = false;
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
    if (_isBusy) return;
    _isBusy = true;
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
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
