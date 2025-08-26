import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'ml_service.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final MLService _mlService = MLService();
  final List<String> _capturedImages = [];
  final List<EyeAnalysisResult> _eyeAnalyses = [];
  bool _isCapturing = false;
  Timer? _captureTimer;
  bool _shouldStopCapturing = false;
  // bool _stopFlag = false;


  Future<String?> captureEyeImage(CameraController cameraController, {String? testType}) async {
    if (_isCapturing || _shouldStopCapturing) return null;

    if (!cameraController.value.isInitialized) {
      print('⚠️ Camera not initialized');
      return null;
    }

    _isCapturing = true;
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(tempDir.path, 'eye_capture_$timestamp.jpg');

      // Capture first (locks ImageReader buffer)
      final XFile imageFile = await cameraController.takePicture();

      // Immediately release the capture flag (free buffer sooner)
      _isCapturing = false;

      // Then copy to your app storage
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
      await captureEyeImage(cameraController, testType: testType);
    }
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
    final saveDir = Directory('${appDir.path}/eye_captures');
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

      await captureEyeImage(cameraController, testType: testType);
    }
  }

  void stopCapture() {
    _shouldStopCapturing = true;
    _captureTimer?.cancel();
    _captureTimer = null;
    print('🛑 Periodic capture stopped');
  }

  List<EyeTrackingData> generateEyeTrackingData() {
    final eyeTrackingData = <EyeTrackingData>[];
    final now = DateTime.now();

    // Mock data for demo - production extracts from actual images
    for (int i = 0; i < 50; i++) {
      eyeTrackingData.add(EyeTrackingData(
        timestamp: now.subtract(Duration(seconds: i)),
        leftEyeX: 100.0 + (i % 10 - 5),
        leftEyeY: 50.0 + (i % 8 - 4),
        rightEyeX: 200.0 + (i % 10 - 5),
        rightEyeY: 50.0 + (i % 8 - 4),
        blinkDuration: i % 20 == 0 ? 150.0 : 0.0,
        isBlinking: i % 20 == 0,
      ));
    }

    return eyeTrackingData;
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