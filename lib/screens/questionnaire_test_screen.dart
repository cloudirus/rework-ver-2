import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'results_screen.dart';
import '../models/test_result.dart';
import '../models/test_session.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  List<dynamic> _questions = [];
  final Map<int, String> _answers = {};
  int _currentIndex = 0;
  final List<TestResult> _testResults = [];
  final TestSessionManager _sessionManager = TestSessionManager();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final String response = await rootBundle.loadString('assets/questions.json');
    final data = json.decode(response);
    setState(() {
      _questions = data["questions"];
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _completeQuestionnaire();
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _completeQuestionnaire() async {
    // Ensure a session exists
    final sessionManager = TestSessionManager();
    var current = sessionManager.getCurrentSession();
    current ??= sessionManager.startNewSession();


// Create one TestResult per question and add to session
//     final now = DateTime.now();
//     for (int i = 0; i < _questions.length; i++) {
//       final q = _questions[i];
//       final questionText = q['question']?.toString() ?? 'Question $i';
//       final selected = _answers[i] ?? '';
//

// Build TestResult: line is question index, letter is question text marker
      for (int i = 0; i < _answers.length; i++) {
        final response = _answers[i] ?? "";
        final tr = TestResult(
          line: i,
          letter: "Questionnaire",
          userResponse: response,  // ✅ store each answer separately
          isCorrect: true,
          timestamp: DateTime.now(),
        );
        _sessionManager.addQuestionnaireResult(tr);
      }


// Optionally save sessions / navigate to results
// If you have SessionStorage or _testDataService in your app, call those here.


// Navigate to Results screen (if you want)
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          testType: 'Hoàn thành bài kiểm tra',
          testResults: current!.getAllResults(),
          testStartTime: current.startTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _questions[_currentIndex];
    final options = question["options"] as List<dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7), // pastel background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        centerTitle: false, // make sure it's left-aligned
        title: Row(
          mainAxisSize: MainAxisSize.min, // keeps content compact on the left
          children: const [
            Icon(Icons.remove_red_eye, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Câu hỏi",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question["question"],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Answer options
                ...options.map((option) {
                  return RadioListTile<String>(
                    value: option,
                    groupValue: _answers[_currentIndex],
                    onChanged: (value) {
                      setState(() {
                        _answers[_currentIndex] = value!;
                      });
                    },
                    title: Text(option, style: const TextStyle(fontSize: 16)),
                    activeColor: Colors.blue,
                  );
                }),

                const Spacer(),

                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentIndex > 0)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _prev,
                        child: const Text("Quay lại", style: TextStyle(color: Colors.white)),
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _answers[_currentIndex] != null ? _next : null,
                      child: Text(
                        _currentIndex == _questions.length - 1 ? "Hoàn tất" : "Tiếp tục",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}