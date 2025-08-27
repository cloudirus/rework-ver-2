import 'dart:math';
import '../models/test_result.dart';
import '../models/test_session.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AnalysisResultLog {
  final DateTime timestamp;
  final int durations;
  final double visionScore;
  final String riskLevel;
  final String diagnosis;
  final List<String> recommendations;

  AnalysisResultLog({
    required this.timestamp,
    required this.durations,
    required this.visionScore,
    required this.riskLevel,
    required this.diagnosis,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'durations': durations,
    'visionScore': visionScore,
    'riskLevel': riskLevel,
    'diagnosis': diagnosis,
    'recommendations': recommendations,
  };
}

class OverallHistoryLog{
  final int totalTest;
  final double averageScore;
  final int lowRiskCount;
  final int mediumRiskCount;
  final int highRiskCount;
  final DateTime? lastTestDate;

  OverallHistoryLog({
    required this.totalTest,
    required this.averageScore,
    required this.lowRiskCount,
    required this.mediumRiskCount,
    required this.highRiskCount,
    required this.lastTestDate,
  });

  Map<String, dynamic> toJson() => {
    'totalTest': totalTest,
    'averageScore': averageScore,
    'lowRiskCount': lowRiskCount,
    'mediumRiskCount': mediumRiskCount,
    'highRiskCount': highRiskCount,
    'lastTestDay': lastTestDate?.toIso8601String(),
  };
}

class AnalysisResultStorage {
  static Future<Directory> _getHistoryDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final historyDir = Directory("${dir.path}/run_history");

    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return historyDir;
  }

  static Future<void> saveResult(AnalysisResultLog result) async {
    final dir = await _getHistoryDir();

    // Use timestamp as filename, e.g. 2025-08-26_14-30-12.json
    final filename = result.timestamp.toIso8601String().replaceAll(":", "-");
    final file = File("${dir.path}/$filename.json");

    await file.writeAsString(jsonEncode(result.toJson()));
    print("✅ Saved analysis result to ${file.path}");
  }
}

class OverallResultStorage {
  static Future<Directory> _getOverallHistoryDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final historyDir = Directory("${dir.path}/run_history/overall");

    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return historyDir;
  }

  static Future<void> saveResult(OverallHistoryLog result) async {
    print("Save overall history initalized");
    final dir = await _getOverallHistoryDir();

    // Use timestamp as filename, e.g. 2025-08-26_14-30-12.json
    final filename = 'overall';
    final file = File("${dir.path}/$filename.json");

    await file.writeAsString(jsonEncode(result.toJson()));
    print("✅ Saved overall history to ${file.path}");
  }
}

class TestDataService {
  static final TestDataService _instance = TestDataService._internal();
  factory TestDataService() => _instance;
  TestDataService._internal();

  final List<VisionTestSession> _testHistory = [];
  final List<TestSession> _allSessions = [];
  final TestSessionManager _sessionManager = TestSessionManager();
  List<dynamic> _questions = [];

  void addCompletedSession(TestSession session) {
    _allSessions.add(session);

    final visionSession = VisionTestSession(
      sessionId: session.sessionId,
      testType: _determineTestType(session),
      startTime: session.startTime,
      endTime: DateTime.now(),
      testResults: session.getAllResults(),
      eyeTrackingData: session.eyeTrackingData,
      visionScore: calculateOverallScore(session),
      diagnosis: generateDiagnosis(session),
      recommendations: generateRecommendations(session),
    );

    _testHistory.add(visionSession);

    final endTime = DateTime.now();
    final durations = session.startTime.difference(endTime).inMinutes;
    final visionScore = calculateOverallScore(session);

    final log = AnalysisResultLog(
        timestamp: session.startTime,
        durations: durations,
        visionScore: visionScore,
        riskLevel: getRiskLevel(visionScore),
        diagnosis: generateDiagnosis(session),
        recommendations: generateRecommendations(session)
    );
    AnalysisResultStorage.saveResult(log);
  }

  String _determineTestType(TestSession session) {
    if (session.isSnellenComplete && session.isAmslerComplete) {
      return 'Complete Vision Test';
    } else if (session.isSnellenComplete) {
      return 'Snellen Test';
    } else if (session.isAmslerComplete) {
      return 'Amsler Grid Test';
    }
    return 'Incomplete Test';
  }

