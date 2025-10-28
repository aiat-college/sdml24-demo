import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:perfectrep/exercise_cart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

class PostureDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExerciseType exerciseType;

  const PostureDetectionScreen({
    super.key,
    required this.cameras,
    required this.exerciseType,
  });

  @override
  State<PostureDetectionScreen> createState() => _PostureDetectionScreenState();
}

class _PostureDetectionScreenState extends State<PostureDetectionScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  Pose? _currentPose;
  int _repCount = 0;
  bool _isInPosition = false;
  String _feedback = 'Position yourself in frame';
  List<String> _postureIssues = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializePoseDetector();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _cameraController = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      _cameraController!.startImageStream(_processCameraImage);
      setState(() {});
    }
  }

  void _initializePoseDetector() {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

    try {
      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isNotEmpty && mounted) {
        setState(() {
          _currentPose = poses.first;
          _analyzePose(poses.first);
        });
      }
    } catch (e) {
      print('Error detecting pose: $e');
    }

    _isDetecting = false;
  }

  void _analyzePose(Pose pose) {
    switch (widget.exerciseType) {
      case ExerciseType.situp:
        _analyzeSitup(pose);
        break;
      case ExerciseType.pushup:
        _analyzePushup(pose);
        break;
      case ExerciseType.squat:
        _analyzeSquat(pose);
        break;
      case ExerciseType.plank:
        _analyzePlank(pose);
        break;
    }
  }

  void _analyzeSitup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];

    if (leftShoulder == null || leftHip == null || leftKnee == null) return;

    final angle = _calculateAngle(leftShoulder, leftHip, leftKnee);

    _postureIssues.clear();

    // Check if in down position
    if (angle > 160) {
      if (_isInPosition) {
        _repCount++;
        _feedback = 'Great! Rep completed: $_repCount';
      }
      _isInPosition = false;
    }

    // Check if in up position
    if (angle < 90) {
      _isInPosition = true;
      _feedback = 'Hold this position';
    }

    // Posture checks
    if (angle > 90 && angle < 160) {
      _feedback = 'Keep going up or down';
    }

    // Check knee stability
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    if (rightKnee != null && (leftKnee.y - rightKnee.y).abs() > 50) {
      _postureIssues.add('Keep knees aligned');
    }
  }

  void _analyzePushup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];

    if (leftShoulder == null ||
        leftElbow == null ||
        leftWrist == null ||
        leftHip == null)
      return;

    final armAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);

    _postureIssues.clear();

    // Down position
    if (armAngle < 90) {
      if (_isInPosition) {
        _repCount++;
        _feedback = 'Rep completed: $_repCount';
      }
      _isInPosition = false;
    }

    // Up position
    if (armAngle > 160) {
      _isInPosition = true;
      _feedback = 'Good form - go down';
    }

    // Check back alignment
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (leftAnkle != null) {
      final bodyAngle = _calculateAngle(leftShoulder, leftHip, leftAnkle);
      if (bodyAngle < 160) {
        _postureIssues.add('Keep your back straight');
      }
    }

    // Check elbow position
    if (armAngle > 90 && armAngle < 160) {
      _feedback = 'Lower yourself more';
    }
  }

  void _analyzeSquat(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftHip == null || leftKnee == null || leftAnkle == null) return;

    final angle = _calculateAngle(leftHip, leftKnee, leftAnkle);

    _postureIssues.clear();

    // Down position (squat)
    if (angle < 90) {
      if (_isInPosition) {
        _repCount++;
        _feedback = 'Rep completed: $_repCount';
      }
      _isInPosition = false;

      // Check depth
      if (angle > 70) {
        _postureIssues.add('Go deeper for full range');
      }
    }

    // Up position
    if (angle > 160) {
      _isInPosition = true;
      _feedback = 'Good - now squat down';
    }

    // Check knee alignment
    if (leftKnee.x < leftAnkle.x - 30) {
      _postureIssues.add('Knees going too far forward');
    }
  }

  void _analyzePlank(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder == null || leftHip == null || leftAnkle == null) return;

    _postureIssues.clear();

    final bodyAngle = _calculateAngle(leftShoulder, leftHip, leftAnkle);

    if (bodyAngle > 160 && bodyAngle < 200) {
      _feedback = 'Perfect plank position! Hold it!';
      _isInPosition = true;
    } else {
      _isInPosition = false;
      if (bodyAngle < 160) {
        _postureIssues.add('Hips too high - lower them');
      } else {
        _postureIssues.add('Hips sagging - raise them');
      }
    }

    // Check shoulder alignment
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    if (leftElbow != null && (leftShoulder.x - leftElbow.x).abs() > 50) {
      _postureIssues.add('Keep elbows under shoulders');
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    var angle = radians.abs() * 180.0 / math.pi;
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getExerciseName()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _repCount = 0),
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_cameraController!),
          if (_currentPose != null)
            CustomPaint(
              painter: PosePainter(_currentPose!),
              size: Size.infinite,
            ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Reps: $_repCount',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _feedback,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.greenAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (_postureIssues.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posture Issues:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._postureIssues.map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(issue)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getExerciseName() {
    switch (widget.exerciseType) {
      case ExerciseType.situp:
        return 'Sit-ups';
      case ExerciseType.pushup:
        return 'Push-ups';
      case ExerciseType.squat:
        return 'Squats';
      case ExerciseType.plank:
        return 'Plank';
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }
}

class PosePainter extends CustomPainter {
  final Pose pose;

  PosePainter(this.pose);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 8
      ..style = PaintingStyle.fill;

    // Draw connections
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
    );
    _drawLine(
      canvas,
      paint,
      pose,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    );

    // Draw points
    pose.landmarks.forEach((type, landmark) {
      canvas.drawCircle(Offset(landmark.x, landmark.y), 6, pointPaint);
    });
  }

  void _drawLine(
    Canvas canvas,
    Paint paint,
    Pose pose,
    PoseLandmarkType start,
    PoseLandmarkType end,
  ) {
    final startLandmark = pose.landmarks[start];
    final endLandmark = pose.landmarks[end];

    if (startLandmark != null && endLandmark != null) {
      canvas.drawLine(
        Offset(startLandmark.x, startLandmark.y),
        Offset(endLandmark.x, endLandmark.y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
