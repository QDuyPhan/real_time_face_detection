import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:real_time_face_detection/app_config.dart';

@pragma('vm:entry-point')
Future<void> processImage(List<Object> args) async {
  try {
    SendPort sendPort = args[0] as SendPort;
    RootIsolateToken rootIsolateToken = args[1] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

    ReceivePort imagePort = ReceivePort();
    sendPort.send(imagePort.sendPort);

    final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    await for (var message in imagePort) {
      if (message is List) {
        if (message.isNotEmpty && message.length == 3) {
          if (message[0] is CameraImage &&
              message[1] is int &&
              message[2] is SendPort) {
            final CameraImage image = message[0];
            final int sensorOrientation = message[1];
            final SendPort sendMsg = message[2];

            InputImageFormat? inputImageFormat =
                InputImageFormatValue.fromRawValue(image.format.raw);
            if (inputImageFormat == null ||
                (Platform.isAndroid &&
                    inputImageFormat != InputImageFormat.nv21) ||
                (Platform.isIOS &&
                    inputImageFormat != InputImageFormat.bgra8888)) {
              continue;
            }

            if (image.planes.length != 1) {
              continue;
            }

            Plane plane = image.planes.first;

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

            InputImage inputImage = InputImage.fromBytes(
              bytes: plane.bytes,
              metadata: InputImageMetadata(
                size: Size(image.width.toDouble(), image.height.toDouble()),
                format: inputImageFormat,
                bytesPerRow: plane.bytesPerRow,
                rotation: rotation,
              ),
            );

            List<Face> faces = await _faceDetector.processImage(inputImage);
            app_config.printLog('i', '[Debug camera] faces : ${faces.length}');
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
            imglib.Image img = decodeNV21(inputImage);
            sendMsg.send([faces, img]);
          }
        }
      }
    }
  } catch (e) {
    app_config.printLog('e', '[Error Camera] $e');
  }
}

imglib.Image decodeNV21(InputImage image) {
  final width = image.metadata!.size.width.toInt();
  final height = image.metadata!.size.height.toInt();

  Uint8List yuv420sp = image.bytes!;

  final outImg = imglib.Image(width: width, height: height);

  final int frameSize = width * height;

  for (int j = 0, yp = 0; j < height; j++) {
    int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
    for (int i = 0; i < width; i++, yp++) {
      int y = (0xff & yuv420sp[yp]) - 16;
      if (y < 0) y = 0;
      if ((i & 1) == 0) {
        v = (0xff & yuv420sp[uvp++]) - 128;
        u = (0xff & yuv420sp[uvp++]) - 128;
      }
      int y1192 = 1192 * y;
      int r = (y1192 + 1634 * v);
      int g = (y1192 - 833 * v - 400 * u);
      int b = (y1192 + 2066 * u);

      r = r.clamp(0, 262143);
      g = g.clamp(0, 262143);
      b = b.clamp(0, 262143);

      outImg.setPixelRgb(
        i,
        j,
        ((r << 6) & 0xff0000) >> 16,
        ((g >> 2) & 0xff00) >> 8,
        (b >> 10) & 0xff,
      );
    }
  }
  return outImg;
}

class APICamera {
  late CameraLensDirection _initialDirection;
  late List<CameraDescription> _cameras;
  int _camera_index = 0;
  CameraController? controller;
  late Isolate _isolate;
  late SendPort sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _busy = false;
  bool _run = false;
  StreamController streamJpgController = StreamController.broadcast();
  StreamController streamDetectFaceController = StreamController.broadcast();

  APICamera(CameraLensDirection direction) {
    _initialDirection = direction;
  }

  Future<void> init(RootIsolateToken rootIsolateToken) async {
    try {
      ReceivePort myReceivePort = ReceivePort();
      _isolate = await Isolate.spawn(processImage, [
        myReceivePort.sendPort,
        rootIsolateToken,
      ]);
      app_config.printLog('i', '[Debug] * * * * *');
      sendPort = await myReceivePort.first;
      app_config.printLog('i', '[Debug] * * * * * * * * * *');
      _receivePort.listen((message) {
        app_config.printLog('i', '[Debug camera] finish process image');
        if (message is List) {
          app_config.printLog('i', '[Debug camera] finish process image * ');
          if (message.isNotEmpty && message.length == 2) {
            app_config.printLog(
              'i',
              '[Debug camera] finish process image * * ',
            );
            if (message[0] is List<Face> && message[1] is imglib.Image) {
              final List<Face> faces = message[0];

              final imglib.Image img = message[1];
              app_config.printLog('i', '[Debug] size : ${faces.length}');
              streamDetectFaceController.sink.add([faces, img]);
              _busy = false;
            }
          }
        }
      });
      _busy = false;
      _run = false;
    } catch (e) {
      app_config.printLog('e', '[Error Camera] $e');
    }
  }