  Future<void> _loadQuestions() async {
    final String data = await rootBundle.loadString('assets/questions.json');
    _questions = json.decode(data)['questions'];
  }

  double calculateOverallScore(TestSession session) {
    double totalScore = 0.0;
    int testCount = 0;
    final currentSession = _sessionManager.getCurrentSession();
    if (currentSession == null) {
      // handle gracefully
      return 1; // or whatever default weight
    }
    double weight = _weightBasedOnQuestionnare(currentSession.questionnaireResults, _questions);
    final snellenScore = calculateSnellenScore(session.snellenResults);
    final amslerScore = calculateAmslerScore(session.amslerResults);

    if (session.isSnellenComplete) {
      totalScore += snellenScore;
      testCount++;
    }

    if (session.isAmslerComplete) {
      totalScore += amslerScore;
      testCount++;
    }

    final testScore = totalScore / testCount;
    final testScoreAfterWeight = testScore * weight;

    print("Snellen score: $snellenScore");
    print("Amsler score: $amslerScore");
    print("Test score before weight: $testScore");
    print("Test score after weight: $testScoreAfterWeight");

    return testCount > 0 ? testScoreAfterWeight : 0.0;
  }

  double _weightBasedOnQuestionnare(
      List<TestResult> questionnaireResults,
      List<dynamic> _ignoredQuestions, // kept to match your old signature
      ) {
    if (questionnaireResults.isEmpty) {
      print("📥 Questionnaire empty → default weight 1.0");
      return 1.0;
    }

    int totalScore = 0;

    for (final r in questionnaireResults) {
      final response = r.userResponse.trim();

      // Try to parse a leading integer: "1. ...", "2. ...", "3. ..."
      final match = RegExp(r'^(\d+)').firstMatch(response); // <-- IMPORTANT: no double backslash
      int? value;
      if (match != null) {
        value = int.tryParse(match.group(1)!);
      } else {
        // Fallbacks in case of weird whitespace or formatting
        if (response.startsWith('1')) value = 1;
        else if (response.startsWith('2')) value = 2;
        else if (response.startsWith('3')) value = 3;
      }

      if (value == null) {
        print('⚠️ Could not parse score from answer: "${r.userResponse}"');
        continue;
      }

      totalScore += value;
    }

    print("🧮 Questionnaire answers: ${questionnaireResults.length}, totalScore = $totalScore");

    // Category → weight
    // 0–10 → 1.0 | 11–20 → 0.95 | >20 → 0.9
    if (totalScore <= 20) return 1.0;
    if (totalScore <= 40) return 0.85;
    return 0.7;
  }


  double calculateSnellenScore(List<TestResult> results) {
    if (results.isEmpty) return 0.0;

    final visionLevels = ['20/200', '20/100', '20/70', '20/50', '20/40', '20/30', '20/25', '20/20'];
    int bestLine = -1;

    for (final result in results) {
      if (result.isCorrect && result.line > bestLine) {
        bestLine = result.line;
      }
    }

    if (bestLine == -1) return 0.1; // Very poor vision if no correct answers

    switch (bestLine) {
      case 0: return 0.2; // 20/200
      case 1: return 0.3; // 20/100
      case 2: return 0.4; // 20/70
      case 3: return 0.5; // 20/50
      case 4: return 0.6; // 20/40
      case 5: return 0.7; // 20/30
      case 6: return 0.8; // 20/25
      case 7: return 0.9; // 20/20
      default: return 0.1;
    }
  }

  double calculateAmslerScore(List<TestResult> results) {
    if (results.isEmpty) return 0.0;

    final result = results.first;
    final response = result.userResponse;

    final distortionMatch = RegExp(r'Distortion Points: (\d+)').firstMatch(response);
    final distortionCount = distortionMatch != null ? int.parse(distortionMatch.group(1)!) : 0;

    final hasWavyLines = response.contains('wavy_lines: Yes');
    final hasBlurredAreas = response.contains('blurred_areas: Yes');
    final hasMissingSpots = response.contains('missing_spots: Yes');
    final hasDistortedLines = response.contains('straight_lines: No') || response.contains('straight_lines: Some areas distorted');
    final hasFocusDifficulty = response.contains('focus_difficulty: Moderate') || response.contains('focus_difficulty: Severe');

    double score = 1.0;

    if (distortionCount > 0) score -= 0.1 * min(distortionCount, 5);
    if (hasWavyLines) score -= 0.15;
    if (hasBlurredAreas) score -= 0.15;
    if (hasMissingSpots) score -= 0.2;
    if (hasDistortedLines) score -= 0.15;
    if (hasFocusDifficulty) score -= 0.1;

    return max(0.1, score);
  }

