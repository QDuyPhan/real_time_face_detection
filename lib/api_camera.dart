import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import 'app_config.dart';

@pragma('vm:entry-point')
Future<void> processImage(List<Object> args) async {
  try {
    SendPort sendPort = args[0] as SendPort;
    RootIsolateToken rootIsolateToken = args[1] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

    ReceivePort imagePort = ReceivePort();
    sendPort.send(imagePort.sendPort);

    app_config.printLog('i', 'ImagePort: $imagePort');

    final FaceDetector faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    await for (var message in imagePort) {
      app_config.printLog('i', '[Isolate] message received: $message');
      if (message is List) {
        app_config.printLog('i', '[Isolate] message length: ${message.length}');
        if (message.isNotEmpty && message.length == 3) {
          if (message[0] is CameraImage &&
              message[1] is int &&
              message[2] is SendPort) {
            final CameraImage image = message[0];
            final int sensorOrientation = message[1];
            final SendPort sendMsg = message[2];

            // Debug log
            app_config.printLog(
              'i',
              'Image format: ${image.format.group}, planes: ${image.planes.length}',
            );

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

            // Xác định định dạng ảnh đầu vào
            final InputImageFormat? inputImageFormat =
                InputImageFormatValue.fromRawValue(image.format.raw);
            if (inputImageFormat == null) {
              app_config.printLog(
                'e',
                '[Error Camera] Unknown raw format: ${image.format.raw}',
              );
              continue;
            }

            // Xử lý Android - YUV420/NV21
            if (Platform.isAndroid &&
                image.format.group == ImageFormatGroup.yuv420) {
              if (image.planes.length < 3) {
                app_config.printLog(
                  'e',
                  '[Error Camera] YUV420 image does not have 3 planes!',
                );
                continue;
              }

              final Uint8List nv21Bytes = convertYUV420ToNV21Safe(image);

              final inputImage = InputImage.fromBytes(
                bytes: nv21Bytes,
                metadata: InputImageMetadata(
                  size: Size(image.width.toDouble(), image.height.toDouble()),
                  format: InputImageFormat.nv21,
                  bytesPerRow: image.planes[0].bytesPerRow,
                  rotation: rotation,
                ),
              );

              final faces = await faceDetector.processImage(inputImage);
              final img = decodeNV21(inputImage);
              sendMsg.send([
                faces,
                img,
                inputImage.metadata!.size,
                inputImage.metadata!.rotation,
              ]);
            }
            // Xử lý iOS - BGRA8888 (1 plane)
            else if (Platform.isIOS &&
                image.format.group == ImageFormatGroup.bgra8888) {
              if (image.planes.length != 1) {
                app_config.printLog(
                  'e',
                  '[Error Camera] BGRA8888 image does not have 1 plane!',
                );
                continue;
              }

              final inputImage = InputImage.fromBytes(
                bytes: image.planes[0].bytes,
                metadata: InputImageMetadata(
                  size: Size(image.width.toDouble(), image.height.toDouble()),
                  format: InputImageFormat.bgra8888,
                  bytesPerRow: image.planes[0].bytesPerRow,
                  rotation: rotation,
                ),
              );

              final faces = await faceDetector.processImage(inputImage);
              final img = convertBGRA8888(image);
              sendMsg.send([
                faces,
                img,
                inputImage.metadata!.size,
                inputImage.metadata!.rotation,
              ]);
            }
          }
        } else {
          app_config.printLog('e', '[Isolate] message format invalid!');
        }
      } else {
        app_config.printLog('e', '[Isolate] message is not a List!');
      }
    }
  } catch (e) {
    app_config.printLog('e', '[Error Camera] $e');
  }
}

