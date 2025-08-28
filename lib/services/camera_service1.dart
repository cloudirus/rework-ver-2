import 'dart:async';
//import 'dart:ffi';
import 'dart:io' ;
import 'dart:ui'as ui;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as path;
import 'ml_service.dart';

class CameraService {
  CameraController? _cameraController;
  CameraController? get controller => _cameraController;

  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final MLService _mlService = MLService();
  final List<String> _capturedImages = [];
  final List<EyeAnalysisResult> _eyeAnalyses = [];
  final List<EyeTrackingData> _eyeTrackingData = [];
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // needed for eye open prob
      enableTracking: true,
    ),
  );
  Future<void>? _cameraStreamFuture;

  bool _isCapturing = false;
  Timer? _captureTimer;
  bool _shouldStopCapturing = false;
  // bool _stopFlag = false;

  Future<void> startCamera(CameraDescription description) async {
    _cameraController = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    print("📷 Camera started");
    _startEyeTracking();
  }

  Future<void> stopCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      print("🛑 Camera fully stopped");
    }
  }

  bool get isCameraActive => _cameraController != null;

  void _startEyeTracking() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("⚠️ Camera not initialized for eye tracking");
      return;
    }

    bool _isProcessingFrame = false;

    _cameraStreamFuture = _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final inputImage = _convertCameraImage(image, _cameraController!);
        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          final now = DateTime.now();

          // store basic tracking
          final eyeData = EyeTrackingData(
            timestamp: now,
            leftEyeX: face.boundingBox.left.toDouble(),
            leftEyeY: face.boundingBox.top.toDouble(),
            rightEyeX: face.boundingBox.right.toDouble(),
            rightEyeY: face.boundingBox.top.toDouble(),
            blinkDuration: (face.leftEyeOpenProbability ?? 1.0) < 0.5 ? 150.0 : 0.0,
            isBlinking: (face.leftEyeOpenProbability ?? 1.0) < 0.5 ||
                (face.rightEyeOpenProbability ?? 1.0) < 0.5,
          );

          _eyeTrackingData.add(eyeData);
          if (_eyeTrackingData.length > 200) {
            _eyeTrackingData.removeAt(0);
          }

          print("👁 Eye tracked: Blink=${eyeData.isBlinking}, "
              "Left=(${eyeData.leftEyeX},${eyeData.leftEyeY})");

          // ✅ Eye cropping + AI analysis
          final eyePath = await _saveEyeCrop(inputImage, face);
          if (eyePath != null) {
            final analysis = await MLService().analyzeEyeImage(eyePath);
            _eyeAnalyses.add(analysis);
            print("🤖 AI Eye Analysis Result: $analysis");
          }
        }
      } catch (e) {
        print("⚠️ Eye tracking error: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
  }



  // Convert CameraImage → InputImage for ML Kit
  InputImage _convertCameraImage(CameraImage image, CameraController controller) {
    // Concatenate planes into a single byte array
    final bytesBuilder = BytesBuilder();
    for (final Plane plane in image.planes) {
      bytesBuilder.add(plane.bytes);
    }
    final bytes = bytesBuilder.toBytes();

    // Image size
    final ui.Size imageSize = ui.Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // Camera rotation
    final imageRotation =
        InputImageRotationValue.fromRawValue(controller.description.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    // Image format
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    // Metadata (no more planeData in new API)
    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    // Build InputImage
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }

  // ⚡ Public getter
  List<EyeTrackingData> getEyeTrackingData() => List.from(_eyeTrackingData);

  Future<String?> captureEyeImage({String? testType}) async {
    final cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      print('⚠️ Camera not initialized');
      return null;
    }

    if (_isCapturing || _shouldStopCapturing) return null;

    _isCapturing = true;
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(tempDir.path, 'eye_frame_$timestamp.jpg');

      final XFile imageFile = await cameraController.takePicture();

      final File savedImage = await File(imageFile.path).copy(imagePath);
      _capturedImages.add(savedImage.path);

      print('📸 Eye image captured: ${savedImage.path}');
      return savedImage.path;

    } catch (e) {
      print('❌ Error capturing eye image: $e');
      return null;
    } finally {
      _isCapturing = false;
    }
  }


  Future<void> captureTestSession(CameraController cameraController, String testType) async {
    // Staggered captures during test session
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(seconds: 2 + i * 3)); // Stagger captures
      await captureEyeImage(testType: testType);

    }
    await stopCamera();
    //   while(_stopFlag){
    //     await captureEyeImage(cameraController, testType: testType);
    //     await Future.delayed(Duration(seconds: 1));
    //   }
    // }
    // void stopCaptureSession() {
    //   _stopFlag = true;
  }


  Future<void> saveAllCapturedImages() async {
    final appDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${appDir.path}/eye_frames/full');
    // stopCaptureSession();

    // Create folder if it doesn't exist
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    for (final imagePath in _capturedImages) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final fileName = path.basename(imagePath); // keep original name
          final newPath = path.join(saveDir.path, fileName);

          // Copy file into permanent folder
          await file.copy(newPath);
          print('✅ Saved image to: $newPath');
        }
      } catch (e) {
        print('⚠️ Error saving image $imagePath: $e');
      }
    }
  }




  EyeAnalysisResult? getBestAnalysisResult() {
    if (_eyeAnalyses.isEmpty) return null;

    EyeAnalysisResult bestResult = _eyeAnalyses.first;
    for (final result in _eyeAnalyses) {
      if (result.confidence > bestResult.confidence) {
        bestResult = result;
      }
    }

    return bestResult;
  }

  EyeAnalysisResult? getAggregateAnalysis() {
    if (_eyeAnalyses.isEmpty) return null;

    final conditionCounts = <String, int>{};
    double totalConfidence = 0.0;
    final allRiskFactors = <String>{};
    final allRecommendations = <String>{};

    for (final analysis in _eyeAnalyses) {
      conditionCounts[analysis.condition] = (conditionCounts[analysis.condition] ?? 0) + 1;
      totalConfidence += analysis.confidence;
      allRiskFactors.addAll(analysis.riskFactors);
      allRecommendations.addAll(analysis.recommendations);
    }

    String mostCommonCondition = 'normal';
    int maxCount = 0;

    conditionCounts.forEach((condition, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonCondition = condition;
      }
    });

    final averageConfidence = totalConfidence / _eyeAnalyses.length;

    return EyeAnalysisResult(
      condition: mostCommonCondition,
      confidence: averageConfidence,
      riskFactors: allRiskFactors.toList(),
      recommendations: allRecommendations.toList(),
    );
  }


  List<String> getCapturedImagePaths() {
    return List.from(_capturedImages);
  }

  List<EyeAnalysisResult> getAllAnalysisResults() {
    return List.from(_eyeAnalyses);
  }

  //bool _shouldStopCapturing = false;

  Future<void> startPeriodicCapture(CameraController cameraController, String testType) async {
    _shouldStopCapturing = false;

    for (int i = 0; i < 3; i++) {
      if (_shouldStopCapturing) {
        print("🛑 Capture stopped before iteration $i");
        break;
      }

      await Future.delayed(Duration(seconds: 10));

      if (_shouldStopCapturing || !cameraController.value.isInitialized) {
        print("🛑 Skipping capture at iteration $i");
        break;
      }

      await captureEyeImage(testType: testType);

    }
  }

  void stopCapture() {
    _shouldStopCapturing = true;
    _captureTimer?.cancel();
    _captureTimer = null;
    print('🛑 Periodic capture stopped');
    stopCamera();
  }

  Future<String?> _saveEyeCrop(InputImage inputImage, Face face) async {
    // Convert InputImage to raw bytes
    final bytes = inputImage.bytes;
    if (bytes == null) return null;

    // Decode using `package:image`
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image crop;

    // Try cropping eye first
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    if (leftEye == null) {
      print("⚠️ No eye landmark found, saving face instead");
      crop = img.copyCrop(
        image,
        x: face.boundingBox.left.toInt(),
        y: face.boundingBox.top.toInt(),
        width: face.boundingBox.width.toInt(),
        height: face.boundingBox.height.toInt(),
      );
    } else {
      const cropSize = 100; // adjust based on resolution
      crop = img.copyCrop(
        image,
        x: leftEye.position.x.toInt() - cropSize ~/ 2,
        y: leftEye.position.y.toInt() - cropSize ~/ 2,
        width: cropSize,
        height: cropSize,
      );
    }

    // Save to temp file
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/eye_frames/crop');

    // Ensure directory exists
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final path = '${dir.path}/eye_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path)..writeAsBytesSync(img.encodePng(crop));

    print("📸 Saved crop at: $path");
    return file.path;
  }

  List<EyeTrackingData> generateEyeTrackingData() {
    if (_eyeTrackingData.isNotEmpty) {
      return List.from(_eyeTrackingData); // ✅ real tracked data
    }

    // fallback mock
    final mockData = <EyeTrackingData>[];
    final now = DateTime.now();

    for (int i = 0; i < 50; i++) {
      mockData.add(EyeTrackingData(
        timestamp: now.subtract(Duration(seconds: i)),
        leftEyeX: 100.0 + (i % 10 - 5),
        leftEyeY: 50.0 + (i % 8 - 4),
        rightEyeX: 200.0 + (i % 10 - 5),
        rightEyeY: 50.0 + (i % 8 - 4),
        blinkDuration: i % 20 == 0 ? 150.0 : 0.0,
        isBlinking: i % 20 == 0,
      ));
    }

    return mockData;
  }


  bool hasCaptures() {
    return _capturedImages.isNotEmpty;
  }

  Map<String, dynamic> getCaptureStatistics() {
    return {
      'totalCaptures': _capturedImages.length,
      'totalAnalyses': _eyeAnalyses.length,
      'bestConfidence': _eyeAnalyses.isNotEmpty
          ? _eyeAnalyses.map((a) => a.confidence).reduce((a, b) => a > b ? a : b)
          : 0.0,
      'averageConfidence': _eyeAnalyses.isNotEmpty
          ? _eyeAnalyses.map((a) => a.confidence).reduce((a, b) => a + b) / _eyeAnalyses.length
          : 0.0,
    };
  }
}