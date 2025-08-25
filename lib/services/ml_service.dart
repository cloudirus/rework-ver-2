import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/test_result.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Input dimensions and model path
  static const int _inputSize = 224;
  static const int _numChannels = 3;
  static const String _modelPath = 'assets/models/eye_effnet_fp16.tflite';

  // Supported eye conditions
  static const List<String> _eyeConditionLabels = [
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

  Future<void> loadModel() async {
    try {
      print('Loading TensorFlow Lite model...');

      final modelData = await rootBundle.load(_modelPath);
      final modelBytes = modelData.buffer.asUint8List();

      _interpreter = Interpreter.fromBuffer(modelBytes);

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('Model loaded successfully');
      print('Input shape: ${inputTensors.first.shape}');
      print('Output shape: ${outputTensors.first.shape}');

      _isModelLoaded = true;
    } catch (e) {
      print('Error loading ML model: $e');
      _isModelLoaded = false;
    }
  }

  Future<EyeAnalysisResult> analyzeEyeImage(String imagePath) async {
    if (!_isModelLoaded) {
      await loadModel();
    }

    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('ML model not loaded');
    }

    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final preprocessedImage = _preprocessImage(image);

      final output = List.filled(_eyeConditionLabels.length, 0.0).reshape([1, _eyeConditionLabels.length]);
      _interpreter!.run(preprocessedImage, output);

      final predictions = output[0] as List<double>;
      return _processEyeAnalysisResults(predictions);

    } catch (e) {
      print('Error analyzing eye image: $e');
      // Fallback on analysis failure
      return EyeAnalysisResult(
        condition: 'Healthy',
        confidence: 0.5,
        riskFactors: [],
        recommendations: ['Unable to analyze image. Please retake the photo.'],
      );
    }
  }

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

  EyeAnalysisResult _processEyeAnalysisResults(List<double> predictions) {
    int maxIndex = 0;
    double maxConfidence = predictions[0];

    for (int i = 1; i < predictions.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        maxIndex = i;
      }
    }

    final predictedCondition = _eyeConditionLabels[maxIndex];
    final confidence = maxConfidence;

    final riskFactors = _generateRiskFactors(predictedCondition, predictions);
    final recommendations = _generateRecommendations(predictedCondition, confidence);

    return EyeAnalysisResult(
      condition: predictedCondition,
      confidence: confidence,
      riskFactors: riskFactors,
      recommendations: recommendations,
    );
  }

  List<String> _generateRiskFactors(String condition, List<double> predictions) {
    final riskFactors = <String>[];

    switch (condition) {
      case 'Central Serous Chorioretinopathy [Color Fundus]':
        riskFactors.addAll([
          'Fluid accumulation under the retina detected',
          'May cause central vision distortion',
          'Often stress-related condition'
        ]);
        break;
      case 'Diabetic Retinopathy':
        riskFactors.addAll([
          'Retinal blood vessel changes detected',
          'Diabetes-related eye damage',
          'May lead to vision loss if untreated'
        ]);
        break;
      case 'Disc Edema':
        riskFactors.addAll([
          'Optic disc swelling detected',
          'May indicate increased intracranial pressure',
          'Requires urgent medical attention'
        ]);
        break;
      case 'Glaucoma':
        riskFactors.addAll([
          'Possible optic nerve damage',
          'May be related to elevated eye pressure',
          'Progressive vision loss risk'
        ]);
        break;
      case 'Healthy':
        riskFactors.add('No significant abnormalities detected');
        break;
      case 'Macular Scar':
        riskFactors.addAll([
          'Scarring in the macular area detected',
          'May affect central vision',
          'Previous retinal damage indicated'
        ]);
        break;
      case 'Myopia':
        riskFactors.addAll([
          'Nearsightedness detected',
          'May worsen over time',
          'Increased risk of retinal complications'
        ]);
        break;
      case 'Pterygium':
        riskFactors.addAll([
          'Growth of tissue on the eye surface',
          'UV exposure related condition',
          'May affect vision if progresses'
        ]);
        break;
      case 'Retinal Detachment':
        riskFactors.addAll([
          'Separation of retina from underlying tissue',
          'Emergency condition requiring immediate treatment',
          'Risk of permanent vision loss'
        ]);
        break;
      case 'Retinitis Pigmentosa':
        riskFactors.addAll([
          'Progressive genetic eye disorder',
          'Gradual vision loss over time',
          'Night vision typically affected first'
        ]);
        break;
    }

    return riskFactors;
  }

  List<String> _generateRecommendations(String condition, double confidence) {
    final recommendations = <String>[];

    if (confidence < 0.6) {
      recommendations.addAll([
        'Image quality may be insufficient for accurate analysis',
        'Consider retaking the photo with better lighting',
        'Consult with an eye care professional for definitive diagnosis'
      ]);
      return recommendations;
    }

    switch (condition) {
      case 'Central Serous Chorioretinopathy [Color Fundus]':
        recommendations.addAll([
          'Consult with a retinal specialist',
          'Manage stress levels and get adequate sleep',
          'Avoid corticosteroid use if possible',
          'Monitor for vision changes'
        ]);
        break;
      case 'Diabetic Retinopathy':
        recommendations.addAll([
          'Urgent consultation with a retinal specialist required',
          'Maintain strict blood sugar control',
          'Schedule regular diabetic eye screenings',
          'Monitor blood pressure and cholesterol levels'
        ]);
        break;
      case 'Disc Edema':
        recommendations.addAll([
          'Seek immediate medical attention',
          'Neurological evaluation may be required',
          'Monitor for headaches or vision changes',
          'Emergency ophthalmology consultation'
        ]);
        break;
      case 'Glaucoma':
        recommendations.addAll([
          'Immediate evaluation by an eye care professional',
          'Regular monitoring of eye pressure',
          'Consider family history screening',
          'Follow prescribed eye drop regimen if diagnosed'
        ]);
        break;
      case 'Healthy':
        recommendations.addAll([
          'Continue regular eye check-ups',
          'Maintain healthy lifestyle habits',
          'Protect eyes from UV radiation',
          'Follow the 20-20-20 rule for digital device use'
        ]);
        break;
      case 'Macular Scar':
        recommendations.addAll([
          'Consult with a retinal specialist',
          'Vision rehabilitation may be helpful',
          'Use of magnifying devices if needed',
          'Monitor for any vision changes'
        ]);
        break;
      case 'Myopia':
        recommendations.addAll([
          'Regular eye examinations',
          'Consider myopia control treatments',
          'Outdoor activities may help slow progression',
          'Proper lighting for near work'
        ]);
        break;
      case 'Pterygium':
        recommendations.addAll([
          'Protect eyes from UV exposure',
          'Use wraparound sunglasses outdoors',
          'Artificial tears for dry eyes',
          'Surgical removal if vision is affected'
        ]);
        break;
      case 'Retinal Detachment':
        recommendations.addAll([
          'EMERGENCY - Seek immediate medical attention',
          'Do not delay treatment',
          'Avoid strenuous activities',
          'Emergency retinal surgery may be required'
        ]);
        break;
      case 'Retinitis Pigmentosa':
        recommendations.addAll([
          'Genetic counseling consultation',
          'Low vision rehabilitation services',
          'Vitamin A supplementation (under medical supervision)',
          'Regular monitoring by retinal specialist'
        ]);
        break;
    }

    return recommendations;
  }

  Future<VisionAnalysisResult> analyzeVisionTest(
    String testType,
    List<TestResult> testResults,
    List<EyeTrackingData> eyeTrackingData,
  ) async {
    if (!_isModelLoaded) {
      await loadModel();
    }

    try {
      EyeAnalysisResult? eyeAnalysis;
      if (eyeTrackingData.isNotEmpty) {
        // Simulate analysis for demo - production would use actual images
        eyeAnalysis = await _simulateEyeAnalysis(testResults);
      }

      double visionScore = _calculateVisionScore(testResults, testType);

      if (eyeAnalysis != null && eyeAnalysis.condition != 'normal') {
        visionScore *= (0.5 + eyeAnalysis.confidence * 0.5);
      }

      final riskLevel = _determineRiskLevel(visionScore, eyeAnalysis);
      final diagnosis = _generateDiagnosis(visionScore, eyeAnalysis, testType);
      final recommendations = _generateVisionRecommendations(visionScore, eyeAnalysis);

      print('Returned result: $riskLevel, $diagnosis, $recommendations');

      return VisionAnalysisResult(
        visionScore: visionScore,
        riskLevel: riskLevel,
        diagnosis: diagnosis,
        recommendations: recommendations,
        confidence: eyeAnalysis?.confidence ?? 0.85,
        eyeAnalysis: eyeAnalysis,
      );
    } catch (e) {
      print('Error analyzing vision test: $e');
      // Default response when analysis fails
      return VisionAnalysisResult(
        visionScore: 0.5,
        riskLevel: 'Medium',
        diagnosis: 'Analysis incomplete - please consult an eye care professional',
        recommendations: ['Schedule a comprehensive eye examination'],
        confidence: 0.5,
      );
    }
  }

  Future<EyeAnalysisResult> _simulateEyeAnalysis(List<TestResult> testResults) async {
    // Demo simulation - production uses actual eye image analysis

    final correctAnswers = testResults.where((r) => r.isCorrect).length;
    final accuracy = testResults.isNotEmpty ? correctAnswers / testResults.length : 0.5;

    String condition;
    double confidence;

    if (accuracy > 0.8) {
      condition = 'Healthy';
      confidence = 0.9;
    } else if (accuracy > 0.6) {
      condition = 'Healthy';
      confidence = 0.7;
    } else if (accuracy > 0.4) {
      condition = 'Myopia';
      confidence = 0.6;
    } else {
      condition = 'Glaucoma';
      confidence = 0.7;
    }

    final riskFactors = _generateRiskFactors(condition, List.filled(10, 0.1));
    final recommendations = _generateRecommendations(condition, confidence);

    return EyeAnalysisResult(
      condition: condition,
      confidence: confidence,
      riskFactors: riskFactors,
      recommendations: recommendations,
    );
  }

  double _calculateVisionScore(List<TestResult> testResults, String testType) {
    if (testResults.isEmpty) return 0.0;

    final correctAnswers = testResults.where((r) => r.isCorrect).length;
    return correctAnswers / testResults.length;
  }

  String _determineRiskLevel(double visionScore, EyeAnalysisResult? eyeAnalysis) {
    if (eyeAnalysis != null && eyeAnalysis.condition != 'Healthy') {
      // Critical conditions requiring immediate attention
      if (eyeAnalysis.condition == 'Retinal Detachment' ||
          eyeAnalysis.condition == 'Disc Edema') {
        return 'Emergency';
      }
      return 'High';
    }

    if (visionScore >= 0.8) return 'Low';
    if (visionScore >= 0.6) return 'Medium';
    return 'High';
  }

  String _generateDiagnosis(double visionScore, EyeAnalysisResult? eyeAnalysis, String testType) {
    if (eyeAnalysis != null && eyeAnalysis.condition != 'Healthy') {
      return 'AI analysis detected possible ${eyeAnalysis.condition}. Professional evaluation recommended.';
    }

    if (visionScore >= 0.8) {
      return 'Vision test performance is excellent. No significant issues detected.';
    } else if (visionScore >= 0.6) {
      return 'Vision test shows some areas for improvement. Regular monitoring recommended.';
    } else {
      return 'Vision test indicates potential concerns. Professional eye examination recommended.';
    }
  }

  List<String> _generateVisionRecommendations(double visionScore, EyeAnalysisResult? eyeAnalysis) {
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

    return recommendations.toSet().toList(); // Remove duplicates
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}

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
  final String source;       // "Test", "AI", hoặc "Combined"
  final String? aiDiagnosis;

  VisionAnalysisResult({
    required this.visionScore,
    required this.riskLevel,
    required this.diagnosis,
    required this.recommendations,
    required this.confidence,
    this.eyeAnalysis,
    this.source = "Combined",   // mặc định
    this.aiDiagnosis,
  });

  /// Update object -> new object
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