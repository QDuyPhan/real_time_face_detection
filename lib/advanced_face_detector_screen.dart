import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:real_time_face_detection/app_config.dart';

import 'api_face.dart';
import 'face_detect_controller.dart';

class AdvancedFaceDetectorScreen extends StatefulWidget {
  const AdvancedFaceDetectorScreen({super.key});

  @override
  State<AdvancedFaceDetectorScreen> createState() =>
      _AdvancedFaceDetectorScreenState();
}

class _AdvancedFaceDetectorScreenState extends State<AdvancedFaceDetectorScreen>
    with WidgetsBindingObserver {
  FaceDetectController?
  _controller; // Lưu reference controller để tránh lỗi context khi dispose

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lưu lại reference controller để dùng trong dispose, tránh lỗi context khi widget bị dispose
    _controller ??= Provider.of<FaceDetectController>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tự động khởi tạo và bắt đầu nhận diện khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = _controller ?? context.read<FaceDetectController>();
        if (!controller.isInitialized && !controller.isInitializing) {
          _autoStartDetection(controller);
        }
      }
    });
  }

  // Hàm tự động khởi tạo và bắt đầu nhận diện camera khi mở màn hình
  Future<void> _autoStartDetection(FaceDetectController controller) async {
    try {
      app_config.printLog('i', '[Debug face] : Auto-starting detection...');
      // Khởi tạo controller (camera, stream, ...)
      await controller.init();
      // Chờ một chút để đảm bảo khởi tạo hoàn tất
      await Future.delayed(const Duration(milliseconds: 500));
      // Nếu vẫn mounted và đã khởi tạo xong thì tự động bắt đầu nhận diện
      if (mounted && controller.isInitialized) {
        await controller.startDetection();
        app_config.printLog(
          'i',
          '[Debug face] : Auto-detection started successfully',
        );
      }
    } catch (e) {
      app_config.printLog('e', '[Debug face] : Auto-start detection error: $e');
    }
  }

  @override
  void dispose() {
    app_config.printLog(
      'i',
      '[Debug face] : AdvancedFaceDetectorScreen: dispose() called',
    );
    WidgetsBinding.instance.removeObserver(this);
    // Cleanup: dừng camera, hủy khởi tạo nếu còn đang chạy
    _controller?.cancelInitialization();
    _controller?.stopDetection();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Khi app chuyển trạng thái (pause, inactive, ...), dừng camera và nhận diện
    final controller = context.read<FaceDetectController>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        app_config.printLog(
          'i',
          '[Debug face] : App lifecycle state changed to $state - stopping detection',
        );
        if (controller.isInitializing) {
          controller.cancelInitialization();
        }
        controller.stopDetection();
        break;
      case AppLifecycleState.resumed:
        app_config.printLog(
          'i',
          '[Debug face] : App resumed - detection remains stopped for safety',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        app_config.printLog(
          'i',
          '[Debug face] : WillPopScope triggered - stopping detection',
        );
        final controller = context.read<FaceDetectController>();
        if (controller.isInitializing) {
          controller.cancelInitialization();
        }
        controller.stopDetection();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Advanced Face Detection'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              app_config.printLog(
                'i',
                '[Debug face] : Back button pressed - stopping detection',
              );
              final controller = context.read<FaceDetectController>();
              if (controller.isInitializing) {
                controller.cancelInitialization();
              }
              controller.stopDetection();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            // Status section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Selector<FaceDetectController, String>(
                    selector: (context, controller) => controller.statusText,
                    builder: (context, statusText, child) {
                      return Text(
                        'Status: $statusText',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Selector<FaceDetectController, bool>(
                    selector:
                        (context, controller) => controller.isInitializing,
                    builder: (context, isInitializing, child) {
                      if (isInitializing) {
                        return Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Auto-initializing camera and face detection...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                context
                                    .read<FaceDetectController>()
                                    .cancelInitialization();
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Selector<FaceDetectController, bool>(
                    selector:
                        (context, controller) =>
                            controller.controller?.value.isInitialized == true,
                    builder: (context, isInitialized, child) {
                      return Text(
                        'Camera: ${isInitialized ? "Running" : "Stopped"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isInitialized ? Colors.green : Colors.red,
                        ),
                      );
                    },
                  ),
                  Selector<FaceDetectController, int>(
                    selector:
                        (context, controller) => controller.currentFaces.length,
                    builder: (context, faceCount, child) {
                      return Text(
                        'Faces detected: $faceCount',
                        style: const TextStyle(fontSize: 14),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Selector<FaceDetectController, (bool, bool, bool)>(
                    selector:
                        (context, controller) => (
                          controller.isInitialized,
                          controller.isDetecting,
                          controller.isInitializing,
                        ),
                    builder: (context, data, child) {
                      final isInitialized = data.$1;
                      final isDetecting = data.$2;
                      final isInitializing = data.$3;

                      // Chỉ hiển thị nút Start nếu đã khởi tạo nhưng chưa nhận diện
                      if (isInitialized && !isDetecting && !isInitializing) {
                        return ElevatedButton.icon(
                          onPressed:
                              () =>
                                  context
                                      .read<FaceDetectController>()
                                      .startDetection(),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Restart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        );
                      }

                      // Hiển thị loading khi đang khởi tạo
                      if (isInitializing) {
                        return Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Auto-starting...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }

                      // Không hiển thị gì nếu đang nhận diện
                      return const SizedBox.shrink();
                    },
                  ),
                  Selector<FaceDetectController, bool>(
                    selector: (context, controller) => controller.isDetecting,
                    builder: (context, isDetecting, child) {
                      return ElevatedButton.icon(
                        onPressed:
                            isDetecting
                                ? () =>
                                    context
                                        .read<FaceDetectController>()
                                        .stopDetection()
                                : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Camera preview with face detection overlay
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Selector<FaceDetectController, bool>(
                    selector:
                        (context, controller) =>
                            controller.controller?.value.isInitialized == true,
                    builder: (context, isInitialized, child) {
                      return isInitialized
                          ? _buildCameraPreview()
                          : Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.camera_alt,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Selector<FaceDetectController, bool>(
                                    selector:
                                        (context, controller) =>
                                            controller.isInitializing,
                                    builder: (context, isInitializing, child) {
                                      return Text(
                                        isInitializing
                                            ? 'Auto-starting camera...'
                                            : 'Camera not started',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                    },
                  ),
                ),
              ),
            ),

            // Detected persons list
            Expanded(
              flex: 1,
              child: Selector<FaceDetectController, List<InfoPerson>>(
                selector: (context, controller) => controller.detectedPersons,
                builder: (context, detectedPersons, child) {
                  return detectedPersons.isEmpty
                      ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No faces detected',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.people, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Detected Persons (${detectedPersons.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: detectedPersons.length,
                                itemBuilder: (context, index) {
                                  final person = detectedPersons[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading:
                                          person.image.isNotEmpty
                                              ? Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.grey[300]!,
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    person.image,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              )
                                              : Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.face,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      title: Text(
                                        'Face ID: ${person.faceId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Position: (${person.x.toStringAsFixed(1)}, ${person.y.toStringAsFixed(1)})',
                                          ),
                                          Text(
                                            'Size: ${person.w.toStringAsFixed(1)} x ${person.h.toStringAsFixed(1)}',
                                          ),
                                          if (person.name.isNotEmpty)
                                            Text(
                                              'Name: ${person.name}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          if (person.phone.isNotEmpty)
                                            Text(
                                              'Phone: ${person.phone}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              person.busy
                                                  ? Colors.orange
                                                  : Colors.green,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Overlay bounding box lên camera preview bằng customPaint từ controller
  Widget _buildCameraPreview() {
    return Selector<FaceDetectController, (CameraController?, CustomPaint?)>(
      selector:
          (context, controller) => (
            controller.controller,
            controller
                .customPaint, // customPaint đã sử dụng FaceDetectorPainter để vẽ bounding box
          ),
      builder: (context, data, child) {
        final cameraController = data.$1;
        final customPaint = data.$2;
        // Log kiểm tra customPaint có được render không
        app_config.printLog(
          'i',
          '[BoundingBox Debug] _buildCameraPreview: customPaint=${customPaint != null}',
        );
        if (cameraController == null) {
          return Container(color: Colors.black);
        }
        final size = MediaQuery.of(context).size;
        var scale = size.aspectRatio * cameraController.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;
        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: scale,
                child: Center(child: CameraPreview(cameraController)),
              ),
              if (customPaint != null) customPaint, // Overlay bounding box
            ],
          ),
        );
      },
    );
  }
}
