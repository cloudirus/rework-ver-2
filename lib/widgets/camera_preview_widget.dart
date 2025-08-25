import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraPreviewWidget extends StatefulWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  final List<String> _capturedImages = [];
  Timer? _captureTimer;
  bool _isCapturing = false;
  bool _isDetecting = false;

  late FaceDetector _faceDetector;
  List<Face> _faces = [];

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
      ),
    );
    _startEyeTracking();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _captureTimer?.cancel();
    super.dispose();
  }

  void _startEyeTracking() {
    _captureTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _captureFrame();
    });
  }

  Future<void> _captureFrame() async {
    if (_isCapturing || _isDetecting) return;

    try {
      if (widget.controller.value.isInitialized) {
        _isCapturing = true;

        final Directory appDir = await getApplicationDocumentsDirectory();
        final String timestamp =
        DateTime.now().millisecondsSinceEpoch.toString();
        final String filePath =
        path.join(appDir.path, 'eye_frames', '$timestamp.jpg');

        await Directory(path.dirname(filePath)).create(recursive: true);

        final XFile imageFile = await widget.controller.takePicture();
        await imageFile.saveTo(filePath);

        setState(() {
          _capturedImages.add(filePath);
          if (_capturedImages.length > 100) {
            final oldImage = _capturedImages.removeAt(0);
            File(oldImage).delete();
          }
        });

        // detect face landmarks
        _isDetecting = true;
        final inputImage = InputImage.fromFilePath(filePath);
        final faces = await _faceDetector.processImage(inputImage);
        setState(() {
          _faces = faces;
        });
      }
    } catch (e) {
      print('Error capturing frame: $e');
    } finally {
      _isCapturing = false;
      _isDetecting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: widget.controller.value.isInitialized
          ? Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CameraPreview(widget.controller),
          ),
          // Frames counter
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Frames: ${_capturedImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Eye overlay
          Positioned.fill(
            child: CustomPaint(
              painter: EyeTrackingOverlayPainter(_faces),
            ),
          ),
        ],
      )
          : const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class EyeTrackingOverlayPainter extends CustomPainter {
  final List<Face> faces;

  EyeTrackingOverlayPainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    final paintEye = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paintPupil = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (var face in faces) {
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye != null) {
        canvas.drawCircle(
            Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble()), 8, paintEye);
        canvas.drawCircle(
            Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble()), 3, paintPupil);
      }
      if (rightEye != null) {
        canvas.drawCircle(
            Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble()), 8, paintEye);
        canvas.drawCircle(
            Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble()), 3, paintPupil);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EyeTrackingOverlayPainter oldDelegate) =>
      oldDelegate.faces != faces;
}