imglib.Image convertBGRA8888(CameraImage image) {
  return imglib.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.planes[0].bytes.buffer,
    order: imglib.ChannelOrder.bgra,
    numChannels: 4,
  );
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

  int destIndex = 0;
  for (int row = 0; row < height; row++) {
    final int srcIndex = row * yRowStride;
    nv21.setRange(destIndex, destIndex + width, yPlane, srcIndex);
    destIndex += width;
  }

  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

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

  CameraController? _controller;

  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  bool _busy = false;

  bool _run = false;

  StreamController streamJpgController = StreamController.broadcast();

  StreamController streamDectectFaceController = StreamController.broadcast();

  StreamController streamFacesForUI = StreamController.broadcast();

  CameraController? get cameraController => _controller;

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
      _sendPort = await myReceivePort.first;
      app_config.printLog('i', '[Debug] * * * * * * * * * *');
      _receivePort.listen((message) {
        app_config.printLog('i', '[Debug camera] finish process image');
        if (message is List) {
          app_config.printLog('i', '[Debug camera] finish process image * ');
          if (message.isNotEmpty && message.length == 4) {
            app_config.printLog(
              'i',
              '[Debug camera] finish process image * * ',
            );
            if (message[0] is List<Face> &&
                message[1] is imglib.Image &&
                message[2] is Size &&
                message[3] is InputImageRotation) {
              final List<Face> faces = message[0];

              final imglib.Image img = message[1];
              final Size size = message[2];
              final InputImageRotation rotation = message[3];
              app_config.printLog('i', '[Debug] size : ${faces.length}');
              streamDectectFaceController.sink.add([
                faces,
                img,
                size,
                rotation,
              ]);
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
          if (_controller != null) {
            await _controller!.stopImageStream();
            _controller = null;
          }
          _controller = CameraController(
            _cameras[_camera_index],
            ResolutionPreset.low,
            enableAudio: false,
            imageFormatGroup:
                Platform.isAndroid
                    ? ImageFormatGroup.yuv420
                    : ImageFormatGroup.bgra8888,
          );
          if (_controller != null) {
            try {
              await _controller!.initialize();
              _controller!.startImageStream((value) {
                CameraImage image = value;
                int sensorOrientation =
                    _cameras[_camera_index].sensorOrientation;
                if (_busy == false) {
                  _busy = true;
                  app_config.printLog(
                    'i',
                    '[Debug camera] start process image',
                  );
                  if (_sendPort == null) {
                    app_config.printLog(
                      'i',
                      '[Debug camera] start process image * ',
                    );
                  }
                  _sendPort.send([
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
                  app_config.printLog('e', 'You have denied camera access.');
                  break;
                case 'CameraAccessDeniedWithoutPrompt':
                  // iOS only
                  app_config.printLog(
                    'e',
                    'Please go to Settings app to enable camera access.',
                  );
                  break;
                case 'CameraAccessRestricted':
                  // iOS only
                  app_config.printLog('e', 'Camera access is restricted.');
                  break;
                case 'AudioAccessDenied':
                  app_config.printLog('e', 'You have denied audio access.');
                  break;
                case 'AudioAccessDeniedWithoutPrompt':
                  // iOS only
                  app_config.printLog(
                    'e',
                    'Please go to Settings app to enable audio access.',
                  );
                  break;
                case 'AudioAccessRestricted':
                  // iOS only
                  app_config.printLog('e', 'Audio access is restricted.');
                  break;
                default:
                  app_config.printLog('e', e.toString());
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
    app_config.printLog('i', '[Debug face] : APICamera: stop() called');
    if (_run == true) {
      try {
        if (_controller != null) {
          app_config.printLog(
            'i',
            '[Debug face] : APICamera: stopping image stream and disposing controller',
          );
          await _controller!.stopImageStream();
          await _controller!.dispose();
          _controller = null;
          _run = false;
          app_config.printLog(
            'i',
            '[Debug face] : APICamera: stop() completed successfully',
          );
        } else {
          app_config.printLog(
            'i',
            '[Debug face] : APICamera: stop() - controller was null',
          );
        }
      } catch (e) {
        app_config.printLog('i', '[Debug] : $e');
        app_config.printLog('i', '[Debug face] : APICamera: stop() error: $e');
      }
    } else {
      app_config.printLog(
        'i',
        '[Debug face] : APICamera: stop() - camera was not running (_run = false)',
      );
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

  Uint8List convertJPG(imglib.Image image) {
    return Uint8List.fromList(imglib.encodeJpg(image, quality: 90));
  }
}
