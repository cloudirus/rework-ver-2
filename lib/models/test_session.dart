import 'test_result.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class TestSession {
  final String sessionId;
  final DateTime startTime;
  List<TestResult> snellenResults = [];
  List<TestResult> amslerResults = [];
  List<TestResult> questionnaireResults = [];
  List<EyeTrackingData> eyeTrackingData = [];
  
  TestSession({
    required this.sessionId,
    required this.startTime,
  });

  void addSnellenResult(TestResult result) {
    snellenResults.add(result);
  }

  void addAmslerResult(TestResult result) {
    amslerResults.add(result);
  }

  void addQuestionnaireResult (TestResult result){
    questionnaireResults.add(result);
  }

  void addEyeTrackingData(EyeTrackingData data) {
    eyeTrackingData.add(data);
  }

  List<TestResult> getAllResults() {
    return [...snellenResults, ...amslerResults];
  }

  bool get isSnellenComplete => snellenResults.isNotEmpty;
  bool get isAmslerComplete => amslerResults.isNotEmpty;
  bool get isComplete => isSnellenComplete && isAmslerComplete;

  // --- JSON serialization ---
  Map<String, dynamic> toJson() {
    return {
      "sessionId": sessionId,
      "startTime": startTime.toIso8601String(),
      "snellenResults": snellenResults.map((r) => r.toJson()).toList(),
      "amslerResults": amslerResults.map((r) => r.toJson()).toList(),
      "questrionnaireResults": questionnaireResults.map((r) => r.toJson()).toList(),
      "eyeTrackingData": eyeTrackingData.map((e) => e.toJson()).toList(),
    };
  }

  factory TestSession.fromJson(Map<String, dynamic> json) {
    return TestSession(
      sessionId: json["sessionId"],
      startTime: DateTime.parse(json["startTime"]),
    )
      ..snellenResults = (json["snellenResults"] as List)
          .map((r) => TestResult.fromJson(r))
          .toList()
      ..amslerResults = (json["amslerResults"] as List)
          .map((r) => TestResult.fromJson(r))
          .toList()
      ..questionnaireResults = (json["questrionnaireResults"] as List)
          .map((r) => TestResult.fromJson(r))
          .toList()
      ..eyeTrackingData = (json["eyeTrackingData"] as List)
          .map((e) => EyeTrackingData.fromJson(e))
          .toList();
  }
}

class TestSessionManager {
  static final TestSessionManager _instance = TestSessionManager._internal();
  factory TestSessionManager() => _instance;
  TestSessionManager._internal();

  TestSession? _currentSession;

  TestSession startNewSession() {
    _currentSession = TestSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
    );
    return _currentSession!;
  }

  TestSession? getCurrentSession() {
    return _currentSession;
  }

  void addSnellenResult(TestResult result) {
    _currentSession?.addSnellenResult(result);
  }

  void addAmslerResult(TestResult result) {
    _currentSession?.addAmslerResult(result);
  }

  void addQuestionnaireResult (TestResult result){
    _currentSession?.addQuestionnaireResult(result);
  }

  void addEyeTrackingData(EyeTrackingData data) {
    _currentSession?.addEyeTrackingData(data);
  }

  void clearSession() {
    _currentSession = null;
  }
}

class SessionStorage {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    print("📂 Saving sessions to: ${dir.path}");
    return File("${dir.path}/sessions.json");
  }

  static Future<void> saveSessions(List<TestSession> sessions) async {
    final file = await _getFile();
    final jsonData = sessions.map((s) => s.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonData));
  }

  static Future<List<TestSession>> loadSessions() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final jsonString = await file.readAsString();
      final List data = jsonDecode(jsonString);
      return data.map((e) => TestSession.fromJson(e)).toList();
    } catch (e) {
      print("⚠️ Failed to load sessions: $e");
      return [];
    }
  }
}