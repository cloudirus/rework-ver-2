import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// ===================== RESULT CLASSES =====================

class EyeAnalysisResult {
  final String condition;
  final double confidence;
  final List<String> riskFactors;
  final List<String> recommendations;

  EyeAnalysisResult({
    required this.condition,
    required this.confidence,
    required this.riskFactors,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'confidence': confidence,
      'riskFactors': riskFactors,
      'recommendations': recommendations,
    };
  }
}

class VisionAnalysisResult {
  final double visionScore;
  final String riskLevel;
  final String diagnosis;
  final List<String> recommendations;
  final double confidence;
  final EyeAnalysisResult? eyeAnalysis;
  final String source; // "Test", "AI", or "Combined"
  final String? aiDiagnosis;

  VisionAnalysisResult({
    required this.visionScore,
    required this.riskLevel,
    required this.diagnosis,
    required this.recommendations,
    required this.confidence,
    this.eyeAnalysis,
    this.source = "Combined",
    this.aiDiagnosis,
  });

  VisionAnalysisResult copyWith({
    double? visionScore,
    String? riskLevel,
    String? diagnosis,
    List<String>? recommendations,
    double? confidence,
    EyeAnalysisResult? eyeAnalysis,
    String? source,
    String? aiDiagnosis,
  }) {
    return VisionAnalysisResult(
      visionScore: visionScore ?? this.visionScore,
      riskLevel: riskLevel ?? this.riskLevel,
      diagnosis: diagnosis ?? this.diagnosis,
      recommendations: recommendations ?? this.recommendations,
      confidence: confidence ?? this.confidence,
      eyeAnalysis: eyeAnalysis ?? this.eyeAnalysis,
      source: source ?? this.source,
      aiDiagnosis: aiDiagnosis ?? this.aiDiagnosis,
    );
  }
}

class EyeTrackingData {
  final DateTime timestamp;
  final double leftEyeX;
  final double leftEyeY;
  final double rightEyeX;
  final double rightEyeY;
  final double blinkDuration;
  final bool isBlinking;

  EyeTrackingData({
    required this.timestamp,
    required this.leftEyeX,
    required this.leftEyeY,
    required this.rightEyeX,
    required this.rightEyeY,
    required this.blinkDuration,
    required this.isBlinking,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'leftEyeX': leftEyeX,
      'leftEyeY': leftEyeY,
      'rightEyeX': rightEyeX,
      'rightEyeY': rightEyeY,
      'blinkDuration': blinkDuration,
      'isBlinking': isBlinking,
    };
  }

  factory EyeTrackingData.fromJson(Map<String, dynamic> json) {
    return EyeTrackingData(
      timestamp: DateTime.parse(json['timestamp']),
      leftEyeX: json['leftEyeX'],
      leftEyeY: json['leftEyeY'],
      rightEyeX: json['rightEyeX'],
      rightEyeY: json['rightEyeY'],
      blinkDuration: json['blinkDuration'],
      isBlinking: json['isBlinking'],
    );
  }
}