  Future<void> start() async {
    if (_run == false) {
      try {
        _cameras = await availableCameras();
        _camera_index = 0;
        if (_cameras.any(
          (element) =>
              element.lensDirection == _initialDirection &&
              element.sensorOrientation == 99,
        )) {
          _camera_index = _cameras.indexOf(
            _cameras.firstWhere(
              (element) =>
                  element.lensDirection == _initialDirection &&
                  element.sensorOrientation == 99,
            ),
          );
        } else {
          _camera_index = _cameras.indexOf(
            _cameras.firstWhere(
              (element) => element.lensDirection == _initialDirection,
            ),
          );
        }
        if (_cameras[_camera_index] != null) {
          if (controller != null) {
            await controller!.stopImageStream();
            controller = null;
          }
          controller = CameraController(
            _cameras[_camera_index],
            ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.nv21,
          );
          if (controller != null) {
            try {
              await controller!.initialize();
              await controller!.setExposureMode(ExposureMode.auto);
              await controller!.setFocusMode(FocusMode.auto);

              controller!.startImageStream((value) {
                CameraImage image = value;
                int sensorOrientation =
                    _cameras[_camera_index].sensorOrientation;
                if (_busy == false) {
                  _busy = true;
                  app_config.printLog(
                    'i',
                    '[Debug camera] start process image',
                  );
                  if (sendPort == null) {
                    app_config.printLog(
                      'i',
                      '[Debug camera] start process image * ',
                    );
                  }
                  sendPort.send([
                    image,
                    sensorOrientation,
                    _receivePort.sendPort,
                  ]);
                }
              });
              _run = true;
            } on CameraException catch (e) {
              switch (e.code) {
                case 'CameraAccessDenied':
                  app_config.printLog('i', 'You have denied camera access.');
                  break;
                case 'CameraAccessDeniedWithoutPrompt':
                  app_config.printLog(
                    'i',
                    'Please go to Settings app to enable camera access.',
                  );
                  break;
                case 'CameraAccessRestricted':
                  app_config.printLog('i', 'Camera access is restricted.');
                  break;
                case 'AudioAccessDenied':
                  app_config.printLog('i', 'You have denied audio access.');
                  break;
                case 'AudioAccessDeniedWithoutPrompt':
                  app_config.printLog(
                    'i',
                    'Please go to Settings app to enable audio access.',
                  );
                  break;
                case 'AudioAccessRestricted':
                  app_config.printLog('i', 'Audio access is restricted.');
                  break;
                default:
                  app_config.printLog('e', '$e');
                  break;
              }
            }
          }
        }
      } catch (e) {
        app_config.printLog('e', '[Error Camera] $e');
      }
    }
  }

  Future<void> stop() async {
    if (_run == true) {
      try {
        if (controller != null) {
          await controller!.stopImageStream();
          await controller!.dispose();
          controller = null;
          _run = false;
        }
      } catch (e) {
        app_config.printLog('e', '[Error Camera] $e');
      }
    }
  }

  bool state() {
    return _run;
  }

  imglib.Image convertYUV420(CameraImage cameraImage) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yBuffer = cameraImage.planes[0].bytes;

    final uBuffer = cameraImage.planes[1].bytes;

    final vBuffer = cameraImage.planes[2].bytes;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;

    final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;

    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = imglib.Image(width: imageWidth, height: imageHeight);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);

        final int y = yBuffer[yIndex];

        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        int r = (y + v * 1436 / 1024 - 179).round();
        int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
        int b = (y + u * 1814 / 1024 - 227).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);
        image.setPixelRgba(w, h, r, g, b, 255);
      }
    }
    return image;
  }

  imglib.Image convertBGRA8888(CameraImage image) {
    return imglib.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
    );
  }

  Uint8List convertJPG(imglib.Image image) {
    return Uint8List.fromList(imglib.encodeJpg(image, quality: 90));
  }
}
