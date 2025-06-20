import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'face_detector_screen.dart';
import 'advanced_face_detector_screen.dart';
import 'face_detect_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detector'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Basic Face Detector Button
            SizedBox(
              width: 350,
              height: 80,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FaceDetectorScreen(),
                    ),
                  );
                },
                style: ButtonStyle(
                  side: MaterialStateProperty.all(
                    BorderSide(
                      color: Colors.blue,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Basic Face Detector', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Advanced Face Detector Button
            SizedBox(
              width: 350,
              height: 80,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChangeNotifierProvider(
                            create: (context) => FaceDetectController(),
                            child: const AdvancedFaceDetectorScreen(),
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  side: const BorderSide(
                    color: Colors.green,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_retouching_natural, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Advanced Face Detection',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Description
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Column(
                children: [
                  Text(
                    'Face Detection Options',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Basic: Simple face detection with bounding boxes\n'
                    '• Advanced: Real-time tracking, face registration, and identification',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