// ===================== ML SERVICE =====================

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  Interpreter? _fundusInterpreter;
  Interpreter? _outerInterpreter;
  bool _isFundusLoaded = false;
  bool _isOuterLoaded = false;

  // Input dimensions and model paths
  static const int _inputSize = 224;
  static const int _numChannels = 3;
  static const String _fundusModelPath = 'assets/models/eye_effnet_fp16.tflite';
  static const String _outerModelPath = 'assets/models/outer_eye_effnet.tflite';

  // Supported fundus conditions
  static const List<String> _fundusLabels = [
    'Central Serous Chorioretinopathy [Color Fundus]',
    'Diabetic Retinopathy',
    'Disc Edema',
    'Glaucoma',
    'Healthy',
    'Macular Scar',
    'Myopia',
    'Pterygium',
    'Retinal Detachment',
    'Retinitis Pigmentosa'
  ];

  // Supported outer eye conditions
  static const List<String> _outerLabels = [
    "Cataract",
    "Conjunctivitis",
    "Eyelid",
    "Normal",
    "Uveitis"
  ];

  Future<void> _loadFundusModel() async {
    try {
      _fundusInterpreter = await Interpreter.fromAsset(
        'assets/models/eye_effnet_fp32.tflite',
        options: InterpreterOptions()..threads = 2, // optional
      );
      print("📂 Loading model: models/eye_effnet_fp32.tflite");
      print("📏 File exists? ${await rootBundle.load('assets/models/eye_effnet_fp32.tflite')}");
      _isFundusLoaded = true;
      print("✅ Fundus model loaded");
    } catch (e) {
      print("❌ Error loading fundus model: $e");
    }
  }


  Future<void> _loadOuterModel() async {
    try {
      _outerInterpreter = await Interpreter.fromAsset(
        'assets/models/outer_eye_effnet.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      _isOuterLoaded = true;
      print("✅ Outer eye model loaded");
    } catch (e) {
      print("❌ Error loading outer model: $e");
    }
  }

  // ===================== MAIN ANALYSIS =====================

  bool _isLoadingModels = false;

  Future<void> loadModels() async {
    if (_isFundusLoaded && _isOuterLoaded) return;

    if (_isLoadingModels) {
      // wait for ongoing load
      while (_isLoadingModels) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isLoadingModels = true;
    try {
      if (!_isFundusLoaded) await _loadFundusModel();
      if (!_isOuterLoaded) await _loadOuterModel();
    } finally {
      _isLoadingModels = false;
    }
  }


  Future<EyeAnalysisResult> analyzeEyeImage(String imagePath) async {
    if (!_isFundusLoaded || !_isOuterLoaded) {
      print("⚠️ Models not loaded, loading now...");
      await loadModels();
      print('✅ Models loaded');
    }

    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) throw Exception('Image file not found');

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      final input = _preprocessImage(image).reshape([1, _inputSize, _inputSize, _numChannels]);

      // Run Fundus model
      final fundusOutput = List.filled(_fundusLabels.length, 0.0).reshape([1, _fundusLabels.length]);
      _fundusInterpreter!.run(input, fundusOutput);
      final fundusResult = _processFundusResults(fundusOutput[0] as List<double>);

      // Run Outer-eye model
      final outerOutput = List.filled(_outerLabels.length, 0.0).reshape([1, _outerLabels.length]);
      _outerInterpreter!.run(input, outerOutput);
      final outerPredictions = outerOutput[0] as List<double>;
      final outerIdx = _argmax(outerPredictions);
      final outerCondition = _outerLabels[outerIdx];
      final outerConfidence = outerPredictions[outerIdx];

      // Merge results
      final combinedCondition =
          "Outer: $outerCondition (${(outerConfidence * 100).toStringAsFixed(1)}%) | "
          "Fundus: ${fundusResult.condition} (${(fundusResult.confidence * 100).toStringAsFixed(1)}%)";

      return EyeAnalysisResult(
        condition: combinedCondition,
        confidence: (outerConfidence > fundusResult.confidence)
            ? outerConfidence
            : fundusResult.confidence,
        riskFactors: [
          ...fundusResult.riskFactors,
          if (outerCondition != "Normal") "Outer-eye issue: $outerCondition"
        ],
        recommendations: [
          ...fundusResult.recommendations,
          if (outerCondition != "Normal") "Consult an eye specialist for $outerCondition"
        ],
      );
    } catch (e) {
      print('❌ Eye analysis failed: $e');
      return EyeAnalysisResult(
        condition: 'Unknown',
        confidence: 0.0,
        riskFactors: [],
        recommendations: ['Analysis failed, please retake the image'],
      );
    }
  }



  // ===================== HELPERS =====================

  Float32List _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    final input = Float32List(_inputSize * _inputSize * _numChannels);

    int index = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }
    return input;
  }

  EyeAnalysisResult _processFundusResults(List<double> predictions) {
    int maxIndex = 0;
    double maxConfidence = predictions[0];

    for (int i = 1; i < predictions.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        maxIndex = i;
      }
    }

    final predictedCondition = _fundusLabels[maxIndex];
    final confidence = maxConfidence;
    final riskFactors = _generateRiskFactors(predictedCondition);
    final recommendations =
    _generateRecommendations(predictedCondition, confidence);

    return EyeAnalysisResult(
      condition: predictedCondition,
      confidence: confidence,
      riskFactors: riskFactors,
      recommendations: recommendations,
    );
  }

  int _argmax(List<double> arr) {
    int idx = 0;
    double maxVal = arr[0];
    for (int i = 1; i < arr.length; i++) {
      if (arr[i] > maxVal) {
        maxVal = arr[i];
        idx = i;
      }
    }
    return idx;
  }

  // ===================== RISK FACTORS & RECOMMENDATIONS =====================

  List<String> _generateRiskFactors(String condition) {
    switch (condition) {
      case 'Diabetic Retinopathy':
        return ['High blood sugar', 'Possible vision loss'];
      case 'Glaucoma':
        return ['High intraocular pressure', 'Optic nerve damage risk'];
      case 'Retinal Detachment':
        return ['Possible retinal tear', 'Emergency eye condition'];
      case 'Myopia':
        return ['Nearsightedness', 'Higher risk of retinal issues'];
      case 'Cataract':
        return ['Lens clouding', 'Blurry vision'];
      case 'Conjunctivitis':
        return ['Eye infection or allergy'];
      default:
        return [];
    }
  }

  List<String> _generateRecommendations(String condition, double confidence) {
    final recs = <String>[];

    if (confidence < 0.6) {
      recs.add("Result uncertain, please retake the test under better lighting.");
    }

    switch (condition) {
      case 'Diabetic Retinopathy':
        recs.add("Consult an ophthalmologist immediately.");
        recs.add("Maintain good blood sugar control.");
        break;
      case 'Glaucoma':
        recs.add("Schedule regular eye pressure checkups.");
        recs.add("Consult a glaucoma specialist.");
        break;
      case 'Retinal Detachment':
        recs.add("Seek emergency eye care immediately.");
        break;
      case 'Myopia':
        recs.add("Wear prescribed corrective lenses.");
        recs.add("Avoid excessive screen time.");
        break;
      case 'Cataract':
        recs.add("Surgical evaluation if vision significantly impaired.");
        break;
      case 'Conjunctivitis':
        recs.add("Maintain good eye hygiene.");
        recs.add("Avoid touching/rubbing eyes.");
        break;
      default:
        recs.add("Maintain regular eye checkups.");
    }
    return recs;
  }

  List<String> _generateVisionRecommendations(
      double visionScore, EyeAnalysisResult? eyeAnalysis) {
    final recommendations = <String>[];

    if (eyeAnalysis != null) {
      recommendations.addAll(eyeAnalysis.recommendations);
    }

    if (visionScore < 0.6) {
      recommendations.addAll([
        'Schedule comprehensive eye examination',
        'Consider vision correction options',
        'Regular monitoring of vision changes'
      ]);
    }

    return recommendations.toSet().toList(); // remove duplicates
  }

  // ===================== VISION TEST =====================

  Future<VisionAnalysisResult> analyzeVisionTest(
      int correctAnswers,
      int totalQuestions,
      List<EyeTrackingData> eyeTrackingData, {
        EyeAnalysisResult? eyeAnalysis,
      }) async {
    final score = _calculateVisionScore(correctAnswers, totalQuestions);
    final riskLevel = _determineRiskLevel(score);
    final diagnosis = _generateDiagnosis(score);
    final recs = _generateVisionRecommendations(score, eyeAnalysis);
    String? aiDiagnosis;
    if (eyeAnalysis != null) {
      aiDiagnosis = "Detected: ${eyeAnalysis.condition.replaceAll('_', ' ').toUpperCase()} "
          "(Confidence: ${(eyeAnalysis.confidence * 100).toInt()}%)";
    }
    return VisionAnalysisResult(
      visionScore: score,
      riskLevel: riskLevel,
      diagnosis: diagnosis,
      recommendations: recs,
      confidence: score,
      eyeAnalysis: eyeAnalysis,
      source: eyeAnalysis == null ? "Test" : "Combined",
      aiDiagnosis: aiDiagnosis,
    );
  }

  double _calculateVisionScore(int correct, int total) {
    if (total == 0) return 0.0;
    return correct / total;
  }

  String _determineRiskLevel(double score) {
    if (score >= 0.9) return "Low Risk";
    if (score >= 0.7) return "Moderate Risk";
    return "High Risk";
  }

  String _generateDiagnosis(double score) {
    if (score >= 0.9) return "Normal vision function";
    if (score >= 0.7) return "Possible mild vision issues";
    return "Significant vision impairment suspected";
  }

  // ===================== CLEANUP =====================

  void dispose() {
    _fundusInterpreter?.close();
    _outerInterpreter?.close();
    _fundusInterpreter = null;
    _outerInterpreter = null;
    _isFundusLoaded = false;
    _isOuterLoaded = false;
  }
}
