import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:real_time_face_detection/app_config.dart';
import 'package:real_time_face_detection/face_detector_painter.dart';

class FaceDetectorController {
  final FaceDetector _faceDetector;
  bool _isProcessing = false;
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? customPaint;
  String? text;

  FaceDetectorController()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableContours: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

  void dispose() {
    _faceDetector.close();
  }

  Uint8List convertYUV420ToNV21Safe(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;

    // Copy Y plane
    int destIndex = 0;
    for (int row = 0; row < height; row++) {
      final int srcIndex = row * yRowStride;
      nv21.setRange(destIndex, destIndex + width, yPlane, srcIndex);
      destIndex += width;
    }

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    // Interleave V and U planes to NV21 format (VU VU VU...)
    int uvStartIndex = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvIndex = row * uvRowStride + col * uvPixelStride;
        nv21[uvStartIndex++] = vPlane[uvIndex]; // V
        nv21[uvStartIndex++] = uPlane[uvIndex]; // U
      }
    }

    return nv21;
  }

  Future<InputImage> processCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    if (_isProcessing) return Future.value(null);
    _isProcessing = true;
    try {
      if (image.format.group != ImageFormatGroup.yuv420) {
        app_config.printLog('e', 'WARNING: CameraImage format is not yuv420!');
        return Future.value(null);
      }

      final nv21 = convertYUV420ToNV21Safe(image);

      InputImageRotation rotation;
      switch (sensorOrientation) {
        case 0:
          rotation = InputImageRotation.rotation0deg;
          break;
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
        default:
          rotation = InputImageRotation.rotation0deg;
      }

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      app_config.printLog("e", "Error processing image: $e");
      return Future.value(null);
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (inputImage == null) return [];
    try {
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        app_config.printLog("i", 'Detected ${faces.length} face(s):');
        for (var i = 0; i < faces.length; i++) {
          final face = faces[i];
          app_config.printLog("i", 'Face $i:');
          app_config.printLog("i", '  Bounding box: ${face.boundingBox}');
          app_config.printLog(
            "i",
            '  Head Euler Angle X: ${face.headEulerAngleX}',
          );
          app_config.printLog(
            "i",
            '  Head Euler Angle Y: ${face.headEulerAngleY}',
          );
          app_config.printLog(
            "i",
            '  Head Euler Angle Z: ${face.headEulerAngleZ}',
          );
          if (face.contours.isNotEmpty) {
            app_config.printLog(
              "i",
              '  Contours detected: ${face.contours.keys.length} types',
            );
          }
        }
      } else {
        app_config.printLog("i", 'No faces detected.');
      }

      return faces;
    } catch (e) {
      app_config.printLog("e", "Error detecting faces: $e");
      return [];
    }
  }

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    text = '';

    final faces = await detectFaces(inputImage);

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
      );
      customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Face found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      this.text = text;
      customPaint = null;
    }
    _isBusy = false;
  }
}
