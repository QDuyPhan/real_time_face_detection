import 'package:flutter/material.dart';
import 'package:real_time_face_detection/face_detector_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Face Detector')),
      body: Center(
        child: SizedBox(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text('Go Face Detector')],
            ),
          ),
        ),
      ),
    );
  }
}
