import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'spectrum_screen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load available cameras on device
  cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spectrum Proof of Concept',
      theme: ThemeData.dark(),
      home: SpectrumScreen(camera: camera),
    );
  }
}

