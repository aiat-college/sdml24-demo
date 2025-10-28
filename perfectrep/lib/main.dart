import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:perfectrep/exercise_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  print(cameras);
  runApp(FitnessPostureApp(cameras: cameras));
}

class FitnessPostureApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const FitnessPostureApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Perfect',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: ExerciseSelectionScreen(cameras: cameras),
    );
  }
}
