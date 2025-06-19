import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import 'api_face.dart';
import 'main.dart';

class AdvancedFaceDetectorScreen extends StatefulWidget {
  const AdvancedFaceDetectorScreen({super.key});

  @override
  State<AdvancedFaceDetectorScreen> createState() =>
      _AdvancedFaceDetectorScreenState();
}

class _AdvancedFaceDetectorScreenState
    extends State<AdvancedFaceDetectorScreen> {
  late APIFace _apiFace;
  bool _isInitialized = false;
  List<InfoPerson> _detectedPersons = [];
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeFaceDetection();
  }

  Future<void> _initializeFaceDetection() async {
    try {
      _apiFace = APIFace();
      _apiFace.init(rootIsolateToken!);

      // Lắng nghe stream từ API Face để cập nhật UI
      _apiFace.streamPersonController.stream.listen((persons) {
        if (persons is List<InfoPerson>) {
          setState(() {
            _detectedPersons = persons;
            _statusText = 'Detected ${persons.length} person(s)';
          });
        }
      });

      // Lắng nghe stream face detection để hiển thị thông tin debug
      _apiFace.streamFaceController.stream.listen((event) {
        if (event is List && event.isNotEmpty) {
          if (event[0] is List<Face> && event[1] is imglib.Image) {
            List<Face> faces = event[0];
            setState(() {
              _statusText = 'Processing ${faces.length} face(s)';
            });
          }
        }
      });

      setState(() {
        _isInitialized = true;
        _statusText = 'Ready - Tap to start detection';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _apiFace.stop();
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
                Text(
                  'Status: $_statusText',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Camera: ${_apiFace.state() ? "Running" : "Stopped"}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _apiFace.state() ? Colors.green : Colors.red,
                  ),
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
                  onPressed: _isInitialized ? _startDetection : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isInitialized ? _stopDetection : null,
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

          // Detected persons list
          Expanded(
            child:
                _detectedPersons.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.face, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No faces detected',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            'Start detection to see results',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _detectedPersons.length,
                      itemBuilder: (context, index) {
                        final person = _detectedPersons[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Face image preview
                                    if (person.image.isNotEmpty)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.memory(
                                            person.image,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.face,
                                          color: Colors.grey,
                                        ),
                                      ),

                                    const SizedBox(width: 16),

                                    // Person info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Face ID: ${person.faceId}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Position: (${person.x.toStringAsFixed(1)}, ${person.y.toStringAsFixed(1)})',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Size: ${person.w.toStringAsFixed(1)} x ${person.h.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Angles: X:${person.angleX.toStringAsFixed(1)}°, Y:${person.angleY.toStringAsFixed(1)}°, Z:${person.angleZ.toStringAsFixed(1)}°',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (person.name.isNotEmpty)
                                            Text(
                                              'Name: ${person.name}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          if (person.phone.isNotEmpty)
                                            Text(
                                              'Phone: ${person.phone}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Status indicators
                                    Column(
                                      children: [
                                        Container(
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
                                        const SizedBox(height: 4),
                                        Text(
                                          person.busy ? 'Busy' : 'Ready',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Action buttons
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed:
                                          person.image.isNotEmpty
                                              ? () => _registerPerson(person)
                                              : null,
                                      child: const Text('Register'),
                                    ),
                                    ElevatedButton(
                                      onPressed:
                                          person.image.isNotEmpty
                                              ? () => _identifyPerson(person)
                                              : null,
                                      child: const Text('Identify'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDetection() async {
    try {
      await _apiFace.start();
      setState(() {
        _statusText = 'Detection started';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error starting detection: $e';
      });
    }
  }

  Future<void> _stopDetection() async {
    try {
      _apiFace.stop();
      setState(() {
        _statusText = 'Detection stopped';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error stopping detection: $e';
      });
    }
  }

  void _registerPerson(InfoPerson person) {
    // TODO: Implement person registration
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Register Person'),
            content: const Text(
              'This feature will be implemented to register a new person with the detected face.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _identifyPerson(InfoPerson person) {
    // TODO: Implement person identification
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Identify Person'),
            content: const Text(
              'This feature will be implemented to identify the person from the detected face.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
