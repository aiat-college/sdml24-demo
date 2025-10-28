import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:perfectrep/exercise_cart.dart';
import 'package:perfectrep/posture_deduction_screen.dart';

class ExerciseSelectionScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const ExerciseSelectionScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(''), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Choose an exercise\nto start',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                children: [
                  ExerciseCard(
                    title: 'Sit-ups',
                    icon: Icons.accessibility_new,
                    color: Colors.blue,
                    onTap: () =>
                        _navigateToExercise(context, ExerciseType.situp),
                  ),
                  ExerciseCard(
                    title: 'Push-ups',
                    icon: Icons.fitness_center,
                    color: Colors.green,
                    onTap: () =>
                        _navigateToExercise(context, ExerciseType.pushup),
                  ),
                  ExerciseCard(
                    title: 'Squats',
                    icon: Icons.airline_seat_legroom_normal,
                    color: Colors.orange,
                    onTap: () =>
                        _navigateToExercise(context, ExerciseType.squat),
                  ),
                  ExerciseCard(
                    title: 'Plank',
                    icon: Icons.horizontal_rule,
                    color: Colors.purple,
                    onTap: () =>
                        _navigateToExercise(context, ExerciseType.plank),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToExercise(BuildContext context, ExerciseType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostureDetectionScreen(cameras: cameras, exerciseType: type),
      ),
    );
  }
}
