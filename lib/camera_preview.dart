import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:real_time_face_detection/app_config.dart';
import 'package:real_time_face_detection/main.dart';
import 'package:real_time_face_detection/screen_model.dart';

class Camerapreview extends StatefulWidget {
  final String? text;
  final CustomPaint? customPaint;
  final String? title;
  final Function(InputImage inputIamge) onImage;
  final CameraLensDirection cameraLensDirection;

  const Camerapreview({
    super.key,
    this.text,
    this.customPaint,
    this.title,
    required this.onImage,
    required this.cameraLensDirection,
  });

  @override
  State<Camerapreview> createState() => _CamerapreviewState();
}

class _CamerapreviewState extends State<Camerapreview> {
  ScreenModel _model = ScreenModel.live;
  CameraController? _controller;
  File? _image;
  String? _path;
  ImagePicker? _picker;
  int _cameraIndex = 0;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  final bool _allowPicker = true;
  bool _chagingCameraLens = false;
  bool _isProcessing = false;
  FaceDetector? _faceDetector;

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );
    if (cameras.any(
      (element) =>
          element.lensDirection == widget.cameraLensDirection &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere(
          (element) =>
              element.lensDirection == widget.cameraLensDirection &&
              element.sensorOrientation == 90,
        ),
      );
    } else {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere(
          (element) => element.lensDirection == widget.cameraLensDirection,
        ),
      );
    }
    _startLive();
  }

  @override
  void dispose() {
    _faceDetector?.close();
    _stopLive();
    super.dispose();
  }

  Future<void> _startLive() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
        // minZoomLevel = value;
      });
      _controller?.getMinZoomLevel().then((value) {
        // maxZoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
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

  void _processCameraImage(final CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      if (image.format.group != ImageFormatGroup.yuv420) {
        app_config.printLog('e', 'WARNING: CameraImage format is not yuv420!');
        return;
      }

      final nv21 = convertYUV420ToNV21Safe(image);

      InputImageRotation rotation;
      switch (_controller!.description.sensorOrientation) {
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

      final inputImage = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // Nhận diện khuôn mặt trên main isolate
      final faces = await _faceDetector!.processImage(inputImage);

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

      // Gọi callback nếu cần
      widget.onImage(inputImage);
    } catch (e) {
      app_config.printLog("e", "Error processing image: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
        actions: [
          if (_allowPicker)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: _switchScreenMode,
                child: Icon(
                  _model == ScreenModel.live
                      ? Icons.photo_library_rounded
                      : (Platform.isIOS
                          ? Icons.camera_alt_outlined
                          : Icons.camera),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
      floatingActionButton: _floatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget? _floatingActionButton() {
    if (_model == ScreenModel.gallery) return null;
    if (cameras.length == 1) return null;
    return SizedBox(
      height: 70,
      width: 70,
      child: FloatingActionButton(
        onPressed: _switcherCamera,
        child: Icon(
          Platform.isIOS
              ? Icons.flip_camera_ios_outlined
              : Icons.flip_camera_android_outlined,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _switcherCamera() async {
    setState(() => _chagingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;
    await _stopLive();
    await _startLive();
    setState(() => _chagingCameraLens = false);
  }

  Widget _body() {
    Widget body;
    if (_model == ScreenModel.live) {
      body = _liveBody();
    } else {
      body = _galleryBody();
    }
    return body;
  }

  Widget _liveBody() {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child:
                  _chagingCameraLens
                      ? const Center(child: Text('Changing camera lens'))
                      : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
          // Positioned(
          //   bottom: 100,
          //   left: 50,
          //   right: 50,
          //   child: Slider(
          //     value: zoomLevel,
          //     min: minZoomLevel,
          //     max: maxZoomLevel,
          //     onChanged: (value) {
          //       setState(() {
          //         zoomLevel = value;
          //         _controller?.setZoomLevel(zoomLevel);
          //       });
          //     },
          //     divisions:
          //         (maxZoomLevel - 1).toInt() < 1
          //             ? null
          //             : (maxZoomLevel - 1).toInt(),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _galleryBody() {
    return ListView(
      shrinkWrap: true,
      children: [
        _image != null
            ? SizedBox(
              height: 400,
              width: 400,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_image!),
                  if (widget.customPaint != null) widget.customPaint!,
                ],
              ),
            )
            : Icon(Icons.image, size: 200),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: () => _getImage(ImageSource.gallery),
            child: const Text('From Gallery'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: () => _getImage(ImageSource.camera),
            child: Text('Take a picture'),
          ),
        ),
        if (_image != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_path == null ? '' : 'image path: $_path'}\n\n${widget.text ?? ""} ',
            ),
          ),
      ],
    );
  }

  Future<void> _getImage(ImageSource source) async {
    setState(() {
      _path = null;
      _image = null;
    });
    final pickedFile = await _picker?.pickImage(source: source);
    if (pickedFile != null) {
      _processPickedFile(pickedFile);
    }
    setState(() {});
  }

  Future<void> _processPickedFile(XFile pickedFile) async {
    final path = pickedFile.path;
    if (path == null) {
      return;
    }
    setState(() {
      _image = File(path);
    });
    _path = path;
    final inputImage = InputImage.fromFilePath(path);
    widget.onImage(inputImage);
  }

  void _switchScreenMode() {
    _image = null;
    if (_model == ScreenModel.live) {
      _model = ScreenModel.gallery;
      _stopLive();
    } else {
      _model = ScreenModel.live;
      _startLive();
    }
    setState(() {});
  }

  Future<void> _stopLive() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}