  String generateDiagnosis(TestSession session) {
    final score = calculateOverallScore(session);

    if (score >= 0.8) {
      return 'Excellent vision health. No significant visual impairments detected.';
    } else if (score >= 0.6) {
      return 'Good vision with minor variations. Regular monitoring recommended.';
    } else if (score >= 0.4) {
      return 'Moderate vision concerns detected. Professional eye examination recommended.';
    } else {
      return 'Significant vision issues detected. Immediate professional consultation strongly recommended.';
    }
  }

  List<String> generateRecommendations(TestSession session) {
    final recommendations = <String>[];
    final score = calculateOverallScore(session);

    if (score >= 0.8) {
      recommendations.addAll([
        'Maintain regular eye check-ups every 2 years',
        'Continue protecting your eyes from UV rays',
        'Follow the 20-20-20 rule when using digital devices',
        'Maintain a healthy diet rich in omega-3 fatty acids',
      ]);
    } else if (score >= 0.6) {
      recommendations.addAll([
        'Schedule an eye examination within 6 months',
        'Consider prescription glasses if not already wearing them',
        'Take frequent breaks from digital screens',
        'Ensure adequate lighting when reading or working',
      ]);
    } else if (score >= 0.4) {
      recommendations.addAll([
        'Schedule a comprehensive eye examination within 1 month',
        'Consider vision correction options with an eye care professional',
        'Monitor symptoms and changes in vision',
        'Avoid driving at night if vision is compromised',
      ]);
    } else {
      recommendations.addAll([
        'Seek immediate professional eye care consultation',
        'Consider emergency eye examination if symptoms are severe',
        'Avoid activities that require precise vision until evaluated',
        'Keep a record of vision changes and symptoms',
      ]);
    }

    if (session.isAmslerComplete) {
      final amslerScore = calculateAmslerScore(session.amslerResults);
      if (amslerScore < 0.7) {
        recommendations.add('Request macular degeneration screening during eye exam');
      }
    }

    return recommendations;
  }

  String getRiskLevel(double score) {
    if (score >= 0.7) return 'Low';
    if (score >= 0.4) return 'Medium';
    return 'High';
  }

  Map<String, dynamic> getTestStatistics() {
    if (_testHistory.isEmpty) {
      return {
        'totalTests': 0,
        'averageScore': 0.0,
        'lowRiskCount': 0,
        'mediumRiskCount': 0,
        'highRiskCount': 0,
        'lastTestDate': null,
        'bestScore': 0.0,
        'worstScore': 0.0,
      };
    }

    final scores = _testHistory.map((s) => s.visionScore ?? 0.0).toList();
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;

    int lowRiskCount = 0, mediumRiskCount = 0, highRiskCount = 0;

    for (final score in scores) {
      final risk = getRiskLevel(score);
      switch (risk) {
        case 'Low': lowRiskCount++; break;
        case 'Medium': mediumRiskCount++; break;
        case 'High': highRiskCount++; break;
      }
    }
    final lastTestDate = _testHistory.isNotEmpty ? _testHistory.last.startTime : null;
    final log = OverallHistoryLog(
        totalTest: _testHistory.length,
        averageScore: averageScore,
        lowRiskCount: lowRiskCount,
        mediumRiskCount: mediumRiskCount,
        highRiskCount: highRiskCount,
        lastTestDate: lastTestDate,
    );
    OverallResultStorage.saveResult(log);

    return {
      'totalTests': _testHistory.length,
      'averageScore': averageScore,
      'lowRiskCount': lowRiskCount,
      'mediumRiskCount': mediumRiskCount,
      'highRiskCount': highRiskCount,
      'lastTestDate': _testHistory.isNotEmpty ? _testHistory.last.startTime : null,
      'bestScore': scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0.0,
      'worstScore': scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0.0,
    };
  }

  List<VisionTestSession> getTestHistory() {
    return List.from(_testHistory.reversed);
  }

  List<VisionTestSession> getRecentActivity({int limit = 5}) {
    return _testHistory.reversed.take(limit).toList();
  }

  void clearAllData() {
    _testHistory.clear();
    _allSessions.clear();
  }
}