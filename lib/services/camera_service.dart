import 'dart:async';
//import 'dart:ffi';
import 'dart:io' ;
import 'dart:ui';
import 'dart:typed_data';

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
      enableClassification: true,
      enableLandmarks: true,// needed for eye open prob
      enableTracking: true,
    ),
  );
  Future<void>? _cameraStreamFuture;
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  bool _isCapturing = false;
  Timer? _captureTimer;
  bool _shouldStopCapturing = false;
  // bool _stopFlag = false;

  Future<CameraController> startCamera(CameraDescription description) async {
    _cameraController = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    print("📷 Camera started");
    _startEyeTracking();
    return _cameraController!;
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
          final String? eyePath =  await _saveEyeCrop(image, face);
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

  Uint8List _yuv420toNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 4;

    final Uint8List nv21 = Uint8List(ySize + uvSize * 2);

    // Y plane (full size)
    nv21.setRange(0, ySize, image.planes[0].bytes);

    // UV planes: Android camera gives U and V separately
    final u = image.planes[1].bytes;
    final v = image.planes[2].bytes;

    int uvIndex = ySize;
    for (int i = 0; i < u.length; i++) {
      nv21[uvIndex++] = v[i];
      nv21[uvIndex++] = u[i];
    }

    return nv21;
  }
  // Chuyển CameraImage (YUV420) thành ảnh RGB để crop/lưu
  img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yBuffer = image.planes[0].bytes;
    final uBuffer = image.planes[1].bytes;
    final vBuffer = image.planes[2].bytes;

    final imgData = Uint8List(width * height * 3);

    int uvRowStride = image.planes[1].bytesPerRow;
    int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        int index = y * width + x;

        int yp = yBuffer[index];
        int up = uBuffer[uvIndex];
        int vp = vBuffer[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255).toInt();
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255).toInt();
        int b = (yp + up * 1814 / 1024 - 227).clamp(0, 255).toInt();

        imgData[index * 3] = r;
        imgData[index * 3 + 1] = g;
        imgData[index * 3 + 2] = b;
      }
    }

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: imgData.buffer,
      numChannels: 3,
    );

  }

  // Convert CameraImage → InputImage for ML Kit
  InputImage _convertCameraImage(CameraImage image, CameraController controller) {
    final imageRotation =
        InputImageRotationValue.fromRawValue(controller.description.sensorOrientation)
            ?? InputImageRotation.rotation0deg;

    if (Platform.isAndroid) {
      final bytes = _yuv420toNv21(image);

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else if (Platform.isIOS) {
      final bytes = image.planes[0].bytes;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    throw Exception("Unsupported platform ${Platform.operatingSystem}");
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


  Future<List<EyeAnalysisResult>> analyzeAllCapturedImages() async {
    final results = <EyeAnalysisResult>[];

    for (final imagePath in _capturedImages) {
      try {
        final analysisResult = await _mlService.analyzeEyeImage(imagePath);
        results.add(analysisResult);
        _eyeAnalyses.add(analysisResult);
      } catch (e) {
        print('Error analyzing image $imagePath: $e');
      }
    }

    return results;
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

  Future<void> cleanup() async {
    for (final imagePath in _capturedImages) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting image file $imagePath: $e');
      }
    }

    _capturedImages.clear();
    _eyeAnalyses.clear();
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

  Future<String?> _saveEyeCrop(CameraImage cameraImage, Face face) async {
    try {
      // Convert CameraImage (YUV420) -> RGB image
      final img.Image? image = _convertYUV420ToImage(cameraImage);
      if (image == null) {
        print("⚠️ Could not convert CameraImage to Image");
        return null;
      }

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
        const cropSize = 100;
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
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final path = '${dir.path}/eye_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path)..writeAsBytesSync(img.encodeJpg(crop));
      print("📸 Saved crop at: $path");
      return file.path;
    } catch (e) {
      print("❌ Error in _saveEyeCrop: $e");
      return null;
    }
  }


  List<EyeTrackingData> generateEyeTrackingData() {
    if (_eyeTrackingData.isNotEmpty) {
      return List.from(_eyeTrackingData); // ✅ real tracked data
    }

    // fallback mock
    final mockData = <EyeTrackingData>[];
    final now = DateTime.now();


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