import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../main.dart';
import '../widgets/camera_preview_widget.dart';
import '../models/test_result.dart';
import '../models/test_session.dart';
import 'questionnaire_test_screen.dart';
import '../widgets/app_header.dart';
import '../services/camera_service.dart';

class AmslerGridTestScreen extends StatefulWidget {
  const AmslerGridTestScreen({super.key});

  @override
  State<AmslerGridTestScreen> createState() => _AmslerGridTestScreenState();
}

class _AmslerGridTestScreenState extends State<AmslerGridTestScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isTestActive = false;
  bool _testCompleted = false;
  bool _showQuestionnaire = false;
  DateTime? _testStartTime;
  final List<TestResult> _testResults = [];
  final TestSessionManager _sessionManager = TestSessionManager();
  final CameraService _cameraService = CameraService();
  
  String _currentEye = 'right';
  final List<Offset> _distortionPoints = [];
  final List<Offset> _blurPoints = [];
  final List<Offset> _missingPoints = [];
  
  Timer? _eyeTimer;
  int _remainingTime = 30;
  
  final Map<String, dynamic> _questionnaireResponses = {};
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isNotEmpty) {
      CameraDescription? frontCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }
      
      _cameraController = CameraController(
        frontCamera ?? cameras.first, // Use front camera if available, otherwise fallback to first camera
        ResolutionPreset.medium,
      );
      
      try {
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      } catch (e) {
        print('Error initializing camera: $e');
      }
    }
  }

  @override
  void dispose() {
    _eyeTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _isTestActive = true;
      _testStartTime = DateTime.now();
      _currentEye = 'right';
      _distortionPoints.clear();
      _blurPoints.clear();
      _missingPoints.clear();
      _questionnaireResponses.clear();
      _remainingTime = 30;
    });
    
    // Start AI analysis for Amsler Grid
    _startAIAnalysis();
    
    // Start timer for eye test
    _startEyeTimer();
  }

  void _startAIAnalysis() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      // Start periodic eye capture for AI analysis
      _cameraService.startPeriodicCapture(_cameraController!, 'Amsler Grid Test');
    }
  }

  void _startEyeTimer() {
    _eyeTimer?.cancel();
    _remainingTime = 30;
    
    _eyeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime--;
      });
      
      if (_remainingTime <= 0) {
        timer.cancel();
        _autoSwitchEye();
      }
    });
  }

  void _autoSwitchEye() {
    if (_currentEye == 'right') {
      setState(() {
        _currentEye = 'left';
        _distortionPoints.clear();
        _blurPoints.clear();
        _missingPoints.clear();
        _remainingTime = 30;
      });
      _startEyeTimer();
    } else {
      _completeGridTest();
    }
  }

  void _switchEye() {
    _eyeTimer?.cancel();
    if (_currentEye == 'right') {
      setState(() {
        _currentEye = 'left';
        _distortionPoints.clear();
        _blurPoints.clear();
        _missingPoints.clear();
        _remainingTime = 30;
      });
      _startEyeTimer();
    } else {
      _completeGridTest();
    }
  }

  void _completeGridTest() {
    _eyeTimer?.cancel();
    setState(() {
      _isTestActive = false;
      _testCompleted = true;
      _showQuestionnaire = true;
    });
  }

  void _completeQuestionnaire() {
    final result = TestResult(
      line: 0,
      letter: 'Amsler Grid',
      userResponse: _generateResponseSummary(),
      isCorrect: _distortionPoints.isEmpty && _blurPoints.isEmpty && _missingPoints.isEmpty,
      timestamp: DateTime.now(),
    );
    
    _testResults.add(result);
    _sessionManager.addAmslerResult(result);
    
    final session = _sessionManager.getCurrentSession();
    if (session != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QuestionnaireScreen(),
        ),
      );
    }
  }

  String _generateResponseSummary() {
    final responses = <String>[];
    
    responses.add('Distortion Points: ${_distortionPoints.length}');
    responses.add('Blur Points: ${_blurPoints.length}');
    responses.add('Missing Points: ${_missingPoints.length}');
    
    _questionnaireResponses.forEach((key, value) {
      responses.add('$key: $value');
    });
    
    return responses.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Kiểm tra Lưới Amsler',
        showBackButton: true,
        onBackPressed: () {
          if (_showQuestionnaire) {
            setState(() {
              _showQuestionnaire = false;
              _testCompleted = false;
              _isTestActive = true;
            });
          } else {
            Navigator.pop(context);
          }
        },
      ),
      body: Column(
        children: [
          if (_isCameraInitialized && !_showQuestionnaire) 
            CameraPreviewWidget(controller: _cameraController!),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _showQuestionnaire 
                  ? _buildQuestionnaire()
                  : _isTestActive 
                      ? _buildTestInterface() 
                      : _buildInstructions(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.grid_on,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Kiểm tra Lưới Amsler',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hướng dẫn:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInstructionItem('1. Giữ thiết bị cách mắt ~40 cm (một cánh tay)'),
                _buildInstructionItem('2. Che một mắt bằng tay'),
                _buildInstructionItem('3. Tập trung vào chấm đỏ ở giữa'),
                _buildInstructionItem('4. Chạm vào vùng biến dạng, mờ hoặc thiếu'),
                _buildInstructionItem('5. Mỗi mắt kiểm tra trong 30 giây'),
                _buildInstructionItem('6. Tự động chuyển sang mắt tiếp theo'),
                _buildInstructionItem('7. Trả lời câu hỏi về điều bạn quan sát'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Bắt đầu Kiểm tra',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestInterface() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Text(
                  'Kiểm tra: Mắt ${_currentEye == 'right' ? 'Phải' : 'Trái'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Che mắt ${_currentEye == 'right' ? 'trái' : 'phải'} và tập trung vào chấm giữa',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _remainingTime <= 10 ? Colors.red.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _remainingTime <= 10 ? Colors.red : Colors.blue,
                    ),
                  ),
                  child: Text(
                    'Thời gian còn lại: ${_remainingTime}s',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _remainingTime <= 10 ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 350),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GestureDetector(
                  onTapDown: (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final Offset localPosition = box.globalToLocal(details.globalPosition);
                    setState(() {
                      _distortionPoints.add(localPosition);
                    });
                  },
                  child: CustomPaint(
                    painter: AmslerGridPainter(_distortionPoints, _blurPoints, _missingPoints),
                    child: Container(),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _distortionPoints.clear();
                      _blurPoints.clear();
                      _missingPoints.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Xóa'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _switchEye,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_currentEye == 'right' ? 'Tiếp tục Mắt Trái' : 'Hoàn thành Kiểm tra'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaire() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Câu hỏi Sau Kiểm tra',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vui lòng trả lời các câu hỏi sau về điều bạn quan sát trong quá trình kiểm tra:',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          _buildQuestionCard(
            'Bạn có nhận thấy đường cong hoặc biến dạng không?',
            'wavy_lines',
            ['Có', 'Không', 'Không chắc chắn'],
          ),
          
          _buildQuestionCard(
            'Có vùng nào mờ hoặc không rõ không?',
            'blurred_areas',
            ['Có', 'Không', 'Không chắc chắn'],
          ),
          
          _buildQuestionCard(
            'Bạn có thấy điểm thiếu hoặc điểm tối không?',
            'missing_spots',
            ['Có', 'Không', 'Không chắc chắn'],
          ),
          
          _buildQuestionCard(
            'Các đường lưới có thẳng và cách đều không?',
            'straight_lines',
            ['Có', 'Không', 'Một số vùng biến dạng'],
          ),
          
          _buildQuestionCard(
            'Chấm đỏ ở giữa rõ đến mức nào?',
            'central_dot',
            ['Rất rõ', 'Khá rõ', 'Mờ', 'Không thấy'],
          ),
          
          _buildQuestionCard(
            'Bạn có gặp khó khăn tập trung không?',
            'focus_difficulty',
            ['Không', 'Nhẹ', 'Vừa', 'Nghiêm trọng'],
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _allQuestionsAnswered() ? _completeQuestionnaire : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Hoàn thành Kiểm tra',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (!_allQuestionsAnswered())
            const Text(
              'Vui lòng trả lời tất cả câu hỏi để hoàn thành kiểm tra.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String question, String key, List<String> options) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map((option) => RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _questionnaireResponses[key],
              onChanged: (value) {
                setState(() {
                  _questionnaireResponses[key] = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            )),
          ],
        ),
      ),
    );
  }

  bool _allQuestionsAnswered() {
    const requiredQuestions = [
      'wavy_lines',
      'blurred_areas',
      'missing_spots',
      'straight_lines',
      'central_dot',
      'focus_difficulty',
    ];
    
    return requiredQuestions.every((question) => 
        _questionnaireResponses.containsKey(question) && 
        _questionnaireResponses[question] != null
    );
  }
}

class AmslerGridPainter extends CustomPainter {
  final List<Offset> distortionPoints;
  final List<Offset> blurPoints;
  final List<Offset> missingPoints;

  AmslerGridPainter(this.distortionPoints, this.blurPoints, this.missingPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final markPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final gridSize = size.width / 20;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw center dot
    canvas.drawCircle(
      Offset(centerX, centerY),
      4.0,
      dotPaint,
    );

    // Draw distortion markers
    for (final point in distortionPoints) {
      canvas.drawCircle(point, 6.0, markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}