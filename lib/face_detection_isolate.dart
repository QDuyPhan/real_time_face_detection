import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:real_time_face_detection/app_config.dart';

class FaceDetectionIsolate {
  static Future<FaceDetector> initialize() async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );
    return faceDetector;
  }

  static Future<List<Face>> detectFaces(
    Uint8List imageData,
    int width,
    int height,
    int rotation,
    int format,
    int bytesPerRow,
  ) async {
    final faceDetector = await initialize();

    final inputImage = InputImage.fromBytes(
      bytes: imageData,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation:
            InputImageRotationValue.fromRawValue(rotation) ??
            InputImageRotation.rotation0deg,
        format:
            InputImageFormatValue.fromRawValue(format) ?? InputImageFormat.nv21,
        bytesPerRow: bytesPerRow,
      ),
    );

    try {
      final faces = await faceDetector.processImage(inputImage);
      app_config.printLog("d", "Detected ${faces.length} faces in isolate");
      return faces;
    } catch (e) {
      app_config.printLog("e", "Error detecting faces in isolate: $e");
      return [];
    } finally {
      faceDetector.close();
    }
  }
}

// Isolate entry point
void isolateEntryPoint(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is Map<String, dynamic>) {
      final result = await FaceDetectionIsolate.detectFaces(
        message['imageData'] as Uint8List,
        message['width'] as int,
        message['height'] as int,
        message['rotation'] as int,
        message['format'] as int,
        message['bytesPerRow'] as int,
      );
      final SendPort responsePort = message['responsePort'] as SendPort;
      responsePort.send(result);
    }
  });
}
