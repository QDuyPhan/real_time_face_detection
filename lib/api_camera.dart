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

    // Tạo ReceivePort để nhận dữ liệu từ main isolate
    ReceivePort imagePort = ReceivePort();
    // Gửi SendPort của isolate này về main isolate
    sendPort.send(imagePort.sendPort);

    final FaceDetector faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        //Bật phát hiện đường viền khuôn mặt.
        enableClassification: true,
        //Bật phân loại (ví dụ: xác định cảm xúc hoặc trạng thái mắt).
        enableTracking: true,
        //Bật theo dõi khuôn mặt qua các frame.
        performanceMode:
            FaceDetectorMode
                .accurate, //Chọn chế độ chính xác cao (thay vì nhanh).
      ),
    );

    //Xử lý dữ liệu hình ảnh
    await for (var message in imagePort) {
      app_config.printLog(
        'i',
        '[Isolate] message received: '
            '[33m$message[0m',
      );
      if (message is List) {
        app_config.printLog(
          'i',
          '[Isolate] message length: [36m${message.length}[0m',
        );
        if (message.isNotEmpty && message.length == 3) {
          if (message[0] is CameraImage &&
              message[1] is int &&
              message[2] is SendPort) {
            final CameraImage image = message[0];
            final int sensorOrientation = message[1];
            final SendPort sendMsg = message[2];

            // Kiểm tra số lượng planes
            if (image.planes.length < 3) {
              app_config.printLog(
                'e',
                '[Error Camera] CameraImage does not have 3 planes!',
              );
              continue;
            }
            // Kiểm tra format
            if (image.format.group != ImageFormatGroup.yuv420) {
              app_config.printLog(
                'e',
                '[Error Camera] CameraImage format is not yuv420!',
              );
              continue;
            }

            // Chuyển sensorOrientation thành InputImageRotation
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

            // Chuyển CameraImage (3 planes) sang NV21 đúng chuẩn
            Uint8List nv21Bytes = convertYUV420ToNV21Safe(image);
            InputImage inputImage = InputImage.fromBytes(
              bytes: nv21Bytes,
              metadata: InputImageMetadata(
                size: Size(image.width.toDouble(), image.height.toDouble()),
                format: InputImageFormat.nv21,
                bytesPerRow: image.planes[0].bytesPerRow,
                rotation: rotation,
              ),
            );

            List<Face> faces = await faceDetector.processImage(inputImage);
            app_config.printLog(
              'i',
              '[Debug camera] faces : [32m${faces.length}[0m',
            );
            imglib.Image img = decodeNV21(inputImage);
            sendMsg.send([
              faces,
              img,
              inputImage.metadata!.size,
              inputImage.metadata!.rotation,
            ]);
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

///Trả về đối tượng imglib.Image chứa hình ảnh đã được chuyển đổi NV21 sang định dạng RGB.
///Bạn nên dùng decodeNV21(...) khi:
/// Đã có dữ liệu ảnh dạng NV21 (Uint8List) – thường sau khi dùng convertYUV420(...).
/// Muốn hiển thị ảnh hoặc debug trên màn hình.
/// Không cần gọi model nữa mà chỉ cần xử lý RGB
/// dùng để gửi ảnh về server
imglib.Image decodeNV21(InputImage image) {
  final width = image.metadata!.size.width.toInt();
  final height = image.metadata!.size.height.toInt();

  Uint8List yuv420sp = image.bytes!;

  ///Tạo một đối tượng hình ảnh mới với kích thước tương ứng để lưu kết quả RGB.
  final outImg = imglib.Image(width: width, height: height);

  ///Kênh Y (luma) chứa thông tin độ sáng, chiếm width * height byte.
  ///Tính kích thước của kênh Y.
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
  ///Lưu hướng ban đầu của camera (ví dụ: front hoặc back), được khởi tạo sau khi gọi constructor.
  late CameraLensDirection _initialDirection;

  ///Danh sách các camera khả dụng trên thiết bị, được khởi tạo sau.
  late List<CameraDescription> _cameras;

  ///Chỉ số camera hiện tại (mặc định là 0).
  int _camera_index = 0;

  ///Đối tượng điều khiển camera (tùy chọn, có thể là null nếu chưa khởi tạo).
  CameraController? controller;

  late Isolate _isolate;
  late SendPort sendPort;
  final ReceivePort _receivePort = ReceivePort();

  ///Cờ trạng thái để kiểm tra xem camera có đang bận không.
  bool _busy = false;

  ///Cờ trạng thái để kiểm tra xem camera có đang chạy không.
  bool _run = false;

  ///Bộ điều khiển luồng để phát dữ liệu hình ảnh JPEG tới các subscriber.
  StreamController streamJpgController = StreamController.broadcast();

  ///Bộ điều khiển luồng để phát dữ liệu phát hiện khuôn mặt tới các subscriber.
  StreamController streamDectectFaceController = StreamController.broadcast();

  ///Bộ điều khiển luồng để gửi thông tin faces lên UI để vẽ bounding box.
  StreamController streamFacesForUI = StreamController.broadcast();

  APICamera(CameraLensDirection direction) {
    _initialDirection = direction;
  }

  Future<void> init(RootIsolateToken rootIsolateToken) async {
    try {
      ///Tạo một cổng nhận để nhận thông điệp từ isolate nền khi nó khởi động.
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
          if (message.isNotEmpty && message.length == 4) {
            app_config.printLog(
              'i',
              '[Debug camera] finish process image * * ',
            );
            if (message[0] is List<Face> &&
                message[1] is imglib.Image &&
                message[2] is Size &&
                message[3] is InputImageRotation) {
              ///Lấy danh sách khuôn mặt được phát hiện.
              final List<Face> faces = message[0];

              ///Lấy hình ảnh đã xử lý.
              final imglib.Image img = message[1];
              final Size size = message[2];
              final InputImageRotation rotation = message[3];
              app_config.printLog(
                'i',
                '[Debug] size : [32m${faces.length}[0m',
              );
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
          if (controller != null) {
            await controller!.stopImageStream();
            controller = null;
          }
          controller = CameraController(
            _cameras[_camera_index],
            ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );
          if (controller != null) {
            try {
              await controller!.initialize();
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
    if (_run == true) {
      try {
        if (controller != null) {
          await controller!.stopImageStream();
          await controller!.dispose();
          controller = null;
          _run = false;
        }
      } catch (e) {
        app_config.printLog('i', '[Debug] : $e');
      }
    }
  }

  bool state() {
    return _run;
  }

  /// YUV420 thành ảnh RGB
  /// Chuyển CameraImage từ định dạng YUV420 sang ảnh imglib.Image (dùng để vẽ, lưu, nhận diện, v.v.).
  /// Cần hiển thị ảnh hoặc debug pixel
  imglib.Image convertYUV420(CameraImage cameraImage) {
    /// Lấy chiều rộng và chiều cao của hình ảnh từ cameraImage.
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    /// Plane Y (độ sáng), chứa dữ liệu cho mỗi pixel.
    final yBuffer = cameraImage.planes[0].bytes;

    /// Plane U (chrominance, màu xanh), có kích thước nhỏ hơn (thường là width/2 * height/2).
    final uBuffer = cameraImage.planes[1].bytes;

    /// Plane V (chrominance, màu đỏ), kích thước tương tự U.
    final vBuffer = cameraImage.planes[2].bytes;

    /// Số byte trên mỗi hàng của plane Y. Thường bằng width, nhưng có thể lớn hơn nếu có padding.
    final int yRowStride = cameraImage.planes[0].bytesPerRow;

    /// Số byte cho mỗi pixel trong plane Y (thường là 1, vì Y là 8-bit grayscale).
    final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

    /// Số byte trên mỗi hàng của plane U/V.
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;

    /// Số byte cho mỗi pixel trong plane U/V (thường là 1).
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    /// Khởi tạo một đối tượng imglib.Image với kích thước giống CameraImage.
    /// imglib.Image là một lớp từ thư viện image (package image trong Dart), lưu trữ hình ảnh dưới dạng pixel RGBA.
    /// Khi khởi tạo, hình ảnh chưa có dữ liệu pixel (tất cả pixel mặc định là trong suốt hoặc đen).
    final image = imglib.Image(width: imageWidth, height: imageHeight);

    /// Lặp qua các pixel để tính giá trị RGB
    for (int h = 0; h < imageHeight; h++) {
      /// Vì U/V được lấy mẫu (subsampled) với độ phân giải giảm một nửa theo chiều dọc, mỗi giá trị U/V áp dụng cho 2 pixel theo chiều cao.
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        /// Tương tự, U/V giảm một nửa theo chiều ngang.
        int uvw = (w / 2).floor();

        /// Xác định vị trí byte của pixel (w, h) trong yBuffer.
        final yIndex = (h * yRowStride) + (w * yPixelStride);

        /// Lấy giá trị Y (độ sáng) tại vị trí này, nằm trong khoảng [0, 255].
        final int y = yBuffer[yIndex];

        /// Xác định vị trí byte của giá trị U/V cho pixel (w, h).
        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        /// Lấy giá trị U, V, cũng nằm trong khoảng [0, 255].
        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        /// Chuyển đổi YUV sang RGB
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
