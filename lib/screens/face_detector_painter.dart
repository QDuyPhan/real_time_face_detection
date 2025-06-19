import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../coordinates_painter.dart';

class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  FaceDetectorPainter({
    required this.faces,
    required this.absoluteImageSize,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.red;

    for (final face in faces) {
      canvas.drawRect(
        _scaleRect(
          rect: face.boundingBox,
          imageSize: absoluteImageSize,
          widgetSize: size,
        ),
        paint,
      );

      // Vẽ các điểm đặc trưng trên khuôn mặt
      _paintContour(canvas, face, paint, size);
    }
  }

  void _paintContour(Canvas canvas, Face face, Paint paint, Size size) {
    final contourTypes = [
      FaceContourType.face,
      FaceContourType.leftEye,
      FaceContourType.rightEye,
      FaceContourType.leftEyebrowTop,
      FaceContourType.leftEyebrowBottom,
      FaceContourType.rightEyebrowTop,
      FaceContourType.rightEyebrowBottom,
      FaceContourType.noseBridge,
      FaceContourType.noseBottom,
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
      FaceContourType.leftCheek,
      FaceContourType.rightCheek,
    ];

    for (final type in contourTypes) {
      final contour = face.contours[type];
      if (contour?.points != null) {
        for (final point in contour!.points) {
          final scaledX = translateX(
            point.x.toDouble(),
            rotation,
            size,
            absoluteImageSize,
          );
          final scaledY = translateY(
            point.y.toDouble(),
            rotation,
            size,
            absoluteImageSize,
          );
          canvas.drawCircle(Offset(scaledX, scaledY), 1.0, paint);
        }
      }
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.rotation != rotation;
  }
}
