import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:real_time_face_detection/face_detect_controller.dart';

import 'home_screen.dart';
// import 'package:real_time_face_detection/screens/home_screen.dart';

List<CameraDescription> cameras = [];
RootIsolateToken? rootIsolateToken;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  rootIsolateToken = RootIsolateToken.instance;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FaceDetectController(),
      child: MaterialApp(
        title: 'Face Detection',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}
