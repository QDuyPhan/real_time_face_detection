import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:real_time_face_detection/home_screen.dart';
/// không nhận diện được trên đt xiaomi kể cả log
/// chỉ nhận trên tablet
List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material App',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
