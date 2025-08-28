import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../main.dart';
import '../widgets/camera_preview_widget.dart';
import '../models/test_result.dart';
import '../models/test_session.dart';
import 'amsler_grid_test_screen.dart';
import '../widgets/app_header.dart';
import '../services/camera_service.dart';

class SnellenTestScreen extends StatefulWidget {
    const SnellenTestScreen({super.key});

    @override
    State<SnellenTestScreen> createState() => _SnellenTestScreenState();
}

class _SnellenTestScreenState extends State<SnellenTestScreen> {
  bool _isCameraInitialized = false;
  bool _isTestActive = false;
  int _currentLine = 0;
  String _currentLetter = '';
  String _userResponse = '';
  final List<TestResult> _testResults = [];
  DateTime? _testStartTime;
  final TestSessionManager _sessionManager = TestSessionManager();
  final CameraService _cameraService = CameraService();






  final List<List<String>> _snellenChart = [
    ['E'], // 20/200
    ['F', 'P'], // 20/100
    ['T', 'O', 'Z'], // 20/70
    ['L', 'P', 'E', 'D'], // 20/50
    ['P', 'E', 'C', 'F', 'D'], // 20/40
    ['E', 'D', 'F', 'C', 'Z', 'P'], // 20/30
    ['F', 'E', 'L', 'O', 'P', 'Z', 'D'], // 20/25
    ['D', 'E', 'F', 'P', 'O', 'T', 'E', 'C'], // 20/20
  ];

  final List<String> _visionLevels = [
    '20/200', '20/100', '20/70', '20/50',
    '20/40', '20/30', '20/25', '20/20'
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initCamera() async {
    print("📷 Camera initializing...");
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    await _cameraService.startCamera(frontCamera);
    setState(() {
      _isCameraInitialized = true;
    });
  }



  // Future<void> _initializeCamera() async {
  //   if (cameras.isNotEmpty) {
  //     CameraDescription? frontCamera;
  //     for (final camera in cameras) {
  //       if (camera.lensDirection == CameraLensDirection.front) {
  //         frontCamera = camera;
  //         break;
  //       }
  //     }
  //
  //     _cameraController = CameraController(
  //       frontCamera ?? cameras.first, // Use front camera if available, otherwise fallback to first camera
  //       ResolutionPreset.medium,
  //     );
  //
  //     try {
  //       await _cameraController!.initialize();
  //       setState(() {
  //         _isCameraInitialized = true;
  //       });
  //     } catch (e) {
  //       print('Error initializing camera: $e');
  //     }
  //   }
  // }

  @override
  void dispose() {
    _cameraService.stopCamera();
    super.dispose();
  }



  void _startTest() async {
    _sessionManager.startNewSession();
    setState(() {
      _isTestActive = true;
      _currentLine = 0;
      _testStartTime = DateTime.now();
    });

    await _initCamera();
    _startAIAnalysis();
    _showNextLetter();
  }

  void _startAIAnalysis() {
    if (_cameraService.controller != null &&
        _cameraService.controller!.value.isInitialized) {
      _cameraService.startPeriodicCapture(
        _cameraService.controller!,
        'Snellen Test',
      );
    }
  }

  void _showNextLetter() {
    if (_currentLine < _snellenChart.length) {
      final letters = _snellenChart[_currentLine];
      final randomIndex = (DateTime.now().millisecondsSinceEpoch % letters.length);
      setState(() {
        _currentLetter = letters[randomIndex];
        _userResponse = '';
      });
    } else {
      _completeTest();
    }
  }

  void _submitResponse(String response) {
    final isCorrect = response.toUpperCase() == _currentLetter;
    final result = TestResult(
      line: _currentLine,
      letter: _currentLetter,
      userResponse: response,
      isCorrect: isCorrect,
      timestamp: DateTime.now(),
    );

    _testResults.add(result);
    _sessionManager.addSnellenResult(result);

    setState(() {
      _currentLine++;
    });

    if (_currentLine < _snellenChart.length) {
      _showNextLetter();
    } else {
      _completeTest();
    }
  }

  void _completeTest() async {
    setState(() {
      _isTestActive = false;
    });

    // Analyze captured eye images
    await _cameraService.analyzeAllCapturedImages();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AmslerGridTestScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Kiểm tra Snellen (Bước 1/2)',
        showBackButton: true,
      ),
      body: Column(
        children: [
          if (_isCameraInitialized &&
              _cameraService.controller != null &&
              _cameraService.controller!.value.isInitialized)
            CameraPreviewWidget(cameraService: _cameraService)
          ,


          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _isTestActive ? _buildTestInterface() : _buildInstructions(),
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
            Icons.text_fields,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Kiểm tra Snellen',
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
                _buildInstructionItem('Đứng cách màn hình 20 feet (6 mét)'),
                _buildInstructionItem('Che một mắt bằng tay'),
                _buildInstructionItem('Đọc các chữ cái hiển thị trên màn hình'),
                _buildInstructionItem('Camera sẽ giám sát chuyển động mắt của bạn'),
                _buildInstructionItem('Các chữ cái sẽ dần nhỏ hơn'),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Text(
                  'Dòng ${_currentLine + 1}/8',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Mức độ Thị lực: ${_visionLevels[_currentLine]}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _currentLetter,
                    style: TextStyle(
                      fontSize: (120 - (_currentLine * 12)).toDouble(),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Bạn thấy chữ cái nào?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Letter buttons in a grid layout for better mobile experience
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                for (String letter in ['E', 'F', 'P', 'T', 'O', 'Z', 'L', 'D', 'C'])
                  ElevatedButton(
                    onPressed: () => _submitResponse(letter),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}