import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:real_time_face_detection/app_config.dart';

import 'face_detect_controller.dart';
import 'api_face.dart';

class AdvancedFaceDetectorScreen extends StatefulWidget {
  const AdvancedFaceDetectorScreen({super.key});

  @override
  State<AdvancedFaceDetectorScreen> createState() =>
      _AdvancedFaceDetectorScreenState();
}

class _AdvancedFaceDetectorScreenState
    extends State<AdvancedFaceDetectorScreen> {
  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure widget is properly mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FaceDetectController>().init();
    });
  }

  @override
  void dispose() {
    app_config.printLog(
      'i',
      '[Debug face] : AdvancedFaceDetectorScreen: dispose() called',
    );
    context.read<FaceDetectController>().stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Face Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
                Selector<FaceDetectController, bool>(
                  selector: (context, controller) => controller.isInitialized,
                  builder: (context, isInitialized, child) {
                    return ElevatedButton.icon(
                      onPressed:
                          isInitialized
                              ? () =>
                                  context
                                      .read<FaceDetectController>()
                                      .startDetection()
                              : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    );
                  },
                ),
                Selector<FaceDetectController, bool>(
                  selector: (context, controller) => controller.isInitialized,
                  builder: (context, isInitialized, child) {
                    return ElevatedButton.icon(
                      onPressed:
                          isInitialized
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
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Camera not started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
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
                            style: TextStyle(fontSize: 16, color: Colors.grey),
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
    );
  }

  Widget _buildCameraPreview() {
    return Selector<FaceDetectController, (CameraController?, CustomPaint?)>(
      selector:
          (context, controller) => (
            controller.controller,
            controller.customPaint,
          ),
      builder: (context, data, child) {
        final cameraController = data.$1;
        final customPaint = data.$2;

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
              if (customPaint != null) customPaint,
            ],
          ),
        );
      },
    );
  }
}
