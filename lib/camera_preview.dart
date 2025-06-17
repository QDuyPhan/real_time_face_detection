import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
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

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
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

  Future<void> _startLive() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
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

  /// Detect faces in the camera image
  Future<void> _processCameraImage(final CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final camera = cameras[_cameraIndex];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    // final planeData = image.planes.map((final Plane plane) {
    //   return InputImagePlaneMetadata(
    //     bytesPerRow: plane.bytesPerRow,
    //
    //   );
    // });
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    widget.onImage(inputImage);
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
