import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'face_detect_controller.dart';

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
    context.read<FaceDetectController>().init();
  }

  @override
  void dispose() {
    context.read<FaceDetectController>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchState = context.watch<FaceDetectController>();
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
                Consumer<FaceDetectController>(
                  builder: (context, provider, child) {
                    return Text(
                      'Status: ${provider.statusText}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Consumer<FaceDetectController>(
                  builder: (context, provider, child) {
                    return Text(
                      'Camera: ${provider.controller?.value.isInitialized == true ? "Running" : "Stopped"}',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            provider.controller?.value.isInitialized == true
                                ? Colors.green
                                : Colors.red,
                      ),
                    );
                  },
                ),
                Consumer<FaceDetectController>(
                  builder: (context, provider, child) {
                    return Text(
                      'Faces detected: ${provider.currentFaces.length}',
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
                ElevatedButton.icon(
                  onPressed:
                      watchState.isInitialized
                          ? watchState.startDetection
                          : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      watchState.isInitialized
                          ? watchState.stopDetection
                          : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
                child:
                    watchState.controller?.value.isInitialized == true
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
                        ),
              ),
            ),
          ),

          // Detected persons list
          Expanded(
            flex: 1,
            child:
                watchState.detectedPersons.isEmpty
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
                                Consumer<FaceDetectController>(
                                  builder: (context, provider, child) {
                                    return Text(
                                      'Detected Persons (${provider.detectedPersons.length})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Consumer<FaceDetectController>(
                            builder: (context, provider, child) {
                              return Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: provider.detectedPersons.length,
                                  itemBuilder: (context, index) {
                                    final person =
                                        provider.detectedPersons[index];
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
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.grey[300]!,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
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
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
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
                              );
                            },
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final watchState = context.watch<FaceDetectController>();
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * watchState.controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(watchState.controller!)),
          ),
          if (watchState.customPaint != null) watchState.customPaint!,
        ],
      ),
    );
  }
}
