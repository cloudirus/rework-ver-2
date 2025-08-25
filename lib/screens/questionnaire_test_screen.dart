// questionnaire_screen.dart
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
  // String answersString = _answers.toString();
  int _currentIndex = 0;
  final List<TestResult> _testResults = [];
  final TestSessionManager _sessionManager = TestSessionManager();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    // String answersString = _answers.toString();
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

  // void _submit() {
  //   debugPrint("User Answers: $_answers");
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text("Responses"),
  //       content: Text(_answers.toString()),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             _completeQuestionnaire();
  //           },
  //           child: const Text("Close"),
  //         )
  //       ],
  //     ),
  //   );
  // }

  Future<void> _completeQuestionnaire() async{
    String answersString = _answers.toString();

    final result = TestResult(
      line: 0,
      letter: 'Questionnaire',
      userResponse: answersString,
      isCorrect: true,
      timestamp: DateTime.now(),
    );

    _testResults.add(result);
    _sessionManager.addQuestionnaireResult(result);

    final session = _sessionManager.getCurrentSession();
    if (session != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            testType: 'Hoàn thành bài kiểm tra',
            testResults: session.getAllResults(),
            testStartTime: session.startTime,
          ),
        ),
      );
    }
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
      appBar: AppBar(
        title: Text("Question ${_currentIndex + 1}/${_questions.length}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question["question"],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...options.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: _answers[_currentIndex],
                onChanged: (value) {
                  setState(() {
                    _answers[_currentIndex] = value!;
                  });
                },
              );
            }),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  ElevatedButton(
                    onPressed: _prev,
                    child: const Text("Back"),
                  ),
                ElevatedButton(
                  onPressed: _answers[_currentIndex] != null ? _next : null,
                  child: Text(
                      _currentIndex == _questions.length - 1 ? "Submit" : "Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}